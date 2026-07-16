import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { OrdersService } from './orders.service';
import { CreateOrderDto } from './dto/create-order.dto';
import {
  AcceptOrderDto,
  CancelOrderDto,
  ConfirmHandoverDto,
  RateOrderDto,
  RejectOrderDto,
} from './dto/order-actions.dto';
import { CurrentUser, RequestUser } from '../auth/decorators';
import { Roles } from '../auth/roles.guard';

@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Roles('customer')
  @Post()
  create(@CurrentUser() user: RequestUser, @Body() dto: CreateOrderDto) {
    return this.orders.create(user.userId, dto);
  }

  // Owning customer or the order's kitchen only (enforced in the service).
  @Get(':id')
  findOne(@CurrentUser() user: RequestUser, @Param('id') id: string) {
    return this.orders.findOne(id, user);
  }

  // --- Seller actions (kitchen owner only) ---
  @Roles('kitchen')
  @Patch(':id/accept')
  accept(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() dto: AcceptOrderDto,
  ) {
    return this.orders.accept(id, user.userId, dto.etaMinutes);
  }

  @Roles('kitchen')
  @Patch(':id/reject')
  reject(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() dto: RejectOrderDto,
  ) {
    return this.orders.reject(id, user.userId, dto.reason);
  }

  @Roles('kitchen')
  @Patch(':id/ready')
  markReady(@CurrentUser() user: RequestUser, @Param('id') id: string) {
    return this.orders.markReady(id, user.userId);
  }

  @Roles('kitchen')
  @Patch(':id/handover')
  handover(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() dto: ConfirmHandoverDto,
  ) {
    return this.orders.confirmHandover(id, user.userId, dto.code);
  }

  // --- Customer actions (order owner only) ---
  @Roles('customer')
  @Patch(':id/cancel')
  cancel(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() dto: CancelOrderDto,
  ) {
    return this.orders.cancel(id, user.userId, dto.reason);
  }

  @Roles('customer')
  @Post(':id/rating')
  rate(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() dto: RateOrderDto,
  ) {
    return this.orders.rate(id, user.userId, dto.stars, dto.comment);
  }
}
