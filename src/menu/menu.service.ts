import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMenuItemDto } from './dto/create-menu-item.dto';
import { UpdateMenuItemDto } from './dto/update-menu-item.dto';
import {
  CreateCategoryDto,
  UpdateCategoryDto,
  SetAvailabilityDto,
  SetPreferencesDto,
} from './dto/menu-actions.dto';
import { StorageService, UploadFile } from '../storage/storage.service';

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

  // ── Categories ───────────────────────────────────────────────────────
  createCategory(kitchenId: string, dto: CreateCategoryDto) {
    return this.prisma.menuCategory.create({
      data: { kitchenId, name: dto.name, sortOrder: dto.sortOrder ?? 0 },
    });
  }

  listCategories(kitchenId: string) {
    return this.prisma.menuCategory.findMany({
      where: { kitchenId },
      orderBy: { sortOrder: 'asc' },
      include: { items: { where: { isActive: true } } },
    });
  }

  async updateCategory(
    kitchenId: string,
    categoryId: string,
    dto: UpdateCategoryDto,
  ) {
    await this.ownsCategory(kitchenId, categoryId);
    return this.prisma.menuCategory.update({
      where: { id: categoryId },
      data: dto,
    });
  }

  async deleteCategory(kitchenId: string, categoryId: string) {
    await this.ownsCategory(kitchenId, categoryId);
    // Orphan items rather than deleting them
    await this.prisma.menuItem.updateMany({
      where: { categoryId },
      data: { categoryId: null },
    });
    return this.prisma.menuCategory.delete({ where: { id: categoryId } });
  }

  private async ownsCategory(kitchenId: string, categoryId: string) {
    const cat = await this.prisma.menuCategory.findUnique({
      where: { id: categoryId },
    });
    if (!cat) throw new NotFoundException('Category not found.');
    if (cat.kitchenId !== kitchenId) {
      throw new ForbiddenException(
        'This category does not belong to your kitchen.',
      );
    }
  }

  // ── Menu items ───────────────────────────────────────────────────────
  async createItem(kitchenId: string, dto: CreateMenuItemDto) {
    if (dto.categoryId) {
      await this.ownsCategory(kitchenId, dto.categoryId);
    }

    const config = await this.prisma.platformConfig.findUniqueOrThrow({ where: { id: 1 } });
    if (dto.pricePaise > config.itemPriceCapPaise) {
      throw new BadRequestException(
        `Price exceeds the ₹${config.itemPriceCapPaise / 100} per-item cap.`,
      );
    }

    return this.prisma.menuItem.create({
      data: {
        kitchenId,
        categoryId: dto.categoryId,
        name: dto.name,
        pricePaise: dto.pricePaise,
        photoUrl: dto.photoUrl,
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
    if (dto.categoryId) {
      await this.ownsCategory(kitchenId, dto.categoryId);
    }

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
      include: { preferences: true, category: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ── Daily availability ───────────────────────────────────────────────
  async setAvailability(
    kitchenId: string,
    itemId: string,
    dto: SetAvailabilityDto,
  ) {
    await this.ownsItem(kitchenId, itemId);
    const serviceDate = new Date(dto.serviceDate);

    return this.prisma.menuDailyAvailability.upsert({
      where: {
        menuItemId_serviceDate: { menuItemId: itemId, serviceDate },
      },
      create: {
        menuItemId: itemId,
        serviceDate,
        platesTotal: dto.platesTotal,
        platesRemaining: dto.platesTotal,
        isAvailable: dto.isAvailable ?? true,
      },
      update: {
        platesTotal: dto.platesTotal,
        platesRemaining: dto.platesTotal,
        isAvailable: dto.isAvailable ?? true,
      },
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

  // ── Customer-facing ──────────────────────────────────────────────────
  async getKitchenMenu(kitchenId: string) {
    // UTC-midnight of the local calendar day, so today's availability rows match
    // how they're stored and how OrdersService.serviceDate() reads them. Using
    // local midnight (new Date(y,m,d)) resolves to the PREVIOUS UTC day in
    // positive-offset zones like IST — which showed yesterday's stock and made
    // orders fail with "insufficient plates".
    const now = new Date();
    const serviceDate = new Date(
      Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()),
    );

    const [categories, uncategorized] = await Promise.all([
      this.prisma.menuCategory.findMany({
        where: { kitchenId },
        orderBy: { sortOrder: 'asc' },
        include: {
          items: {
            where: { isActive: true },
            include: {
              preferences: true,
              availability: { where: { serviceDate } },
            },
          },
        },
      }),
      this.prisma.menuItem.findMany({
        where: { kitchenId, isActive: true, categoryId: null },
        include: {
          preferences: true,
          availability: { where: { serviceDate } },
        },
      }),
    ]);

    return { categories, uncategorized };
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
