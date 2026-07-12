import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  FulfillmentType,
  OrderStatus,
  PaymentStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOrderDto } from './dto/create-order.dto';

@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}

  private fourDigitCode(): string {
    return Math.floor(1000 + Math.random() * 9000).toString();
  }

  /**
   * Places an order. Prices/names are snapshotted from the live menu so later
   * menu edits never rewrite history. Enforces the ₹200 food cap and the flat
   * ₹5 platform fee. Order + items + preferences + a "created" Payment + the
   * first status-history row are written atomically in one transaction.
   */
  async create(dto: CreateOrderDto) {
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

    if (foodTotal > config.orderCapPaise) {
      throw new BadRequestException(
        `Order exceeds the ₹${config.orderCapPaise / 100} cap.`,
      );
    }

    const platformFee = config.platformFeePaise;
    const grandTotal = foodTotal + platformFee + deliveryFee;

    return this.prisma.$transaction(async (tx) => {
      const order = await tx.order.create({
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
      return order;
    });
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

  reject(orderId: string, reason?: string) {
    return this.transition(orderId, [OrderStatus.received], OrderStatus.rejected, {
      rejectReason: reason,
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
      include: {
        items: { include: { preferences: true } },
        payment: true,
        kitchen: true,
      },
    });
  }
}
