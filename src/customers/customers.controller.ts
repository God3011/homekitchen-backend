import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { CustomersService } from './customers.service';
import { AddressesService } from './addresses.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';
import { CurrentUser, Public, RequestUser } from '../auth/decorators';
import { Roles } from '../auth/roles.guard';

@Controller('customers')
export class CustomersController {
  constructor(
    private readonly customers: CustomersService,
    private readonly addresses: AddressesService,
  ) {}

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

  // --- Saved locations (named lat/lng points that set the discovery centre) ---
  // All scoped to the caller's own customerId; another customer's addresses are
  // invisible (404).
  @Roles('customer')
  @Get('me/addresses')
  listAddresses(@CurrentUser() user: RequestUser) {
    return this.addresses.list(user.userId);
  }

  @Roles('customer')
  @Post('me/addresses')
  createAddress(
    @CurrentUser() user: RequestUser,
    @Body() dto: CreateAddressDto,
  ) {
    return this.addresses.create(user.userId, dto);
  }

  @Roles('customer')
  @Patch('me/addresses/:id')
  updateAddress(
    @CurrentUser() user: RequestUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateAddressDto,
  ) {
    return this.addresses.update(user.userId, id, dto);
  }

  @Roles('customer')
  @Patch('me/addresses/:id/default')
  setDefaultAddress(
    @CurrentUser() user: RequestUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.addresses.setDefault(user.userId, id);
  }

  @Roles('customer')
  @Delete('me/addresses/:id')
  deleteAddress(
    @CurrentUser() user: RequestUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.addresses.remove(user.userId, id);
  }
}
