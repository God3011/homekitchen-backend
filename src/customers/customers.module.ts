import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ZonesModule } from '../zones/zones.module';
import { CustomersController } from './customers.controller';
import { CustomersService } from './customers.service';
import { AddressesService } from './addresses.service';

@Module({
  imports: [AuthModule, ZonesModule],
  controllers: [CustomersController],
  providers: [CustomersService, AddressesService],
})
export class CustomersModule {}
