import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { DocType, KitchenStatus, OrderStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { FirebaseService } from '../auth/firebase.service';
import { CreateKitchenDto } from './dto/create-kitchen.dto';
import { UpdateKitchenDto } from './dto/update-kitchen.dto';
import {
  SetDailyStatusDto,
  SetKitchenHoursDto,
  UploadDocumentDto,
} from './dto/kitchen-actions.dto';
import { StorageService, UploadFile } from '../storage/storage.service';

/** Photo files submitted with the multipart signup request. */
export interface SignupFiles {
  kitchenPhotos?: UploadFile[];
  selfPhoto?: UploadFile[];
}

@Injectable()
export class KitchensService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly firebase: FirebaseService,
    private readonly storage: StorageService,
  ) {}

  // ── Signup (public) ──────────────────────────────────────────────────
  async signup(idToken: string, dto: CreateKitchenDto, files: SignupFiles = {}) {
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

    // Required photos: at least one kitchen photo + a photo of the cook.
    const kitchenPhotos = files.kitchenPhotos ?? [];
    const selfPhoto = files.selfPhoto?.[0];
    if (kitchenPhotos.length === 0) {
      throw new BadRequestException('At least one kitchen photo is required.');
    }
    if (!selfPhoto) {
      throw new BadRequestException('A photo of yourself is required.');
    }

    const existing = await this.prisma.kitchen.findUnique({
      where: { firebaseUid },
    });
    if (existing) {
      throw new ConflictException(
        'A kitchen account already exists for this user.',
      );
    }

    // Upload to R2 before creating the row so we only persist real URLs.
    const prefix = `kitchens/${firebaseUid}`;
    const kitchenPhotoUrls = await this.storage.uploadImages(kitchenPhotos, prefix);
    const cookPhotoUrl = await this.storage.uploadImage(selfPhoto, prefix);

    return this.prisma.kitchen.create({
      data: {
        firebaseUid,
        phone,
        kitchenName: dto.kitchenName,
        cookName: dto.cookName,
        cookPhotoUrl,
        kitchenPhotoUrls,
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

  /** Multipart doc upload: pushes the file to R2, then records the URL. */
  async uploadDocumentFile(
    kitchenId: string,
    docType: DocType,
    file?: UploadFile,
  ) {
    if (!file) throw new BadRequestException('No document file provided.');
    const fileUrl = await this.storage.uploadImage(
      file,
      `documents/${kitchenId}`,
    );
    return this.prisma.kitchenDocument.create({
      data: { kitchenId, docType, fileUrl },
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

  // ── Kitchen orders ──────────────────────────────────────────────────
  listOrders(kitchenId: string, status?: string) {
    return this.prisma.order.findMany({
      where: {
        kitchenId,
        ...(status ? { status: status as OrderStatus } : {}),
      },
      orderBy: { placedAt: 'desc' },
      // Never expose handoverCode to the kitchen — it's the customer's
      // proof-of-pickup; the seller only enters what the customer tells them.
      omit: { handoverCode: true },
      include: {
        items: { include: { preferences: true } },
        payment: true,
      },
    });
  }

  // ── Customer-facing ──────────────────────────────────────────────────
  list(zoneId?: string) {
    const today = new Date();
    // UTC-midnight of the local calendar day so it matches stored dates.
    // Local midnight (new Date(y,m,d)) resolves to the previous UTC day in
    // positive-offset zones like IST — see OrdersService.serviceDate().
    const serviceDate = new Date(
      Date.UTC(today.getFullYear(), today.getMonth(), today.getDate()),
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
