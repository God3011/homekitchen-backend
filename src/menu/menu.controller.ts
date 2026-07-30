import {
  Body, Controller, Delete, Get, Param, Patch, Post, Put, Query,
  UploadedFile, UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { MenuService } from './menu.service';
import { UploadFile } from '../storage/storage.service';
import { CreateMenuItemDto } from './dto/create-menu-item.dto';
import { UpdateMenuItemDto } from './dto/update-menu-item.dto';
import { SetPreferencesDto } from './dto/menu-actions.dto';
import { SaveDailyMenuDto } from './dto/daily-menu.dto';
import { CurrentUser, RequestUser } from '../auth/decorators';
import { Roles } from '../auth/roles.guard';

@Controller('menu')
export class MenuController {
  constructor(private readonly menu: MenuService) {}

  // --- Seller: items ---
  @Roles('kitchen')
  @Post('items')
  createItem(
    @CurrentUser() user: RequestUser,
    @Body() dto: CreateMenuItemDto,
  ) {
    return this.menu.createItem(user.userId, dto);
  }

  @Roles('kitchen')
  @Get('items')
  listItems(@CurrentUser() user: RequestUser) {
    return this.menu.listItems(user.userId);
  }

  @Roles('kitchen')
  @Patch('items/:id')
  updateItem(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() dto: UpdateMenuItemDto,
  ) {
    return this.menu.updateItem(user.userId, id, dto);
  }

  @Roles('kitchen')
  @Delete('items/:id')
  deactivateItem(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
  ) {
    return this.menu.deactivateItem(user.userId, id);
  }

  @Roles('kitchen')
  @Post('items/:id/photo')
  @UseInterceptors(
    FileInterceptor('photo', { limits: { fileSize: 5 * 1024 * 1024 } }),
  )
  uploadItemPhoto(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @UploadedFile() photo: UploadFile,
  ) {
    return this.menu.uploadItemPhoto(user.userId, id, photo);
  }

  // --- Seller: daily menu (today's stock) ---
  @Roles('kitchen')
  @Get('daily')
  getDailyMenu(
    @CurrentUser() user: RequestUser,
    @Query('date') date?: string,
  ) {
    return this.menu.getDailyMenu(user.userId, date);
  }

  @Roles('kitchen')
  @Put('daily')
  saveDailyMenu(
    @CurrentUser() user: RequestUser,
    @Body() dto: SaveDailyMenuDto,
  ) {
    return this.menu.saveDailyMenu(user.userId, dto);
  }

  @Roles('kitchen')
  @Put('items/:id/preferences')
  setPreferences(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() dto: SetPreferencesDto,
  ) {
    return this.menu.setPreferences(user.userId, id, dto);
  }

  // --- Customer-facing ---
  @Get('kitchens/:kitchenId')
  getKitchenMenu(@Param('kitchenId') kitchenId: string) {
    return this.menu.getKitchenMenu(kitchenId);
  }
}
