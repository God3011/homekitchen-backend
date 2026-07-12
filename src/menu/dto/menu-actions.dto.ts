import {
  IsString, IsOptional, IsInt, IsBoolean, IsDateString,
  IsArray, IsEnum, Min,
} from 'class-validator';
import { PreferenceType } from '@prisma/client';

export class CreateCategoryDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;
}

export class UpdateCategoryDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;
}

export class SetAvailabilityDto {
  @IsDateString()
  serviceDate: string;

  @IsInt()
  @Min(0)
  platesTotal: number;

  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;
}

export class SetPreferencesDto {
  @IsArray()
  @IsEnum(PreferenceType, { each: true })
  preferences: PreferenceType[];
}
