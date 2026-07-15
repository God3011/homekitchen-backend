import { BadRequestException, Injectable, Logger } from '@nestjs/common';

const NOMINATIM = 'https://nominatim.openstreetmap.org';
// Nominatim's usage policy requires an identifying User-Agent.
const USER_AGENT = 'HomelyKitchen/1.0 (home-food marketplace)';

export interface GeocodeSuggestion {
  label: string;
  lat: number;
  lng: number;
}

/**
 * Thin proxy over OpenStreetMap Nominatim for reverse-geocoding and address
 * search. Centralised here so the provider is swappable (Google/Mapbox later)
 * and the required User-Agent / rate-limits live server-side.
 */
@Injectable()
export class GeocodeService {
  private readonly logger = new Logger(GeocodeService.name);

  /** Coordinates → a human-readable address. */
  async reverse(lat: number, lng: number): Promise<{ address: string; lat: number; lng: number }> {
    const data = await this.get(
      `${NOMINATIM}/reverse?format=jsonv2&lat=${lat}&lon=${lng}`,
    );
    return { address: (data?.display_name as string) ?? '', lat, lng };
  }

  /** Free-text query → up to 6 address suggestions with coordinates. */
  async search(q: string): Promise<GeocodeSuggestion[]> {
    const data = await this.get(
      `${NOMINATIM}/search?format=jsonv2&limit=6&q=${encodeURIComponent(q)}`,
    );
    if (!Array.isArray(data)) return [];
    return data.map((r) => ({
      label: r.display_name as string,
      lat: Number.parseFloat(r.lat),
      lng: Number.parseFloat(r.lon),
    }));
  }

  private async get(url: string): Promise<any> {
    const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT } });
    if (!res.ok) {
      this.logger.warn(`Nominatim ${res.status}: ${url}`);
      throw new BadRequestException('Address lookup failed. Try again.');
    }
    return res.json();
  }
}
