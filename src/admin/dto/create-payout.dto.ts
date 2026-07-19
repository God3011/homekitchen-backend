import { IsDateString, IsInt, IsOptional, IsString, IsUUID, Min } from 'class-validator';

/** Records a manual UPI payout to a kitchen (admin logs the transfer). */
export class CreatePayoutDto {
  @IsUUID()
  kitchenId: string;

  @IsInt()
  @Min(1)
  amountPaise: number;

  @IsDateString()
  payoutDate: string;

  @IsOptional()
  @IsString()
  note?: string;
}
