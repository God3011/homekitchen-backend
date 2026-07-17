import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OrderStatus, PaymentStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RazorpayService } from './razorpay.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly razorpay: RazorpayService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Fires the "new order" push to the kitchen — sent on payment CAPTURE (not at
   * order placement) so sellers only ever see paid orders. Best-effort.
   */
  private async notifyKitchenOrderReceived(orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: { id: true, kitchenId: true, customerId: true },
    });
    if (!order) return;
    try {
      await this.notifications.notifyOrderEvent({
        kitchenId: order.kitchenId,
        customerId: order.customerId,
        orderId: order.id,
        event: 'received',
      });
    } catch {
      /* best-effort — a missed push must not fail payment capture */
    }
  }

  /**
   * Creates a Razorpay order for an existing Payment record.
   * Called by the customer app right before opening checkout.
   */
  async createRazorpayOrder(orderId: string, customerId: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { orderId },
      include: { order: { select: { customerId: true } } },
    });
    if (!payment) throw new NotFoundException('Payment not found.');
    if (payment.order.customerId !== customerId) {
      throw new BadRequestException('This order does not belong to you.');
    }

    // Razorpay keys not configured yet → degrade gracefully. The app treats an
    // empty keyId as "skip checkout": the order stays placed and payment stays
    // pending, so the flow is testable before keys are added.
    if (!this.razorpay.isConfigured) {
      return {
        razorpayOrderId: null,
        amountPaise: payment.amountPaise,
        currency: 'INR',
        keyId: '',
      };
    }

    // Idempotent — return existing Razorpay order if already created
    if (payment.razorpayOrderId) {
      return {
        razorpayOrderId: payment.razorpayOrderId,
        amountPaise: payment.amountPaise,
        currency: 'INR',
        keyId: this.razorpay.publicKeyId,
      };
    }

    const rpOrder = await this.razorpay.createOrder(
      payment.amountPaise,
      orderId,
    );

    await this.prisma.payment.update({
      where: { id: payment.id },
      data: { razorpayOrderId: rpOrder.id },
    });

    return {
      razorpayOrderId: rpOrder.id,
      amountPaise: payment.amountPaise,
      currency: 'INR',
      // Public key_id so the app can open the Razorpay checkout sheet.
      keyId: this.razorpay.publicKeyId,
    };
  }

  /**
   * Client-side verification after Razorpay checkout completes.
   * Verifies the signature and marks Payment as captured.
   */
  async verifyPayment(
    razorpayOrderId: string,
    razorpayPaymentId: string,
    razorpaySignature: string,
  ) {
    const valid = this.razorpay.verifyPaymentSignature(
      razorpayOrderId,
      razorpayPaymentId,
      razorpaySignature,
    );
    if (!valid) {
      throw new BadRequestException('Invalid payment signature.');
    }

    const payment = await this.prisma.payment.findFirst({
      where: { razorpayOrderId },
      include: { order: { select: { status: true } } },
    });
    if (!payment) throw new NotFoundException('Payment not found.');

    // Webhook may have arrived first — skip if already captured (also avoids a
    // duplicate "new order" push, since that fires only on the transition).
    if (payment.status === PaymentStatus.captured) {
      return payment;
    }

    // The order may have been cancelled/rejected (e.g. the TTL sweep fired while
    // the customer was retrying). Don't capture money against a dead order.
    // (Production should trigger a Razorpay refund here.)
    if (
      payment.order.status === OrderStatus.cancelled ||
      payment.order.status === OrderStatus.rejected
    ) {
      throw new BadRequestException(
        'This order is no longer active; payment was not accepted.',
      );
    }

    const updated = await this.prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: PaymentStatus.captured,
        razorpayPayId: razorpayPaymentId,
      },
    });
    await this.notifyKitchenOrderReceived(payment.orderId);
    return updated;
  }

  /**
   * Handles Razorpay webhook events (payment.captured, payment.failed).
   * Signature is verified against the raw request body.
   */
  async handleWebhook(rawBody: string, signature: string) {
    const valid = this.razorpay.verifyWebhookSignature(rawBody, signature);
    if (!valid) {
      throw new BadRequestException('Invalid webhook signature.');
    }

    const event = JSON.parse(rawBody);
    const entity = event.payload?.payment?.entity;
    if (!entity) return { status: 'ignored' };

    const razorpayOrderId: string | undefined = entity.order_id;
    const razorpayPaymentId: string | undefined = entity.id;
    const method: string | undefined = entity.method;

    if (!razorpayOrderId) return { status: 'ignored' };

    const payment = await this.prisma.payment.findFirst({
      where: { razorpayOrderId },
    });
    if (!payment) return { status: 'ignored' };

    if (event.event === 'payment.captured') {
      const wasCaptured = payment.status === PaymentStatus.captured;
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: PaymentStatus.captured,
          razorpayPayId: razorpayPaymentId,
          method,
        },
      });
      // Notify the kitchen only on the first transition to captured (idempotent
      // across a verify + webhook double-capture).
      if (!wasCaptured) {
        await this.notifyKitchenOrderReceived(payment.orderId);
      }
    } else if (event.event === 'payment.failed') {
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: { status: PaymentStatus.failed },
      });
    }

    return { status: 'ok' };
  }
}
