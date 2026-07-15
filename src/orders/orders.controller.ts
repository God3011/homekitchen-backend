import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { OrdersService } from './orders.service';
import { CreateOrderDto } from './dto/create-order.dto';
import {
  AcceptOrderDto,
  CancelOrderDto,
  ConfirmHandoverDto,
  RejectOrderDto,
} from './dto/order-actions.dto';

@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Post()
  create(@Body() dto: CreateOrderDto) {
    return this.orders.create(dto);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.orders.findOne(id);
  }

  // --- Seller actions ---
  @Patch(':id/accept')
  accept(@Param('id') id: string, @Body() dto: AcceptOrderDto) {
    return this.orders.accept(id, dto.etaMinutes);
  }

  @Patch(':id/reject')
  reject(@Param('id') id: string, @Body() dto: RejectOrderDto) {
    return this.orders.reject(id, dto.reason);
  }

  @Patch(':id/cancel')
  cancel(@Param('id') id: string, @Body() dto: CancelOrderDto) {
    return this.orders.cancel(id, dto.reason);
  }

  @Patch(':id/ready')
  markReady(@Param('id') id: string) {
    return this.orders.markReady(id);
  }

  @Patch(':id/handover')
  handover(@Param('id') id: string, @Body() dto: ConfirmHandoverDto) {
    return this.orders.confirmHandover(id, dto.code);
  }
}
