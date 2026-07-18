import { Module } from '@nestjs/common';
import { ServiceInterestController } from './service-interest.controller';
import { ServiceInterestService } from './service-interest.service';

@Module({
  controllers: [ServiceInterestController],
  providers: [ServiceInterestService],
})
export class ServiceInterestModule {}
