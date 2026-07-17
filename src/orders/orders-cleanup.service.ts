import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { OrdersService } from './orders.service';

/**
 * Periodically releases orders whose payment was never completed. Uses a plain
 * unref'd interval (no extra scheduler dependency) so it never keeps the process
 * or the test runner alive. The TTL lives here so it's easy to tune.
 */
@Injectable()
export class OrdersCleanupService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OrdersCleanupService.name);
  private timer?: ReturnType<typeof setInterval>;

  /** How long an order may sit unpaid before it's auto-cancelled. Gives the
   *  customer a comfortable window to retry payment on the same order. */
  private static readonly TTL_MINUTES = 15;
  /** How often to sweep for stale orders. */
  private static readonly SWEEP_MS = 60_000;

  constructor(private readonly orders: OrdersService) {}

  onModuleInit() {
    this.timer = setInterval(() => {
      this.orders
        .expireUnpaidOrders(OrdersCleanupService.TTL_MINUTES)
        .catch((err) => this.logger.warn(`Expiry sweep failed: ${err}`));
    }, OrdersCleanupService.SWEEP_MS);
    // Don't let this interval hold the event loop open.
    this.timer.unref?.();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }
}
