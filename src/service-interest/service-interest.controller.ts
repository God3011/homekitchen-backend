import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { ServiceInterestService } from './service-interest.service';
import { CreateServiceInterestDto } from './dto/create-service-interest.dto';
import { Public } from '../auth/decorators';

@Controller('service-interest')
export class ServiceInterestController {
  constructor(private readonly service: ServiceInterestService) {}

  /** Public interest capture for the "not serving your area yet" screen.
   *  Rate-limited (5/min/IP) — this guard is scoped to THIS controller only, so
   *  the rest of the API is unaffected. */
  @Public()
  @Post()
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  capture(@Body() dto: CreateServiceInterestDto) {
    return this.service.capture(dto);
  }
}
