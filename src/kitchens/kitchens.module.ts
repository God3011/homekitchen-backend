import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { KitchensController } from './kitchens.controller';
import { KitchensService } from './kitchens.service';

@Module({
  imports: [AuthModule],
  controllers: [KitchensController],
  providers: [KitchensService],
})
export class KitchensModule {}
