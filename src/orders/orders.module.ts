import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { OrdersCleanupService } from './orders-cleanup.service';

@Module({
  imports: [NotificationsModule],
  controllers: [OrdersController],
  providers: [OrdersService, OrdersCleanupService],
  exports: [OrdersService],
})
export class OrdersModule {}
