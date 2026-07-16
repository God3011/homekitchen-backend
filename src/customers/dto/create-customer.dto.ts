import { IsBoolean, IsNumber, IsOptional, IsString } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateCustomerDto {
  @IsOptional()
  @IsString()
  name?: string;

  // Home location — used server-side to resolve the customer's home zone.
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lat?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lng?: number;

  @IsOptional()
  @IsBoolean()
  whatsappOptIn?: boolean;
}
