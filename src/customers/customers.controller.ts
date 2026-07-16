import { Body, Controller, Get, Headers, Patch, Post } from '@nestjs/common';
import { CustomersService } from './customers.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { CurrentUser, Public, RequestUser } from '../auth/decorators';
import { Roles } from '../auth/roles.guard';

@Controller('customers')
export class CustomersController {
  constructor(private readonly customers: CustomersService) {}

  // --- Signup (public — token verified manually in service) ---
  @Public()
  @Post('signup')
  signup(
    @Headers('authorization') authHeader: string,
    @Body() dto: CreateCustomerDto,
  ) {
    const token = authHeader?.replace('Bearer ', '');
    return this.customers.signup(token, dto);
  }

  // --- Customer self-service ---
  @Roles('customer')
  @Get('me')
  getProfile(@CurrentUser() user: RequestUser) {
    return this.customers.getProfile(user.userId);
  }

  @Roles('customer')
  @Patch('me')
  updateProfile(
    @CurrentUser() user: RequestUser,
    @Body() dto: UpdateCustomerDto,
  ) {
    return this.customers.updateProfile(user.userId, dto);
  }

  @Roles('customer')
  @Get('me/orders')
  listOrders(@CurrentUser() user: RequestUser) {
    return this.customers.listOrders(user.userId);
  }
}
