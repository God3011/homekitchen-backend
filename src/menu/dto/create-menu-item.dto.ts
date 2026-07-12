import {
  IsString, IsOptional, IsInt, IsBoolean, IsUUID, Min, IsArray, IsEnum,
} from 'class-validator';
import { PreferenceType } from '@prisma/client';

export class CreateMenuItemDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsInt()
  @Min(1)
  pricePaise: number;

  @IsOptional()
  @IsString()
  photoUrl?: string;

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
