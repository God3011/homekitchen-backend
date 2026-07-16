import { Controller, Delete, Get, Param, Post } from '@nestjs/common';
import { FavoritesService } from './favorites.service';
import { CurrentUser, RequestUser } from '../auth/decorators';
import { Roles } from '../auth/roles.guard';

@Roles('customer')
@Controller('favorites')
export class FavoritesController {
  constructor(private readonly favorites: FavoritesService) {}

  @Get()
  list(@CurrentUser() user: RequestUser) {
    return this.favorites.list(user.userId);
  }

  @Post(':kitchenId')
  add(
    @CurrentUser() user: RequestUser,
    @Param('kitchenId') kitchenId: string,
  ) {
    return this.favorites.add(user.userId, kitchenId);
  }

  @Delete(':kitchenId')
  remove(
    @CurrentUser() user: RequestUser,
    @Param('kitchenId') kitchenId: string,
  ) {
    return this.favorites.remove(user.userId, kitchenId);
  }
}
