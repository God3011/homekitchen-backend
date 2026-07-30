import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMenuItemDto } from './dto/create-menu-item.dto';
import { UpdateMenuItemDto } from './dto/update-menu-item.dto';
import { SetPreferencesDto } from './dto/menu-actions.dto';
import { SaveDailyMenuDto } from './dto/daily-menu.dto';
import { StorageService, UploadFile } from '../storage/storage.service';
import {
  formatServiceDate,
  istServiceDate,
  parseServiceDate,
} from '../common/service-date';

@Injectable()
export class MenuService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  /** Upload/replace a dish photo (multipart) → stores the R2 URL on the item. */
  async uploadItemPhoto(kitchenId: string, itemId: string, file?: UploadFile) {
    await this.ownsItem(kitchenId, itemId);
    if (!file) throw new BadRequestException('No photo provided.');
    const url = await this.storage.uploadImage(file, `menu/${kitchenId}`);
    return this.prisma.menuItem.update({
      where: { id: itemId },
      data: { photoUrl: url },
    });
  }

  // ── Menu items ───────────────────────────────────────────────────────
  async createItem(kitchenId: string, dto: CreateMenuItemDto) {
    const config = await this.prisma.platformConfig.findUniqueOrThrow({ where: { id: 1 } });
    if (dto.pricePaise > config.itemPriceCapPaise) {
      throw new BadRequestException(
        `Price exceeds the ₹${config.itemPriceCapPaise / 100} per-item cap.`,
      );
    }

    return this.prisma.menuItem.create({
      data: {
        kitchenId,
        name: dto.name,
        pricePaise: dto.pricePaise,
        photoUrl: dto.photoUrl,
        isVeg: dto.isVeg ?? true,
        pickupAvailable: dto.pickupAvailable,
        deliveryAvailable: dto.deliveryAvailable,
        deliveryFeePaise: dto.deliveryFeePaise,
        preferences: dto.preferences?.length
          ? { create: dto.preferences.map((p) => ({ preference: p })) }
          : undefined,
      },
      include: { preferences: true },
    });
  }

  async updateItem(
    kitchenId: string,
    itemId: string,
    dto: UpdateMenuItemDto,
  ) {
    await this.ownsItem(kitchenId, itemId);

    if (dto.pricePaise !== undefined) {
      const config = await this.prisma.platformConfig.findUniqueOrThrow({ where: { id: 1 } });
      if (dto.pricePaise > config.itemPriceCapPaise) {
        throw new BadRequestException(
          `Price exceeds the ₹${config.itemPriceCapPaise / 100} per-item cap.`,
        );
      }
    }

    return this.prisma.menuItem.update({
      where: { id: itemId },
      data: dto,
      include: { preferences: true },
    });
  }

  async deactivateItem(kitchenId: string, itemId: string) {
    await this.ownsItem(kitchenId, itemId);
    return this.prisma.menuItem.update({
      where: { id: itemId },
      data: { isActive: false },
    });
  }

  listItems(kitchenId: string) {
    return this.prisma.menuItem.findMany({
      where: { kitchenId },
      include: { preferences: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ── Preferences ──────────────────────────────────────────────────────
  async setPreferences(
    kitchenId: string,
    itemId: string,
    dto: SetPreferencesDto,
  ) {
    await this.ownsItem(kitchenId, itemId);

    return this.prisma.$transaction(async (tx) => {
      await tx.menuItemPreference.deleteMany({
        where: { menuItemId: itemId },
      });
      if (dto.preferences.length) {
        await tx.menuItemPreference.createMany({
          data: dto.preferences.map((p) => ({
            menuItemId: itemId,
            preference: p,
          })),
        });
      }
      return tx.menuItemPreference.findMany({
        where: { menuItemId: itemId },
      });
    });
  }

  // ── Daily menu ("today's menu" management screen) ─────────────────────
  //
  // The daily menu is NOT a separate catalog: it is every ACTIVE MenuItem
  // annotated with THIS date's MenuDailyAvailability. A fresh day simply has no
  // availability rows, so every dish reads back `onMenu: false` — the "menu
  // clears daily" behaviour is emergent from the (menuItemId, serviceDate) key,
  // NOT a wipe job. Writing rows here is literally how a kitchen goes live for
  // the day: discovery treats a kitchen as serviceable only when it has ≥1 row
  // with platesRemaining > 0 AND isAvailable (see KitchensService.list).

  /**
   * The catalog annotated with a given date's stock. `date` defaults to today
   * (IST). Past dates are returned `readOnly: true` (history is view-only);
   * future dates are rejected (v1 is same-day only).
   */
  async getDailyMenu(kitchenId: string, date?: string) {
    const today = istServiceDate();
    let serviceDate = today;
    if (date) {
      try {
        serviceDate = parseServiceDate(date);
      } catch (e) {
        throw new BadRequestException((e as Error).message);
      }
      if (serviceDate.getTime() > today.getTime()) {
        throw new BadRequestException('Cannot view a future service date.');
      }
    }
    const readOnly = serviceDate.getTime() !== today.getTime();

    const items = await this.prisma.menuItem.findMany({
      where: { kitchenId, isActive: true },
      orderBy: { createdAt: 'asc' },
      include: { availability: { where: { serviceDate } } },
    });

    const dishes = items.map((it) => {
      const a = it.availability[0];
      return {
        menuItemId: it.id,
        name: it.name,
        pricePaise: it.pricePaise,
        photoUrl: it.photoUrl,
        isVeg: it.isVeg,
        onMenu: !!a,
        platesTotal: a?.platesTotal ?? 0,
        platesRemaining: a?.platesRemaining ?? 0,
        isAvailable: a?.isAvailable ?? false,
      };
    });

    return { serviceDate: formatServiceDate(serviceDate), readOnly, dishes };
  }

  /**
   * Batch-write TODAY's menu in one transaction: upsert stock rows and delete
   * removed ones. Writes to any date other than today (IST) are rejected — past
   * dates are immutable history and v1 has no future scheduling.
   *
   * Stock math preserves mid-day sales:
   *  - New add  → platesRemaining = platesTotal (all fresh).
   *  - Edit     → sold = oldTotal - oldRemaining;
   *               platesRemaining = max(0, newTotal - sold).
   * Sold plates are never resurrected and remaining never goes negative.
   */
  async saveDailyMenu(kitchenId: string, dto: SaveDailyMenuDto) {
    const today = istServiceDate();

    if (dto.date) {
      let requested: Date;
      try {
        requested = parseServiceDate(dto.date);
      } catch (e) {
        throw new BadRequestException((e as Error).message);
      }
      if (requested.getTime() !== today.getTime()) {
        throw new BadRequestException(
          'The daily menu can only be edited for today.',
        );
      }
    }

    const upserts = dto.upserts ?? [];
    const removals = dto.removals ?? [];

    // Every referenced dish must be one of this kitchen's ACTIVE catalog items.
    const ids = [
      ...new Set([...upserts.map((u) => u.menuItemId), ...removals]),
    ];
    if (ids.length) {
      const owned = await this.prisma.menuItem.findMany({
        where: { id: { in: ids }, kitchenId, isActive: true },
        select: { id: true },
      });
      if (owned.length !== ids.length) {
        throw new ForbiddenException(
          'One or more dishes are not part of your active menu.',
        );
      }
    }

    await this.prisma.$transaction(async (tx) => {
      for (const u of upserts) {
        const key = {
          menuItemId_serviceDate: {
            menuItemId: u.menuItemId,
            serviceDate: today,
          },
        };
        const existing = await tx.menuDailyAvailability.findUnique({
          where: key,
        });
        const isAvailable = u.isAvailable ?? true;
        if (!existing) {
          await tx.menuDailyAvailability.create({
            data: {
              menuItemId: u.menuItemId,
              serviceDate: today,
              platesTotal: u.platesTotal,
              platesRemaining: u.platesTotal,
              isAvailable,
            },
          });
        } else {
          // Preserve plates already sold today; clamp remaining to [0, …].
          const sold = existing.platesTotal - existing.platesRemaining;
          const newRemaining = Math.max(0, u.platesTotal - sold);
          await tx.menuDailyAvailability.update({
            where: key,
            data: {
              platesTotal: u.platesTotal,
              platesRemaining: newRemaining,
              isAvailable,
            },
          });
        }
      }
      if (removals.length) {
        await tx.menuDailyAvailability.deleteMany({
          where: { menuItemId: { in: removals }, serviceDate: today },
        });
      }
    });

    return this.getDailyMenu(kitchenId);
  }

  // ── Customer-facing ──────────────────────────────────────────────────
  async getKitchenMenu(kitchenId: string) {
    // Today's IST service date — matches how availability rows are stored and
    // how OrdersService reads them, so the customer sees today's stock.
    const serviceDate = istServiceDate();

    const uncategorized = await this.prisma.menuItem.findMany({
      where: { kitchenId, isActive: true },
      include: {
        preferences: true,
        availability: { where: { serviceDate } },
      },
    });

    return { uncategorized };
  }

  private async ownsItem(kitchenId: string, itemId: string) {
    const item = await this.prisma.menuItem.findUnique({
      where: { id: itemId },
    });
    if (!item) throw new NotFoundException('Menu item not found.');
    if (item.kitchenId !== kitchenId) {
      throw new ForbiddenException(
        'This item does not belong to your kitchen.',
      );
    }
  }
}
