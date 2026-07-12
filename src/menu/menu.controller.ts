import {
  Body, Controller, Delete, Get, Param, Patch, Post, Put,
} from '@nestjs/common';
import { MenuService } from './menu.service';
import { CreateMenuItemDto } from './dto/create-menu-item.dto';
import { UpdateMenuItemDto } from './dto/update-menu-item.dto';
import {
  CreateCategoryDto,
  UpdateCategoryDto,
  SetAvailabilityDto,
  SetPreferencesDto,
} from './dto/menu-actions.dto';
import { CurrentUser, RequestUser } from '../auth/decorators';
import { Roles } from '../auth/roles.guard';

@Controller('menu')
export class MenuController {
  constructor(private readonly menu: MenuService) {}

  // --- Seller: categories ---
  @Roles('kitchen')
  @Post('categories')
  createCategory(
    @CurrentUser() user: RequestUser,
    @Body() dto: CreateCategoryDto,
  ) {
    return this.menu.createCategory(user.userId, dto);
  }

  @Roles('kitchen')
  @Get('categories')
  listCategories(@CurrentUser() user: RequestUser) {
    return this.menu.listCategories(user.userId);
  }

  @Roles('kitchen')
  @Patch('categories/:id')
  updateCategory(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() dto: UpdateCategoryDto,
  ) {
    return this.menu.updateCategory(user.userId, id, dto);
  }

  @Roles('kitchen')
  @Delete('categories/:id')
  deleteCategory(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
  ) {
    return this.menu.deleteCategory(user.userId, id);
  }

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
  @Put('items/:id/availability')
  setAvailability(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() dto: SetAvailabilityDto,
  ) {
    return this.menu.setAvailability(user.userId, id, dto);
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
