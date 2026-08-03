import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { CurrentUser, RequestUser } from '../auth/decorators';
import { SearchService } from './search.service';

/**
 * GET /api/search?q=&lat=&lng=&radiusM=
 *
 * Customer-facing fuzzy search. Same auth pattern as discovery (any
 * authenticated user; no @Roles). lat/lng are required and the distance is
 * always computed server-side — a client-supplied distance is never trusted.
 */
@Controller('search')
export class SearchController {
  constructor(private readonly search: SearchService) {}

  @Get()
  find(
    @CurrentUser() user: RequestUser,
    @Query('q') q?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('radiusM') radiusM?: string,
  ) {
    const latNum = Number(lat);
    const lngNum = Number(lng);
    if (
      lat == null ||
      lng == null ||
      !Number.isFinite(latNum) ||
      !Number.isFinite(lngNum)
    ) {
      throw new BadRequestException('lat and lng query params are required.');
    }
    const r = radiusM != null ? Number(radiusM) : undefined;
    return this.search.search(user, {
      q: q ?? '',
      lat: latNum,
      lng: lngNum,
      radiusM: r != null && Number.isFinite(r) ? r : undefined,
    });
  }
}
