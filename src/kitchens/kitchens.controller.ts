import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UploadedFile,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import { FileFieldsInterceptor, FileInterceptor } from '@nestjs/platform-express';
import {
  EarningsPeriod,
  KitchensService,
  SignupFiles,
} from './kitchens.service';
import { UploadFile } from '../storage/storage.service';
import { CreateKitchenDto } from './dto/create-kitchen.dto';
import { UpdateKitchenDto } from './dto/update-kitchen.dto';
import {
  SetDailyStatusDto,
  SetKitchenHoursDto,
  UploadDocFileDto,
} from './dto/kitchen-actions.dto';
import { CurrentUser, Public, RequestUser } from '../auth/decorators';
import { Roles } from '../auth/roles.guard';

@Controller('kitchens')
export class KitchensController {
  constructor(private readonly kitchens: KitchensService) {}

  // --- Signup (public — token verified manually in service) ---
  // multipart/form-data: text fields + `kitchenPhotos[]` (>=1) + `selfPhoto` (1).
  @Public()
  @Post('signup')
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'kitchenPhotos', maxCount: 8 },
        { name: 'selfPhoto', maxCount: 1 },
      ],
      { limits: { fileSize: 5 * 1024 * 1024 } }, // 5 MB per image
    ),
  )
  signup(
    @Headers('authorization') authHeader: string,
    @Body() dto: CreateKitchenDto,
    @UploadedFiles() files: SignupFiles,
  ) {
    const token = authHeader?.replace('Bearer ', '');
    return this.kitchens.signup(token, dto, files);
  }

  // --- Seller self-service (defined before :id to avoid route conflict) ---
  @Roles('kitchen')
  @Get('me')
  getProfile(@CurrentUser() user: RequestUser) {
    return this.kitchens.getProfile(user.userId);
  }

  @Roles('kitchen')
  @Patch('me')
  updateProfile(
    @CurrentUser() user: RequestUser,
    @Body() dto: UpdateKitchenDto,
  ) {
    return this.kitchens.updateProfile(user.userId, dto);
  }

  // multipart: `file` (image of the doc) + `docType` field. Uploads to R2.
  @Roles('kitchen')
  @Post('me/documents/upload')
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }),
  )
  uploadDocumentFile(
    @CurrentUser() user: RequestUser,
    @Body() dto: UploadDocFileDto,
    @UploadedFile() file: UploadFile,
  ) {
    return this.kitchens.uploadDocumentFile(user.userId, dto.docType, file);
  }

  // multipart: `photo` (image file for profile or banner). Uploads to R2.
  @Roles('kitchen')
  @Post('me/upload-photo')
  @UseInterceptors(
    FileInterceptor('photo', { limits: { fileSize: 5 * 1024 * 1024 } }),
  )
  uploadPhoto(
    @CurrentUser() user: RequestUser,
    @UploadedFile() photo: UploadFile,
  ) {
    return this.kitchens.uploadPhoto(user.userId, photo);
  }

  @Roles('kitchen')
  @Get('me/orders')
  listOrders(
    @CurrentUser() user: RequestUser,
    @Query('status') status?: string,
  ) {
    return this.kitchens.listOrders(user.userId, status);
  }

  @Roles('kitchen')
  @Get('me/documents')
  getDocuments(@CurrentUser() user: RequestUser) {
    return this.kitchens.getDocuments(user.userId);
  }

  @Roles('kitchen')
  @Put('me/hours')
  setHours(
    @CurrentUser() user: RequestUser,
    @Body() dto: SetKitchenHoursDto,
  ) {
    return this.kitchens.setHours(user.userId, dto);
  }

  @Roles('kitchen')
  @Get('me/hours')
  getHours(@CurrentUser() user: RequestUser) {
    return this.kitchens.getHours(user.userId);
  }

  @Roles('kitchen')
  @Post('me/daily-status')
  setDailyStatus(
    @CurrentUser() user: RequestUser,
    @Body() dto: SetDailyStatusDto,
  ) {
    return this.kitchens.setDailyStatus(user.userId, dto);
  }

  @Roles('kitchen')
  @Get('me/daily-status')
  getDailyStatus(
    @CurrentUser() user: RequestUser,
    @Query('date') date: string,
  ) {
    return this.kitchens.getDailyStatus(user.userId, date);
  }

  // --- Earnings & payouts (read-only; scheduled payouts, no self-serve withdraw) ---
  @Roles('kitchen')
  @Get('me/earnings')
  getEarnings(
    @CurrentUser() user: RequestUser,
    @Query('period') period?: string,
  ) {
    const allowed: EarningsPeriod[] = ['today', 'week', 'month', 'all'];
    const p = (period ?? 'today') as EarningsPeriod;
    if (!allowed.includes(p)) {
      throw new BadRequestException(
        "period must be one of: today, week, month, all.",
      );
    }
    return this.kitchens.getEarnings(user.userId, p);
  }

  @Roles('kitchen')
  @Get('me/payouts')
  listPayouts(
    @CurrentUser() user: RequestUser,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    const pageNum = page != null ? Number(page) : 1;
    const sizeNum = pageSize != null ? Number(pageSize) : 20;
    return this.kitchens.listPayouts(
      user.userId,
      Number.isFinite(pageNum) ? pageNum : 1,
      Number.isFinite(sizeNum) ? sizeNum : 20,
    );
  }

  // --- Admin ---
  @Roles('admin')
  @Patch(':id/verify')
  verify(@Param('id') id: string) {
    return this.kitchens.verify(id);
  }

  @Roles('admin')
  @Patch(':id/suspend')
  suspend(@Param('id') id: string) {
    return this.kitchens.suspend(id);
  }

  // --- Customer-facing radius discovery (any authenticated role) ---
  // GET /api/kitchens?lat=&lng=&radiusM=  (lat/lng required)
  @Get()
  list(
    @CurrentUser() user: RequestUser,
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
    return this.kitchens.list(user, {
      lat: latNum,
      lng: lngNum,
      radiusM: r != null && Number.isFinite(r) ? r : undefined,
    });
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.kitchens.findOne(id);
  }
}
