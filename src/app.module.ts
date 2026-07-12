import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { HealthController } from './health/health.controller';
import { OrdersModule } from './orders/orders.module';
import { KitchensModule } from './kitchens/kitchens.module';
import { MenuModule } from './menu/menu.module';
import { PaymentsModule } from './payments/payments.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AuthModule } from './auth/auth.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    KitchensModule,
    MenuModule,
    OrdersModule,
    PaymentsModule,
    NotificationsModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
