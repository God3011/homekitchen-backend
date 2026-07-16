import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ZonesService {
  constructor(private readonly prisma: PrismaService) {}

  list() {
    return this.prisma.zone.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' },
    });
  }

  /**
   * Preview of the zone a point will be assigned to (read-only): the zone that
   * contains it, or — if none does — the *proposed* new zone that would be
   * created on save (same name resolveOrCreate would use). Never persists.
   * Callers just show `name`; `id` is null for a not-yet-created zone.
   */
  async resolveNearest(lat: number, lng: number) {
    const zones = await this.prisma.zone.findMany({ where: { isActive: true } });
    let containing: (typeof zones)[number] | null = null;
    let best = Infinity;
    for (const z of zones) {
      const d = this.haversineM(lat, lng, z.centerLat, z.centerLng);
      if (d <= z.radiusM && d < best) {
        best = d;
        containing = z;
      }
    }
    if (containing) return { ...containing, withinRadius: true };

    return {
      id: null,
      name: this.newZoneName(lat, lng),
      centerLat: lat,
      centerLng: lng,
      radiusM: 5000,
      isActive: true,
      withinRadius: false,
    };
  }

  private newZoneName(lat: number, lng: number): string {
    return `Area ${lat.toFixed(3)}, ${lng.toFixed(3)}`;
  }

  /**
   * The active zone that *contains* the point (within its radius), or — if the
   * point falls outside every zone — a brand-new zone centred there. This lets
   * the service area grow organically as kitchens sign up in fresh locations.
   */
  async resolveOrCreate(lat: number, lng: number) {
    const zones = await this.prisma.zone.findMany({ where: { isActive: true } });
    let containing: (typeof zones)[number] | null = null;
    let best = Infinity;
    for (const z of zones) {
      const d = this.haversineM(lat, lng, z.centerLat, z.centerLng);
      if (d <= z.radiusM && d < best) {
        best = d;
        containing = z;
      }
    }
    if (containing) return containing;

    // New area — found a zone here (radiusM defaults to 5000m in the schema).
    return this.prisma.zone.create({
      data: {
        name: this.newZoneName(lat, lng),
        centerLat: lat,
        centerLng: lng,
      },
    });
  }

  /** Public great-circle distance between two lat/lng points, in metres. */
  distanceM(lat1: number, lng1: number, lat2: number, lng2: number): number {
    return this.haversineM(lat1, lng1, lat2, lng2);
  }

  /** Great-circle distance between two lat/lng points, in metres. */
  private haversineM(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
  ): number {
    const R = 6371000;
    const toRad = (d: number) => (d * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(a));
  }
}
