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
} from '@nestjs/common';
import { KitchensService } from './kitchens.service';
import { CreateKitchenDto } from './dto/create-kitchen.dto';
import { UpdateKitchenDto } from './dto/update-kitchen.dto';
import {
  SetDailyStatusDto,
  SetKitchenHoursDto,
  UploadDocumentDto,
} from './dto/kitchen-actions.dto';
import { CurrentUser, Public, RequestUser } from '../auth/decorators';
import { Roles } from '../auth/roles.guard';

@Controller('kitchens')
export class KitchensController {
  constructor(private readonly kitchens: KitchensService) {}

  // --- Signup (public — token verified manually in service) ---
  @Public()
  @Post('signup')
  signup(
    @Headers('authorization') authHeader: string,
    @Body() dto: CreateKitchenDto,
  ) {
    const token = authHeader?.replace('Bearer ', '');
    return this.kitchens.signup(token, dto);
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
  list(@Query('zoneId') zoneId?: string) {
    return this.kitchens.list(zoneId);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.kitchens.findOne(id);
  }
}
