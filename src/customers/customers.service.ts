import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FirebaseService } from '../auth/firebase.service';
import { ZonesService } from '../zones/zones.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';

@Injectable()
export class CustomersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly firebase: FirebaseService,
    private readonly zones: ZonesService,
  ) {}

  /** Home zone from GPS when provided (containing zone or a new one), else
   *  undefined. Server-authoritative so the client can't mis-assign. */
  private async resolveHomeZoneId(dto: {
    lat?: number | null;
    lng?: number | null;
  }): Promise<string | undefined> {
    if (dto.lat != null && dto.lng != null) {
      const zone = await this.zones.resolveOrCreate(dto.lat, dto.lng);
      return zone.id;
    }
    return undefined;
  }

  // ── Signup (public — token verified here, mirrors KitchensService) ──────
  async signup(idToken: string, dto: CreateCustomerDto) {
    if (!idToken) {
      throw new UnauthorizedException('Missing Firebase token.');
    }

    let decoded;
    try {
      decoded = await this.firebase.verifyIdToken(idToken);
    } catch {
      throw new UnauthorizedException('Invalid or expired Firebase token.');
    }

    const firebaseUid = decoded.uid;
    const phone: string | undefined = decoded.phone_number;
    if (!phone) {
      throw new BadRequestException(
        'Firebase token must include a phone number.',
      );
    }

    const existing = await this.prisma.customer.findFirst({
      where: { OR: [{ firebaseUid }, { phone }] },
    });
    if (existing) {
      throw new ConflictException(
        'A customer account already exists for this user.',
      );
    }

    return this.prisma.customer.create({
      data: {
        firebaseUid,
        phone,
        name: dto.name,
        homeZoneId: await this.resolveHomeZoneId(dto),
        whatsappOptIn: dto.whatsappOptIn ?? false,
      },
      include: { homeZone: true },
    });
  }

  // ── Profile ─────────────────────────────────────────────────────────────
  getProfile(customerId: string) {
    return this.prisma.customer.findUniqueOrThrow({
      where: { id: customerId },
      include: { homeZone: true },
    });
  }

  // ── Orders ────────────────────────────────────────────────────────────
  /** The customer's own orders, newest first. handoverCode is included — these
   *  are the caller's own orders and the code is their proof of pickup. */
  listOrders(customerId: string) {
    return this.prisma.order.findMany({
      where: { customerId },
      orderBy: { placedAt: 'desc' },
      include: {
        items: { include: { preferences: true } },
        payment: true,
        kitchen: true,
        rating: true,
      },
    });
  }

  async updateProfile(customerId: string, dto: UpdateCustomerDto) {
    const homeZoneId = await this.resolveHomeZoneId(dto);
    return this.prisma.customer.update({
      where: { id: customerId },
      data: {
        ...(dto.name !== undefined ? { name: dto.name } : {}),
        ...(dto.whatsappOptIn !== undefined
          ? { whatsappOptIn: dto.whatsappOptIn }
          : {}),
        ...(homeZoneId ? { homeZoneId } : {}),
      },
      include: { homeZone: true },
    });
  }
}
