import { IsInt, IsOptional, IsString, Length, Min, Max } from 'class-validator';

export class AcceptOrderDto {
  // Seller sets prep ETA when accepting (drives the customer's "Preparing" screen)
  @IsInt()
  @Min(1)
  @Max(180)
  etaMinutes: number;
}

export class ConfirmHandoverDto {
  // The 4-digit code the customer reads aloud at pickup
  @IsString()
  @Length(4, 4)
  code: string;
}

export class RejectOrderDto {
  @IsOptional()
  @IsString()
  reason?: string;
}

export class CancelOrderDto {
  @IsOptional()
  @IsString()
  reason?: string;
}
