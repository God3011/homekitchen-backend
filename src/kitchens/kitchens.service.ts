import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { KitchenStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { FirebaseService } from '../auth/firebase.service';
import { CreateKitchenDto } from './dto/create-kitchen.dto';
import { UpdateKitchenDto } from './dto/update-kitchen.dto';
import {
  SetDailyStatusDto,
  SetKitchenHoursDto,
  UploadDocumentDto,
} from './dto/kitchen-actions.dto';

@Injectable()
export class KitchensService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly firebase: FirebaseService,
  ) {}

  // ── Signup (public) ──────────────────────────────────────────────────
  async signup(idToken: string, dto: CreateKitchenDto) {
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

    const existing = await this.prisma.kitchen.findUnique({
      where: { firebaseUid },
    });
    if (existing) {
      throw new ConflictException(
        'A kitchen account already exists for this user.',
      );
    }

    return this.prisma.kitchen.create({
      data: {
        firebaseUid,
        phone,
        kitchenName: dto.kitchenName,
        cookName: dto.cookName,
        story: dto.story,
        signatureDish: dto.signatureDish,
        addressLine: dto.addressLine,
        lat: dto.lat,
        lng: dto.lng,
        zoneId: dto.zoneId,
        languagePref: dto.languagePref,
      },
    });
  }

  // ── Profile ──────────────────────────────────────────────────────────
  getProfile(kitchenId: string) {
    return this.prisma.kitchen.findUniqueOrThrow({
      where: { id: kitchenId },
      include: { zone: true, documents: true, hours: true },
    });
  }

  updateProfile(kitchenId: string, dto: UpdateKitchenDto) {
    return this.prisma.kitchen.update({
      where: { id: kitchenId },
      data: dto,
    });
  }

  // ── Documents ────────────────────────────────────────────────────────
  uploadDocument(kitchenId: string, dto: UploadDocumentDto) {
    return this.prisma.kitchenDocument.create({
      data: {
        kitchenId,
        docType: dto.docType,
        fileUrl: dto.fileUrl,
      },
    });
  }

  getDocuments(kitchenId: string) {
    return this.prisma.kitchenDocument.findMany({
      where: { kitchenId },
      orderBy: { uploadedAt: 'desc' },
    });
  }

  // ── Hours ────────────────────────────────────────────────────────────
  async setHours(kitchenId: string, dto: SetKitchenHoursDto) {
    return this.prisma.$transaction(async (tx) => {
      await tx.kitchenHours.deleteMany({ where: { kitchenId } });
      await tx.kitchenHours.createMany({
        data: dto.hours.map((h) => ({
          kitchenId,
          dayOfWeek: h.dayOfWeek,
          openTime: h.openTime,
          closeTime: h.closeTime,
        })),
      });
      return tx.kitchenHours.findMany({
        where: { kitchenId },
        orderBy: { dayOfWeek: 'asc' },
      });
    });
  }

  getHours(kitchenId: string) {
    return this.prisma.kitchenHours.findMany({
      where: { kitchenId },
      orderBy: { dayOfWeek: 'asc' },
    });
  }

  // ── Daily status ("Cooking Today?" toggle) ───────────────────────────
  setDailyStatus(kitchenId: string, dto: SetDailyStatusDto) {
    const serviceDate = new Date(dto.serviceDate);

    return this.prisma.kitchenDailyStatus.upsert({
      where: {
        kitchenId_serviceDate: { kitchenId, serviceDate },
      },
      create: { kitchenId, serviceDate, isCooking: dto.isCooking },
      update: { isCooking: dto.isCooking },
    });
  }

  getDailyStatus(kitchenId: string, date: string) {
    const serviceDate = new Date(date);
    return this.prisma.kitchenDailyStatus.findUnique({
      where: {
        kitchenId_serviceDate: { kitchenId, serviceDate },
      },
    });
  }

  // ── Admin ────────────────────────────────────────────────────────────
  verify(kitchenId: string) {
    return this.prisma.kitchen.update({
      where: { id: kitchenId },
      data: { status: KitchenStatus.verified, verifiedAt: new Date() },
    });
  }

  suspend(kitchenId: string) {
    return this.prisma.kitchen.update({
      where: { id: kitchenId },
      data: { status: KitchenStatus.suspended },
    });
  }

  // ── Customer-facing ──────────────────────────────────────────────────
  list(zoneId?: string) {
    const today = new Date();
    const serviceDate = new Date(
      today.getFullYear(),
      today.getMonth(),
      today.getDate(),
    );

    return this.prisma.kitchen.findMany({
      where: {
        status: KitchenStatus.verified,
        ...(zoneId ? { zoneId } : {}),
        dailyStatus: { some: { serviceDate, isCooking: true } },
      },
      select: {
        id: true,
        kitchenName: true,
        cookName: true,
        cookPhotoUrl: true,
        story: true,
        signatureDish: true,
        addressLine: true,
        lat: true,
        lng: true,
        ratings: { select: { stars: true } },
      },
    });
  }

  findOne(kitchenId: string) {
    return this.prisma.kitchen.findUniqueOrThrow({
      where: { id: kitchenId },
      include: {
        zone: true,
        hours: { orderBy: { dayOfWeek: 'asc' } },
        ratings: {
          select: { stars: true, comment: true, createdAt: true },
          orderBy: { createdAt: 'desc' },
          take: 20,
        },
      },
    });
  }
}
