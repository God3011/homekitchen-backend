import {
  IsString, IsOptional, IsInt, IsBoolean, Min, IsArray, IsEnum,
} from 'class-validator';
import { PreferenceType } from '@prisma/client';

export class CreateMenuItemDto {
  @IsString()
  name: string;

  @IsInt()
  @Min(1)
  pricePaise: number;

  @IsOptional()
  @IsString()
  photoUrl?: string;

  // Veg vs non-veg. Defaults to veg when omitted.
  @IsOptional()
  @IsBoolean()
  isVeg?: boolean;

  @IsOptional()
  @IsBoolean()
  pickupAvailable?: boolean;

  @IsOptional()
  @IsBoolean()
  deliveryAvailable?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  deliveryFeePaise?: number;

  @IsOptional()
  @IsArray()
  @IsEnum(PreferenceType, { each: true })
  preferences?: PreferenceType[];
}
