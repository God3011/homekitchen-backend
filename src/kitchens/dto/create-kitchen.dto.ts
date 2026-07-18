import { IsString, IsOptional, IsNumber, IsUUID } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateKitchenDto {
  @IsString()
  kitchenName: string;

  @IsOptional()
  @IsString()
  cookName?: string;

  @IsOptional()
  @IsString()
  story?: string;

  @IsOptional()
  @IsString()
  signatureDish?: string;

  @IsOptional()
  @IsString()
  addressLine?: string;

  // Required — a kitchen without coordinates is undiscoverable (radius-based).
  @Type(() => Number)
  @IsNumber()
  lat: number;

  @Type(() => Number)
  @IsNumber()
  lng: number;

  @IsOptional()
  @IsUUID()
  zoneId?: string;

  @IsOptional()
  @IsString()
  languagePref?: string;
}
