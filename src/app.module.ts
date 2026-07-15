import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { LoggingMiddleware } from './common/logging.middleware';
import { PrismaModule } from './prisma/prisma.module';
import { HealthController } from './health/health.controller';
import { OrdersModule } from './orders/orders.module';
import { KitchensModule } from './kitchens/kitchens.module';
import { MenuModule } from './menu/menu.module';
import { PaymentsModule } from './payments/payments.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AuthModule } from './auth/auth.module';
import { StorageModule } from './storage/storage.module';
import { ZonesModule } from './zones/zones.module';
import { GeocodeModule } from './geocode/geocode.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    StorageModule,
    AuthModule,
    KitchensModule,
    MenuModule,
    OrdersModule,
    PaymentsModule,
    NotificationsModule,
    ZonesModule,
    GeocodeModule,
  ],
  controllers: [HealthController],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(LoggingMiddleware).forRoutes('*');
  }
}
