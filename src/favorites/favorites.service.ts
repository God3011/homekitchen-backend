import { Injectable, NotFoundException } from '@nestjs/common';
import { KitchenStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FavoritesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Idempotent: favoriting an already-favorited kitchen is a no-op. */
  async add(customerId: string, kitchenId: string) {
    const kitchen = await this.prisma.kitchen.findUnique({
      where: { id: kitchenId },
      select: { id: true },
    });
    if (!kitchen) throw new NotFoundException('Kitchen not found.');

    return this.prisma.favorite.upsert({
      where: { customerId_kitchenId: { customerId, kitchenId } },
      create: { customerId, kitchenId },
      update: {},
    });
  }

  async remove(customerId: string, kitchenId: string) {
    await this.prisma.favorite.deleteMany({
      where: { customerId, kitchenId },
    });
    return { removed: true };
  }

  /** The customer's favorite kitchens (verified ones only, with rating summary). */
  async list(customerId: string) {
    const favorites = await this.prisma.favorite.findMany({
      where: { customerId, kitchen: { status: KitchenStatus.verified } },
      orderBy: { createdAt: 'desc' },
      include: {
        kitchen: {
          select: {
            id: true,
            kitchenName: true,
            cookName: true,
            cookPhotoUrl: true,
            signatureDish: true,
            addressLine: true,
            lat: true,
            lng: true,
            ratings: { select: { stars: true } },
          },
        },
      },
    });

    return favorites.map((f) => {
      const { ratings, ...kitchen } = f.kitchen;
      const ratingCount = ratings.length;
      const ratingAvg = ratingCount
        ? ratings.reduce((sum, r) => sum + r.stars, 0) / ratingCount
        : null;
      return {
        kitchenId: f.kitchenId,
        favoritedAt: f.createdAt,
        kitchen: { ...kitchen, ratingAvg, ratingCount },
      };
    });
  }
}
