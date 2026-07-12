import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { getMessaging, Messaging } from 'firebase-admin/messaging';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);
  private messaging: Messaging;

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    this.messaging = getMessaging();
  }

  // ── Device tokens ────────────────────────────────────────────────────
  registerToken(
    ownerType: string,
    ownerId: string,
    fcmToken: string,
    deviceInfo?: string,
  ) {
    return this.prisma.deviceToken.upsert({
      where: { fcmToken },
      create: { ownerType, ownerId, fcmToken, deviceInfo },
      update: { ownerType, ownerId, deviceInfo },
    });
  }

  async removeToken(fcmToken: string) {
    await this.prisma.deviceToken.deleteMany({ where: { fcmToken } });
    return { removed: true };
  }

  // ── FCM push (DATA-only, high-priority) ──────────────────────────────
  /**
   * Sends a high-priority DATA message to all devices registered for
   * the given owner. DATA-only (no `notification` key) so the app's
   * foreground service can handle display on budget Android OEMs.
   */
  async sendPush(
    ownerType: string,
    ownerId: string,
    data: Record<string, string>,
  ) {
    const deviceTokens = await this.prisma.deviceToken.findMany({
      where: { ownerType, ownerId },
    });
    if (!deviceTokens.length) return;

    const tokens = deviceTokens.map((t) => t.fcmToken);

    const response = await this.messaging.sendEachForMulticast({
      tokens,
      data,
      android: { priority: 'high' },
    });

    // Clean up invalid/expired tokens
    const staleTokens: string[] = [];
    response.responses.forEach((res, idx) => {
      if (
        !res.success &&
        res.error?.code &&
        [
          'messaging/registration-token-not-registered',
          'messaging/invalid-registration-token',
        ].includes(res.error.code)
      ) {
        staleTokens.push(tokens[idx]);
      }
    });

    if (staleTokens.length) {
      await this.prisma.deviceToken.deleteMany({
        where: { fcmToken: { in: staleTokens } },
      });
      this.logger.warn(`Cleaned up ${staleTokens.length} stale FCM token(s).`);
    }
  }

  // ── WhatsApp fallback ────────────────────────────────────────────────
  /**
   * Sends a WhatsApp message via Business API.
   * TODO: Integrate with Twilio / Gupshup once provider is chosen.
   */
  async sendWhatsApp(phone: string, message: string) {
    this.logger.log(`[WhatsApp stub] To: ${phone} — ${message}`);
  }

  // ── Order event dispatcher ───────────────────────────────────────────
  /**
   * High-level helper: routes an order event to the right recipient(s).
   * Seller gets customer-side events; customer gets seller-side events.
   * "order ready" fires a WhatsApp fallback (the #1 missed-alert risk).
   */
  async notifyOrderEvent(params: {
    kitchenId: string;
    customerId: string;
    orderId: string;
    event: string;
    customerPhone?: string;
  }) {
    const data = {
      type: 'order_alert',
      orderId: params.orderId,
      event: params.event,
    };

    // Events the seller needs to see
    if (
      ['received', 'customer_en_route', 'customer_arrived', 'cancelled'].includes(
        params.event,
      )
    ) {
      await this.sendPush('kitchen', params.kitchenId, data);
    }

    // Events the customer needs to see
    if (
      ['preparing', 'ready', 'completed', 'rejected'].includes(params.event)
    ) {
      await this.sendPush('customer', params.customerId, data);

      // WhatsApp fallback for "ready" — the most critical pickup alert
      if (params.event === 'ready' && params.customerPhone) {
        await this.sendWhatsApp(
          params.customerPhone,
          'Your order is ready for pickup! Head to the kitchen now.',
        );
      }
    }
  }
}
