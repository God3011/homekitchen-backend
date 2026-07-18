import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateServiceInterestDto } from './dto/create-service-interest.dto';

@Injectable()
export class ServiceInterestService {
  constructor(private readonly prisma: PrismaService) {}

  /** Records interest from a location with no serviceable kitchens in range. */
  async capture(dto: CreateServiceInterestDto) {
    await this.prisma.serviceInterest.create({
      data: { lat: dto.lat, lng: dto.lng, phone: dto.phone },
    });
    return { ok: true };
  }
}
