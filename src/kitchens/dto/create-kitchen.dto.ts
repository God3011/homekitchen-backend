import { IsString, IsOptional, IsNumber, IsUUID } from 'class-validator';

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

  @IsOptional()
  @IsNumber()
  lat?: number;

  @IsOptional()
  @IsNumber()
  lng?: number;

  @IsOptional()
  @IsUUID()
  zoneId?: string;

  @IsOptional()
  @IsString()
  languagePref?: string;
}
