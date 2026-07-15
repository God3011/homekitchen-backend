import {
  IsArray, IsBoolean, IsDateString, IsEnum, IsInt, IsString,
  Matches, Max, Min, ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { DocType } from '@prisma/client';

class KitchenHoursEntry {
  @IsInt()
  @Min(0)
  @Max(6)
  dayOfWeek: number;

  @IsString()
  @Matches(/^\d{2}:\d{2}$/, { message: 'openTime must be HH:MM format' })
  openTime: string;

  @IsString()
  @Matches(/^\d{2}:\d{2}$/, { message: 'closeTime must be HH:MM format' })
  closeTime: string;
}

export class SetKitchenHoursDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => KitchenHoursEntry)
  hours: KitchenHoursEntry[];
}

export class UploadDocumentDto {
  @IsEnum(DocType)
  docType: DocType;

  @IsString()
  fileUrl: string;
}

// Multipart upload — the file comes via @UploadedFile, only docType in the body.
export class UploadDocFileDto {
  @IsEnum(DocType)
  docType: DocType;
}

export class SetDailyStatusDto {
  @IsDateString()
  serviceDate: string;

  @IsBoolean()
  isCooking: boolean;
}
