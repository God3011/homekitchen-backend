import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PaymentStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RazorpayService } from './razorpay.service';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly razorpay: RazorpayService,
  ) {}

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

    // Idempotent — return existing Razorpay order if already created
    if (payment.razorpayOrderId) {
      return {
        razorpayOrderId: payment.razorpayOrderId,
        amountPaise: payment.amountPaise,
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

    return { razorpayOrderId: rpOrder.id, amountPaise: payment.amountPaise };
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
    });
    if (!payment) throw new NotFoundException('Payment not found.');

    // Webhook may have arrived first — skip if already captured
    if (payment.status === PaymentStatus.captured) {
      return payment;
    }

    return this.prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: PaymentStatus.captured,
        razorpayPayId: razorpayPaymentId,
      },
    });
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
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: PaymentStatus.captured,
          razorpayPayId: razorpayPaymentId,
          method,
        },
      });
    } else if (event.event === 'payment.failed') {
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: { status: PaymentStatus.failed },
      });
    }

    return { status: 'ok' };
  }
}
