import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ZonesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * The id of the active zone that *contains* the point (nearest, within its
   * radius), or null when the point falls outside every zone. Zones are passive
   * analytics labels — never created here. Discovery is radius-based, not
   * zone-gated, so a null label never blocks any flow.
   */
  async containingZoneId(lat: number, lng: number): Promise<string | null> {
    const zones = await this.prisma.zone.findMany({ where: { isActive: true } });
    let containingId: string | null = null;
    let best = Infinity;
    for (const z of zones) {
      const d = this.distanceM(lat, lng, z.centerLat, z.centerLng);
      if (d <= z.radiusM && d < best) {
        best = d;
        containingId = z.id;
      }
    }
    return containingId;
  }

  /** Great-circle distance between two lat/lng points, in metres. */
  distanceM(lat1: number, lng1: number, lat2: number, lng2: number): number {
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
