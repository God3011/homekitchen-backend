import { IsArray, IsEnum } from 'class-validator';
import { PreferenceType } from '@prisma/client';

export class SetPreferencesDto {
  @IsArray()
  @IsEnum(PreferenceType, { each: true })
  preferences: PreferenceType[];
}
