import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { ZonesService } from './zones.service';
import { Public } from '../auth/decorators';

@Controller('zones')
export class ZonesController {
  constructor(private readonly zones: ZonesService) {}

  /** List active service zones. */
  @Public()
  @Get()
  list() {
    return this.zones.list();
  }

  /** Resolve the nearest zone for a GPS point (used by the "use current
   *  location" flow during signup / profile edit). */
  @Public()
  @Get('resolve')
  resolve(@Query('lat') lat: string, @Query('lng') lng: string) {
    const la = Number.parseFloat(lat);
    const ln = Number.parseFloat(lng);
    if (Number.isNaN(la) || Number.isNaN(ln)) {
      throw new BadRequestException('lat and lng query params are required.');
    }
    return this.zones.resolveNearest(la, ln);
  }
}
