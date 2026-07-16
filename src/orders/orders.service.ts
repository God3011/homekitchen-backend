import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
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
import { RequestUser } from '../auth/decorators';

@Injectable()
export class OrdersService {
  private readonly logger = new Logger(OrdersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  private fourDigitCode(): string {
    return Math.floor(1000 + Math.random() * 9000).toString();
  }

  /**
   * Fire an order-event push (routes to the right recipient in
   * NotificationsService). Swallows failures — a missed push must never fail
   * the order action that triggered it. WhatsApp fallback fires on "ready".
   */
  private notify(params: {
    kitchenId: string;
    customerId: string;
    orderId: string;
    event: string;
    customerPhone?: string;
  }) {
    return this.notifications.notifyOrderEvent(params).catch((err) => {
      this.logger.warn(
        `Order notification failed (order=${params.orderId}, event=${params.event}): ${err}`,
      );
    });
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

  async create(customerId: string, dto: CreateOrderDto) {
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
          customerId,
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

    // NOTE: the "new order" push to the kitchen is intentionally NOT sent here.
    // It fires only once payment is captured (see PaymentsService) so sellers
    // never see unpaid orders. Unpaid orders are auto-cancelled after a TTL by
    // expireUnpaidOrders() below. Stock alerts above still fire on placement
    // because plates are physically reserved at placement.
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

  /** Loads an order and asserts the given kitchen owns it (seller actions). */
  private async assertKitchenOwns(orderId: string, kitchenId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: { kitchenId: true },
    });
    if (!order) throw new NotFoundException('Order not found.');
    if (order.kitchenId !== kitchenId) {
      throw new ForbiddenException('This order belongs to another kitchen.');
    }
  }

  async accept(orderId: string, kitchenId: string, etaMinutes: number) {
    await this.assertKitchenOwns(orderId, kitchenId);
    const order = await this.transition(
      orderId,
      [OrderStatus.received],
      OrderStatus.preparing,
      { acceptedAt: new Date(), etaMinutes },
    );
    await this.notify({
      kitchenId: order.kitchenId,
      customerId: order.customerId,
      orderId: order.id,
      event: 'preparing',
    });
    return order;
  }

  async reject(orderId: string, kitchenId: string, reason?: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { items: true },
    });
    if (!order) throw new NotFoundException('Order not found.');
    if (order.kitchenId !== kitchenId) {
      throw new ForbiddenException('This order belongs to another kitchen.');
    }
    if (order.status !== OrderStatus.received) {
      throw new BadRequestException(
        `Cannot move an order from "${order.status}" to "rejected".`,
      );
    }
    const today = this.serviceDate();
    const updated = await this.prisma.$transaction(async (tx) => {
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

    await this.notify({
      kitchenId: updated.kitchenId,
      customerId: updated.customerId,
      orderId: updated.id,
      event: 'rejected',
    });
    return updated;
  }

  async cancel(orderId: string, customerId: string, reason?: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { items: true, payment: true },
    });
    if (!order) throw new NotFoundException('Order not found.');
    if (order.customerId !== customerId) {
      throw new ForbiddenException('This order belongs to another customer.');
    }
    if (order.status !== OrderStatus.received) {
      throw new BadRequestException(
        `Cannot move an order from "${order.status}" to "cancelled".`,
      );
    }
    const today = this.serviceDate();
    const updated = await this.prisma.$transaction(async (tx) => {
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

    // Only tell the kitchen if it was ever told about this order in the first
    // place — the "new order" push fires on payment capture, so an unpaid order
    // the seller never saw shouldn't produce a "cancelled" push either.
    if (order.payment?.status === PaymentStatus.captured) {
      await this.notify({
        kitchenId: updated.kitchenId,
        customerId: updated.customerId,
        orderId: updated.id,
        event: 'cancelled',
      });
    }
    return updated;
  }

  /** UTC-midnight of the local day a timestamp falls on — matches how plates
   *  were reserved at placement (see serviceDate()). */
  private serviceDateOf(ts: Date): Date {
    return new Date(Date.UTC(ts.getFullYear(), ts.getMonth(), ts.getDate()));
  }

  /**
   * Auto-cancels orders still awaiting payment past the TTL and restores their
   * plates. Only touches orders where a Razorpay order was actually initiated
   * (`razorpayOrderId` set) but never captured — so the no-keys/degraded flow
   * and paid orders are left alone. The kitchen was never notified about these
   * (that push waits for capture), so only the customer is told. Returns the
   * number of orders expired. Safe to call repeatedly.
   */
  async expireUnpaidOrders(olderThanMinutes = 10): Promise<number> {
    const cutoff = new Date(Date.now() - olderThanMinutes * 60_000);
    const stale = await this.prisma.order.findMany({
      where: {
        status: OrderStatus.received,
        placedAt: { lt: cutoff },
        payment: {
          is: {
            status: { not: PaymentStatus.captured },
            razorpayOrderId: { not: null },
          },
        },
      },
      include: { items: true },
    });

    let expired = 0;
    for (const order of stale) {
      const serviceDate = this.serviceDateOf(order.placedAt);
      const didCancel = await this.prisma.$transaction(async (tx) => {
        // Guard against a concurrent accept: only cancel if still "received".
        const upd = await tx.order.updateMany({
          where: { id: order.id, status: OrderStatus.received },
          data: {
            status: OrderStatus.cancelled,
            cancelReason: 'Payment not completed in time',
            cancelledAt: new Date(),
          },
        });
        if (upd.count === 0) return false;
        await tx.orderStatusHistory.create({
          data: { orderId: order.id, status: OrderStatus.cancelled },
        });
        for (const item of order.items) {
          await tx.menuDailyAvailability.updateMany({
            where: { menuItemId: item.menuItemId, serviceDate },
            data: {
              platesRemaining: { increment: item.quantity },
              isAvailable: true,
            },
          });
        }
        return true;
      });

      if (didCancel) {
        expired++;
        // Tell the customer (kitchen never saw this order). Best-effort.
        this.notifications
          .sendPush('customer', order.customerId, {
            type: 'order_alert',
            event: 'expired',
            orderId: order.id,
            message:
              'Your order was cancelled because payment was not completed in time.',
          })
          .catch(() => {});
      }
    }
    if (expired > 0) {
      this.logger.log(`Expired ${expired} unpaid order(s).`);
    }
    return expired;
  }

  async markReady(orderId: string, kitchenId: string) {
    await this.assertKitchenOwns(orderId, kitchenId);
    const order = await this.transition(
      orderId,
      [OrderStatus.preparing],
      OrderStatus.ready,
      { readyAt: new Date() },
    );
    // "ready" also triggers a WhatsApp fallback — the #1 missed-alert risk — so
    // fetch the customer's phone for it.
    const customer = await this.prisma.customer.findUnique({
      where: { id: order.customerId },
      select: { phone: true },
    });
    await this.notify({
      kitchenId: order.kitchenId,
      customerId: order.customerId,
      orderId: order.id,
      event: 'ready',
      customerPhone: customer?.phone,
    });
    return order;
  }

  async confirmHandover(orderId: string, kitchenId: string, code: string) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found.');
    if (order.kitchenId !== kitchenId) {
      throw new ForbiddenException('This order belongs to another kitchen.');
    }
    if (order.handoverCode !== code) {
      throw new BadRequestException('Handover code does not match.');
    }
    const updated = await this.transition(
      orderId,
      [OrderStatus.ready, OrderStatus.customer_arrived],
      OrderStatus.completed,
      { completedAt: new Date() },
    );
    await this.notify({
      kitchenId: updated.kitchenId,
      customerId: updated.customerId,
      orderId: updated.id,
      event: 'completed',
    });
    return updated;
  }

