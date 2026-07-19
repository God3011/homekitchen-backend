import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { LoggingMiddleware } from './common/logging.middleware';
import { PrismaModule } from './prisma/prisma.module';
import { HealthController } from './health/health.controller';
import { OrdersModule } from './orders/orders.module';
import { KitchensModule } from './kitchens/kitchens.module';
import { CustomersModule } from './customers/customers.module';
import { FavoritesModule } from './favorites/favorites.module';
import { MenuModule } from './menu/menu.module';
import { PaymentsModule } from './payments/payments.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AuthModule } from './auth/auth.module';
import { StorageModule } from './storage/storage.module';
import { ZonesModule } from './zones/zones.module';
import { GeocodeModule } from './geocode/geocode.module';
import { ServiceInterestModule } from './service-interest/service-interest.module';
import { AdminModule } from './admin/admin.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // Throttler is registered globally so ThrottlerGuard can be resolved, but it
    // is applied per-route (only the service-interest controller opts in via
    // @UseGuards), so the rest of the API is NOT rate-limited.
    ThrottlerModule.forRoot({ throttlers: [{ ttl: 60000, limit: 5 }] }),
    PrismaModule,
    StorageModule,
    AuthModule,
    KitchensModule,
    CustomersModule,
    MenuModule,
    OrdersModule,
    PaymentsModule,
    NotificationsModule,
    ZonesModule,
    GeocodeModule,
    FavoritesModule,
    ServiceInterestModule,
    AdminModule,
  ],
  controllers: [HealthController],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(LoggingMiddleware).forRoutes('*');
  }
}
