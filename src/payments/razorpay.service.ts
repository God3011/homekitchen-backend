import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Razorpay from 'razorpay';
import * as crypto from 'crypto';

@Injectable()
export class RazorpayService implements OnModuleInit {
  private client: Razorpay | null = null;
  private keyId = '';
  private keySecret = '';
  private webhookSecret = '';

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const keyId = this.config.get<string>('RAZORPAY_KEY_ID');
    const keySecret = this.config.get<string>('RAZORPAY_KEY_SECRET');
    this.webhookSecret =
      this.config.get<string>('RAZORPAY_WEBHOOK_SECRET') ?? '';

    if (keyId && keySecret) {
      this.keyId = keyId;
      this.keySecret = keySecret;
      this.client = new Razorpay({ key_id: keyId, key_secret: keySecret });
    }
  }

  /** Public key_id — safe to hand to the client so it can open checkout. */
  get publicKeyId(): string {
    return this.keyId;
  }

  /** True once RAZORPAY_KEY_ID + RAZORPAY_KEY_SECRET are set and the client
   *  is initialised. Lets callers degrade gracefully before keys are added. */
  get isConfigured(): boolean {
    return this.client !== null;
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
    // Razorpay's floor is 100 paise (₹1). Our amounts are server-derived
    // (grand total ≥ the ₹5 platform fee), but guard defensively anyway.
    if (!Number.isInteger(amountPaise) || amountPaise < 100) {
      throw new Error('Order amount must be an integer ≥ 100 paise.');
    }
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
    const expected = crypto
      .createHmac('sha256', this.keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');
    return this.safeEqual(expected, signature);
  }

  verifyWebhookSignature(body: string, signature: string): boolean {
    const expected = crypto
      .createHmac('sha256', this.webhookSecret)
      .update(body)
      .digest('hex');
    return this.safeEqual(expected, signature);
  }

  /** Constant-time hex-string comparison — avoids leaking signature bytes via
   *  timing. Returns false on any length mismatch or missing value. */
  private safeEqual(expected: string, actual: string | undefined): boolean {
    if (!actual) return false;
    const a = Buffer.from(expected, 'utf8');
    const b = Buffer.from(actual, 'utf8');
    if (a.length !== b.length) return false;
    return crypto.timingSafeEqual(a, b);
  }
}
