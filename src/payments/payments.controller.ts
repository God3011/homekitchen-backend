import {
  Body, Controller, Headers, Param, Post, Req,
} from '@nestjs/common';
import { RawBodyRequest } from '@nestjs/common';
import { Request } from 'express';
import { PaymentsService } from './payments.service';
import { VerifyPaymentDto } from './dto/verify-payment.dto';
import { CurrentUser, Public, RequestUser } from '../auth/decorators';
import { Roles } from '../auth/roles.guard';

@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  /** Customer initiates payment — creates Razorpay order for checkout. */
  @Roles('customer')
  @Post(':orderId/razorpay-order')
  createRazorpayOrder(
    @CurrentUser() user: RequestUser,
    @Param('orderId') orderId: string,
  ) {
    return this.payments.createRazorpayOrder(orderId, user.userId);
  }

  /** Client-side verification after Razorpay checkout callback. */
  @Roles('customer')
  @Post('verify')
  verify(@Body() dto: VerifyPaymentDto) {
    return this.payments.verifyPayment(
      dto.razorpayOrderId,
      dto.razorpayPaymentId,
      dto.razorpaySignature,
    );
  }

  /** Razorpay webhook — public, verified by signature. */
  @Public()
  @Post('webhook')
  webhook(
    @Headers('x-razorpay-signature') signature: string,
    @Req() req: RawBodyRequest<Request>,
  ) {
    const rawBody = req.rawBody?.toString('utf-8') ?? '';
    return this.payments.handleWebhook(rawBody, signature);
  }
}
