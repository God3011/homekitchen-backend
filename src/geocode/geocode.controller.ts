import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { GeocodeService } from './geocode.service';
import { Public } from '../auth/decorators';

@Controller('geocode')
export class GeocodeController {
  constructor(private readonly geocode: GeocodeService) {}

  /** Coordinates → address (used by "use my location" + map pin). */
  @Public()
  @Get('reverse')
  reverse(@Query('lat') lat: string, @Query('lng') lng: string) {
    const la = Number.parseFloat(lat);
    const ln = Number.parseFloat(lng);
    if (Number.isNaN(la) || Number.isNaN(ln)) {
      throw new BadRequestException('lat and lng query params are required.');
    }
    return this.geocode.reverse(la, ln);
  }

  /** Free-text → address suggestions (autocomplete). */
  @Public()
  @Get('search')
  search(@Query('q') q?: string) {
    const query = (q ?? '').trim();
    if (query.length < 3) return [];
    return this.geocode.search(query);
  }
}
