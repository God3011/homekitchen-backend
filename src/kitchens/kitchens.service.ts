import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import {
  DocType,
  KitchenStatus,
  OrderStatus,
  PaymentStatus,
} from '@prisma/client';
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
import { ZonesService } from '../zones/zones.service';
import { RequestUser } from '../auth/decorators';
import {
  istDayOfWeek,
  istDayStartUtc,
  istServiceDate,
  istServiceDateDaysAgo,
  istTimeHHMM,
  parseServiceDate,
} from '../common/service-date';

export type EarningsPeriod = 'today' | 'week' | 'month' | 'all';

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
    private readonly zones: ZonesService,
  ) {}

  /** Zone LABEL from GPS when provided (nearest containing active zone, else
   *  null — never created), otherwise the explicit zoneId. Zones don't gate
   *  anything; this is just an analytics stamp. */
  private async resolveZoneId(dto: {
    lat?: number | null;
    lng?: number | null;
    zoneId?: string;
  }): Promise<string | undefined> {
    if (dto.lat != null && dto.lng != null) {
      return (await this.zones.containingZoneId(dto.lat, dto.lng)) ?? undefined;
    }
    return dto.zoneId;
  }

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

    // Location is required — discovery is radius-based, so a kitchen without
    // coordinates could never appear in any customer's results.
    if (dto.lat == null || dto.lng == null) {
      throw new BadRequestException('Kitchen location (lat/lng) is required.');
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
        zoneId: await this.resolveZoneId(dto),
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

  async updateProfile(kitchenId: string, dto: UpdateKitchenDto) {
    const zoneId = await this.resolveZoneId(dto);
    return this.prisma.kitchen.update({
      where: { id: kitchenId },
      data: { ...dto, zoneId },
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
    const serviceDate = parseServiceDate(dto.serviceDate);

    return this.prisma.kitchenDailyStatus.upsert({
      where: {
        kitchenId_serviceDate: { kitchenId, serviceDate },
      },
      create: { kitchenId, serviceDate, isCooking: dto.isCooking },
      update: { isCooking: dto.isCooking },
    });
  }

  getDailyStatus(kitchenId: string, date: string) {
    const serviceDate = parseServiceDate(date);
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
        // Sellers only ever see PAID orders. Unpaid/failed orders stay hidden
        // (and get auto-cancelled by the TTL sweep) — mirrors the fact that the
        // "new order" push also fires only on payment capture.
        payment: { is: { status: PaymentStatus.captured } },
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

  // ── Earnings & payouts ───────────────────────────────────────────────
  //
  // "Earned" means an order reached status `completed` (handover confirmed) —
  // NOT merely accepted or marked ready. Gross is the sum of foodTotalPaise
  // (the platform's ₹5 fee is Homely's, not the kitchen's). The seller's daily
  // ₹50 fee is deducted per cooking day that was actually charged. All money in
  // integer paise. v1 payouts are SCHEDULED (manual UPI) — there is no
  // self-serve withdraw; pending balance is lifetime net minus payouts recorded.

  /** Inclusive lookback window (days) for a period; null = all-time. */
  private periodDaysAgo(period: EarningsPeriod): number | null {
    switch (period) {
      case 'today':
        return 0;
      case 'week':
        return 6; // today + previous 6 = 7 days
      case 'month':
        return 29; // today + previous 29 = 30 days
      case 'all':
        return null;
    }
  }

  /** Net earnings (completed gross − charged daily fees) across ALL time. */
  private async lifetimeNetPaise(kitchenId: string): Promise<number> {
    const config = await this.prisma.platformConfig.findUniqueOrThrow({
      where: { id: 1 },
    });
    const [grossAgg, feeDays] = await Promise.all([
      this.prisma.order.aggregate({
        where: { kitchenId, status: OrderStatus.completed },
        _sum: { foodTotalPaise: true },
      }),
      this.prisma.kitchenDailyStatus.count({
        where: { kitchenId, feeCharged: true },
      }),
    ]);
    const gross = grossAgg._sum.foodTotalPaise ?? 0;
    return gross - feeDays * config.sellerDailyFeePaise;
  }

  /** Lifetime net minus everything already paid out. Used by admin payout
   *  validation and surfaced on the earnings screen. */
  async pendingBalancePaise(kitchenId: string): Promise<number> {
    const [net, paidAgg] = await Promise.all([
      this.lifetimeNetPaise(kitchenId),
      this.prisma.payout.aggregate({
        where: { kitchenId },
        _sum: { amountPaise: true },
      }),
    ]);
    return net - (paidAgg._sum.amountPaise ?? 0);
  }

  async getEarnings(kitchenId: string, period: EarningsPeriod) {
    const config = await this.prisma.platformConfig.findUniqueOrThrow({
      where: { id: 1 },
    });
    const daysAgo = this.periodDaysAgo(period);

    // Completed-order gross + count within the period (IST day boundaries).
    const orderWhere =
      daysAgo === null
        ? { kitchenId, status: OrderStatus.completed }
        : {
            kitchenId,
            status: OrderStatus.completed,
            completedAt: { gte: istDayStartUtc(daysAgo) },
          };
    const grossAgg = await this.prisma.order.aggregate({
      where: orderWhere,
      _sum: { foodTotalPaise: true },
      _count: true,
    });
    const grossPaise = grossAgg._sum.foodTotalPaise ?? 0;
    const orderCount = grossAgg._count;

    // Daily ₹50 fees actually charged within the period.
    const feeWhere =
      daysAgo === null
        ? { kitchenId, feeCharged: true }
        : {
            kitchenId,
            feeCharged: true,
            serviceDate: { gte: istServiceDateDaysAgo(daysAgo) },
          };
    const feeDays = await this.prisma.kitchenDailyStatus.count({
      where: feeWhere,
    });
    const feesPaise = feeDays * config.sellerDailyFeePaise;

    return {
      period,
      grossPaise,
      orderCount,
      feeDays,
      feesPaise,
      netEarningsPaise: grossPaise - feesPaise,
      // Pending balance is lifetime, independent of the selected period.
      pendingBalancePaise: await this.pendingBalancePaise(kitchenId),
    };
  }

  async listPayouts(kitchenId: string, page = 1, pageSize = 20) {
    const take = Math.min(Math.max(pageSize, 1), 100);
    const skip = (Math.max(page, 1) - 1) * take;
    const [items, total] = await Promise.all([
      this.prisma.payout.findMany({
        where: { kitchenId },
        orderBy: [{ payoutDate: 'desc' }, { createdAt: 'desc' }],
        skip,
        take,
      }),
      this.prisma.payout.count({ where: { kitchenId } }),
    ]);
    return { items, total, page: Math.max(page, 1), pageSize: take };
  }

  // ── Customer-facing radius discovery ─────────────────────────────────
  /**
   * Radius-based discovery (NOT zone-gated). Returns verified kitchens within
   * `discoveryRadiusM` (or the `radiusM` override) of the caller's GPS, computed
   * server-side by haversine, each flagged `serviceable` (verified + cooking
   * today + within hours + has plates) or dormant with a `dormantReason`. The
   * top-level `state` lets the app render a normal list, a dimmed list, or a
   * "not serving your area yet" screen:
   *   serviceable   — ≥1 serviceable kitchen
   *   dormant_only  — kitchens in radius, none serviceable
   *   none_in_radius— no kitchens in radius
   */
  async list(
    _user: RequestUser,
    opts: { lat: number; lng: number; radiusM?: number },
  ) {
    // Today's IST service date / weekday / wall-clock — the menu day rolls over
    // at IST midnight, consistent with orders and the daily-menu screen.
    const serviceDate = istServiceDate();
    const dayOfWeek = istDayOfWeek(); // 0=Sun .. 6=Sat
    const currentTime = istTimeHHMM();

    const config = await this.prisma.platformConfig.findUniqueOrThrow({
      where: { id: 1 },
    });
    const radius = Math.min(
      Math.max(opts.radiusM ?? config.discoveryRadiusM, 1),
      20000,
    );

    // Every verified kitchen that has coordinates (needed for distance).
    const kitchens = await this.prisma.kitchen.findMany({
      where: {
        status: KitchenStatus.verified,
        lat: { not: null },
        lng: { not: null },
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
        hours: {
          where: { dayOfWeek },
          select: { openTime: true, closeTime: true },
        },
        dailyStatus: {
          where: { serviceDate },
          select: { isCooking: true },
        },
      },
    });

    // Distance filter (server-computed — never trust client distance).
    const inRadius = kitchens
      .map((k) => ({
        k,
        distanceM: Math.round(
          this.zones.distanceM(opts.lat, opts.lng, k.lat!, k.lng!),
        ),
      }))
      .filter((x) => x.distanceM <= radius);

    // One batch query: which in-radius kitchens have ≥1 orderable plate today.
    const inRadiusIds = inRadius.map((x) => x.k.id);
    const withPlates = inRadiusIds.length
      ? await this.prisma.menuDailyAvailability.findMany({
          where: {
            serviceDate,
            isAvailable: true,
            platesRemaining: { gt: 0 },
            menuItem: { kitchenId: { in: inRadiusIds }, isActive: true },
          },
          select: { menuItem: { select: { kitchenId: true } } },
        })
      : [];
    const platesSet = new Set(withPlates.map((a) => a.menuItem.kitchenId));

    const cards = inRadius.map(({ k, distanceM }) => {
      const { ratings, hours, dailyStatus, ...card } = k;
      const ratingCount = ratings.length;
      const ratingAvg = ratingCount
        ? ratings.reduce((sum, r) => sum + r.stars, 0) / ratingCount
        : null;
      const cooking = dailyStatus[0]?.isCooking === true;
      const today = hours[0];
      const withinHours =
        !!today &&
        currentTime >= today.openTime &&
        currentTime < today.closeTime;
      const hasPlates = platesSet.has(k.id);
      const serviceable = cooking && withinHours && hasPlates;
      const dormantReason = serviceable
        ? undefined
        : !cooking
          ? 'not_cooking_today'
          : !withinHours
            ? 'outside_hours'
            : 'sold_out';
      return {
        ...card,
        ratingAvg,
        ratingCount,
        distanceM,
        serviceable,
        dormantReason,
      };
    });

    // Serviceable first, then nearest.
    cards.sort((a, b) => {
      if (a.serviceable !== b.serviceable) return a.serviceable ? -1 : 1;
      return a.distanceM - b.distanceM;
    });

    const state = cards.some((k) => k.serviceable)
      ? 'serviceable'
      : cards.length > 0
        ? 'dormant_only'
        : 'none_in_radius';

    return { state, kitchens: cards };
  }

  async findOne(kitchenId: string) {
    const kitchen = await this.prisma.kitchen.findUniqueOrThrow({
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

    // Rating summary is derived across ALL ratings, not just the 20 shown.
    const agg = await this.prisma.rating.aggregate({
      where: { kitchenId },
      _avg: { stars: true },
      _count: true,
    });

    return {
      ...kitchen,
      ratingAvg: agg._avg.stars,
      ratingCount: agg._count,
    };
  }
}
