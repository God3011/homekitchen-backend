import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ZonesModule } from '../zones/zones.module';
import { KitchensController } from './kitchens.controller';
import { KitchensService } from './kitchens.service';

@Module({
  imports: [AuthModule, ZonesModule],
  controllers: [KitchensController],
  providers: [KitchensService],
})
export class KitchensModule {}
