import {
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
import { KitchensService, SignupFiles } from './kitchens.service';
import { UploadFile } from '../storage/storage.service';
import { CreateKitchenDto } from './dto/create-kitchen.dto';
import { UpdateKitchenDto } from './dto/update-kitchen.dto';
import {
  SetDailyStatusDto,
  SetKitchenHoursDto,
  UploadDocFileDto,
  UploadDocumentDto,
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

  @Roles('kitchen')
  @Post('me/documents')
  uploadDocument(
    @CurrentUser() user: RequestUser,
    @Body() dto: UploadDocumentDto,
  ) {
    return this.kitchens.uploadDocument(user.userId, dto);
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

  // --- Customer-facing (any authenticated role) ---
  @Get()
  list(
    @CurrentUser() user: RequestUser,
    @Query('zoneId') zoneId?: string,
    @Query('openNow') openNow?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
  ) {
    const latNum = lat != null ? Number(lat) : NaN;
    const lngNum = lng != null ? Number(lng) : NaN;
    return this.kitchens.list(user, {
      zoneId,
      openNow: openNow === 'true' || openNow === '1',
      lat: Number.isFinite(latNum) ? latNum : undefined,
      lng: Number.isFinite(lngNum) ? lngNum : undefined,
    });
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.kitchens.findOne(id);
  }
}
