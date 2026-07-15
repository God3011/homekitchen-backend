import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  FulfillmentType,
  KitchenStatus,
  OrderStatus,
  PaymentStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateOrderDto } from './dto/create-order.dto';

@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  private fourDigitCode(): string {
    return Math.floor(1000 + Math.random() * 9000).toString();
  }

  /**
   * Places an order. Prices/names are snapshotted from the live menu so later
   * menu edits never rewrite history. Per-item price cap is enforced at menu
   * creation time; there is no cart/order total cap. Order + items + preferences
   * + a "created" Payment + the first status-history row are written atomically
   * in one transaction. After placement, low-stock and sold-out alerts are sent.
   */
  private serviceDate(): Date {
    // Use UTC-midnight of the *local* calendar day so this matches how the
    // apps write dates: they send a "YYYY-MM-DD" string that Prisma parses to
    // UTC-midnight. Using local midnight here (new Date(y,m,d)) would resolve
    // to the previous UTC day in positive-offset zones like IST, causing
    // "not cooking today" / plate-lookup mismatches after local midnight.
    const now = new Date();
    return new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
  }

  async create(dto: CreateOrderDto) {
    // --- Gap #5: kitchen readiness checks ---
    const kitchen = await this.prisma.kitchen.findUnique({
      where: { id: dto.kitchenId },
    });
    if (!kitchen) throw new NotFoundException('Kitchen not found.');
    if (kitchen.status !== KitchenStatus.verified) {
      throw new BadRequestException('Kitchen is not verified.');
    }

    const today = this.serviceDate();

    const dailyStatus = await this.prisma.kitchenDailyStatus.findUnique({
      where: {
        kitchenId_serviceDate: {
          kitchenId: dto.kitchenId,
          serviceDate: today,
        },
      },
    });
    if (!dailyStatus?.isCooking) {
      throw new BadRequestException('Kitchen is not cooking today.');
    }

    const dayOfWeek = new Date().getDay(); // 0=Sun .. 6=Sat
    const hours = await this.prisma.kitchenHours.findUnique({
      where: {
        kitchenId_dayOfWeek: {
          kitchenId: dto.kitchenId,
          dayOfWeek,
        },
      },
    });
    if (!hours) {
      throw new BadRequestException('Kitchen is not open today.');
    }
    const now = new Date();
    const currentTime =
      `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    if (currentTime < hours.openTime || currentTime >= hours.closeTime) {
      throw new BadRequestException('Kitchen is outside operating hours.');
    }

    // --- Validate items ---
    const config = await this.prisma.platformConfig.findUniqueOrThrow({
      where: { id: 1 },
    });

    const itemIds = dto.items.map((i) => i.menuItemId);
    const menuItems = await this.prisma.menuItem.findMany({
      where: { id: { in: itemIds }, kitchenId: dto.kitchenId, isActive: true },
    });
    if (menuItems.length !== new Set(itemIds).size) {
      throw new BadRequestException(
        'One or more items are unavailable or not from this kitchen.',
      );
    }
    const byId = new Map(menuItems.map((m) => [m.id, m]));

    let foodTotal = 0;
    let deliveryFee = 0;
    for (const line of dto.items) {
      const item = byId.get(line.menuItemId)!;
      foodTotal += item.pricePaise * line.quantity;
      if (dto.fulfillment === FulfillmentType.delivery) {
        if (!item.deliveryAvailable) {
          throw new BadRequestException(`"${item.name}" is pickup-only.`);
        }
        deliveryFee += item.deliveryFeePaise;
      }
    }

    const platformFee = config.platformFeePaise;
    const grandTotal = foodTotal + platformFee + deliveryFee;

    const order = await this.prisma.$transaction(async (tx) => {
      // --- Gap #6: decrement plate counts atomically ---
      for (const line of dto.items) {
        const item = byId.get(line.menuItemId)!;
        const updated = await tx.menuDailyAvailability.updateMany({
          where: {
            menuItemId: line.menuItemId,
            serviceDate: today,
            isAvailable: true,
            platesRemaining: { gte: line.quantity },
          },
          data: {
            platesRemaining: { decrement: line.quantity },
          },
        });
        if (updated.count === 0) {
          throw new BadRequestException(
            `"${item.name}" has insufficient plates available.`,
          );
        }
      }

      return tx.order.create({
        data: {
          customerId: dto.customerId,
          kitchenId: dto.kitchenId,
          fulfillment: dto.fulfillment,
          status: OrderStatus.received,
          foodTotalPaise: foodTotal,
          platformFeePaise: platformFee,
          deliveryFeePaise: deliveryFee,
          grandTotalPaise: grandTotal,
          handoverCode: this.fourDigitCode(),
          items: {
            create: dto.items.map((line) => {
              const item = byId.get(line.menuItemId)!;
              return {
                menuItemId: item.id,
                itemName: item.name,
                unitPricePaise: item.pricePaise,
                quantity: line.quantity,
                preferences: line.preferences?.length
                  ? { create: line.preferences.map((p) => ({ preference: p })) }
                  : undefined,
              };
            }),
          },
          statusHistory: { create: { status: OrderStatus.received } },
          payment: {
            create: {
              amountPaise: grandTotal,
              status: PaymentStatus.created,
            },
          },
        },
        include: { items: { include: { preferences: true } }, payment: true },
      });
    });

    // --- Low-stock / sold-out alerts (fire-and-forget, after transaction) ---
    for (const line of dto.items) {
      const avail = await this.prisma.menuDailyAvailability.findUnique({
        where: { menuItemId_serviceDate: { menuItemId: line.menuItemId, serviceDate: today } },
        include: { menuItem: true },
      });
      if (!avail) continue;

      if (avail.platesRemaining === 0) {
        // Auto-disable: no more plates left
        await this.prisma.menuDailyAvailability.update({
          where: { menuItemId_serviceDate: { menuItemId: line.menuItemId, serviceDate: today } },
          data: { isAvailable: false },
        });
        await this.notifications.sendPush('kitchen', dto.kitchenId, {
          type: 'stock_alert',
          menuItemId: line.menuItemId,
          itemName: avail.menuItem.name,
          message: `"${avail.menuItem.name}" is now SOLD OUT for today. No more orders will be accepted.`,
        });
      } else if (avail.platesRemaining <= config.lowStockThreshold) {
        // Low stock warning
        await this.notifications.sendPush('kitchen', dto.kitchenId, {
          type: 'stock_alert',
          menuItemId: line.menuItemId,
          itemName: avail.menuItem.name,
          remaining: String(avail.platesRemaining),
          message: `"${avail.menuItem.name}" has only ${avail.platesRemaining} plate(s) left!`,
        });
      }
    }

    return order;
  }

  private async transition(
    orderId: string,
    from: OrderStatus[],
    to: OrderStatus,
    extra: Prisma.OrderUpdateInput = {},
  ) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found.');
    if (!from.includes(order.status)) {
      throw new BadRequestException(
        `Cannot move an order from "${order.status}" to "${to}".`,
      );
    }
    return this.prisma.order.update({
      where: { id: orderId },
      data: { status: to, ...extra, statusHistory: { create: { status: to } } },
    });
  }

  accept(orderId: string, etaMinutes: number) {
    return this.transition(orderId, [OrderStatus.received], OrderStatus.preparing, {
      acceptedAt: new Date(),
      etaMinutes,
    });
  }

  async reject(orderId: string, reason?: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { items: true },
    });
    if (!order) throw new NotFoundException('Order not found.');
    if (order.status !== OrderStatus.received) {
      throw new BadRequestException(
        `Cannot move an order from "${order.status}" to "rejected".`,
      );
    }
    const today = this.serviceDate();
    return this.prisma.$transaction(async (tx) => {
      for (const item of order.items) {
        await tx.menuDailyAvailability.updateMany({
          where: { menuItemId: item.menuItemId, serviceDate: today },
          data: {
            platesRemaining: { increment: item.quantity },
            isAvailable: true,
          },
        });
      }
      return tx.order.update({
        where: { id: orderId },
        data: {
          status: OrderStatus.rejected,
          rejectReason: reason,
          statusHistory: { create: { status: OrderStatus.rejected } },
        },
      });
    });
  }

  async cancel(orderId: string, reason?: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { items: true },
    });
    if (!order) throw new NotFoundException('Order not found.');
    if (order.status !== OrderStatus.received) {
      throw new BadRequestException(
        `Cannot move an order from "${order.status}" to "cancelled".`,
      );
    }
    const today = this.serviceDate();
    return this.prisma.$transaction(async (tx) => {
      for (const item of order.items) {
        await tx.menuDailyAvailability.updateMany({
          where: { menuItemId: item.menuItemId, serviceDate: today },
          data: {
            platesRemaining: { increment: item.quantity },
            isAvailable: true,
          },
        });
      }
      return tx.order.update({
        where: { id: orderId },
        data: {
          status: OrderStatus.cancelled,
          cancelReason: reason,
          cancelledAt: new Date(),
          statusHistory: { create: { status: OrderStatus.cancelled } },
        },
      });
    });
  }

  markReady(orderId: string) {
    return this.transition(
      orderId,
      [OrderStatus.preparing],
      OrderStatus.ready,
      { readyAt: new Date() },
    );
  }

  async confirmHandover(orderId: string, code: string) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found.');
    if (order.handoverCode !== code) {
      throw new BadRequestException('Handover code does not match.');
    }
    return this.transition(
      orderId,
      [OrderStatus.ready, OrderStatus.customer_arrived],
      OrderStatus.completed,
      { completedAt: new Date() },
    );
  }

  findOne(orderId: string) {
    return this.prisma.order.findUniqueOrThrow({
      where: { id: orderId },
      // Never expose handoverCode on this endpoint — the seller app reads it.
      // The code is proof-of-pickup and must only be known to the customer.
      omit: { handoverCode: true },
      include: {
        items: { include: { preferences: true } },
        payment: true,
        kitchen: true,
      },
    });
  }
}