  async findOne(orderId: string, user: RequestUser) {
    const order = await this.prisma.order.findUniqueOrThrow({
      where: { id: orderId },
      include: {
        items: { include: { preferences: true } },
        payment: true,
        kitchen: true,
        rating: true,
      },
    });

    // Only the owning customer or the order's kitchen may read it.
    const isOwningCustomer =
      user.role === 'customer' && order.customerId === user.userId;
    const isOwningKitchen =
      user.role === 'kitchen' && order.kitchenId === user.userId;
    if (!isOwningCustomer && !isOwningKitchen) {
      throw new ForbiddenException('You do not have access to this order.');
    }

    // handoverCode is proof-of-pickup: the customer reads it aloud, the seller
    // enters it. Return it only to the owning customer, never to the kitchen.
    if (!isOwningCustomer) {
      const { handoverCode: _omit, ...rest } = order;
      return rest;
    }
    return order;
  }

  // ── Ratings ──────────────────────────────────────────────────────────────
  async rate(
    orderId: string,
    customerId: string,
    stars: number,
    comment?: string,
  ) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { rating: true },
    });
    if (!order) throw new NotFoundException('Order not found.');
    if (order.customerId !== customerId) {
      throw new ForbiddenException('This order belongs to another customer.');
    }
    if (order.status !== OrderStatus.completed) {
      throw new BadRequestException('Only completed orders can be rated.');
    }
    if (order.rating) {
      throw new ConflictException('This order has already been rated.');
    }
    return this.prisma.rating.create({
      data: {
        orderId,
        customerId,
        kitchenId: order.kitchenId,
        stars,
        comment,
      },
    });
  }
}
