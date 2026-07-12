import { Module } from '@nestjs/common';
import { KitchensController } from './kitchens.controller';
import { KitchensService } from './kitchens.service';

@Module({
  controllers: [KitchensController],
  providers: [KitchensService],
})
export class KitchensModule {}
