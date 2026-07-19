import { Module } from '@nestjs/common';
import { KitchensModule } from '../kitchens/kitchens.module';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [KitchensModule], // for KitchensService.pendingBalancePaise
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
