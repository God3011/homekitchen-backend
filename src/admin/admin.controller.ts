import { Body, Controller, Post } from '@nestjs/common';
import { AdminService } from './admin.service';
import { CreatePayoutDto } from './dto/create-payout.dto';
import { Roles } from '../auth/roles.guard';

@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  // Log a manual UPI payout to a kitchen (v1 has no automated disbursement).
  @Roles('admin')
  @Post('payouts')
  createPayout(@Body() dto: CreatePayoutDto) {
    return this.admin.createPayout(dto);
  }
}
