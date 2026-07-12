import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Razorpay from 'razorpay';
import * as crypto from 'crypto';

@Injectable()
export class RazorpayService implements OnModuleInit {
  private client: Razorpay | null = null;
  private keySecret = '';
  private webhookSecret = '';

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const keyId = this.config.get<string>('RAZORPAY_KEY_ID');
    const keySecret = this.config.get<string>('RAZORPAY_KEY_SECRET');
    this.webhookSecret =
      this.config.get<string>('RAZORPAY_WEBHOOK_SECRET') ?? '';

    if (keyId && keySecret) {
      this.keySecret = keySecret;
      this.client = new Razorpay({ key_id: keyId, key_secret: keySecret });
    }
  }

  private requireClient(): Razorpay {
    if (!this.client) {
      throw new Error(
        'Razorpay not configured. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET.',
      );
    }
    return this.client;
  }

  async createOrder(amountPaise: number, receipt: string) {
    return this.requireClient().orders.create({
      amount: amountPaise,
      currency: 'INR',
      receipt,
    });
  }

  verifyPaymentSignature(
    razorpayOrderId: string,
    razorpayPaymentId: string,
    signature: string,
  ): boolean {
    const body = `${razorpayOrderId}|${razorpayPaymentId}`;
    const expected = crypto
      .createHmac('sha256', this.keySecret)
      .update(body)
      .digest('hex');
    return expected === signature;
  }

  verifyWebhookSignature(body: string, signature: string): boolean {
    const expected = crypto
      .createHmac('sha256', this.webhookSecret)
      .update(body)
      .digest('hex');
    return expected === signature;
  }
}
