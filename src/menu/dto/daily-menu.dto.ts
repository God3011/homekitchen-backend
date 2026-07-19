import { Type } from 'class-transformer';
import {
  IsArray, IsBoolean, IsInt, IsOptional, IsString, IsUUID, Max, Min,
  ValidateNested,
} from 'class-validator';

/** One dish put onto (or restocked on) today's menu. */
export class DailyUpsertDto {
  @IsUUID()
  menuItemId: string;

  @IsInt()
  @Min(0)
  @Max(9999)
  platesTotal: number;

  // false = "stop selling" even if plates remain (sold-out toggle).
  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;
}

/** Batch write of today's menu: upsert some dishes, remove others. */
export class SaveDailyMenuDto {
  // Optional client echo of the date it is editing. If present it MUST equal
  // today (IST) — the service rejects a stale screen trying to write the past.
  @IsOptional()
  @IsString()
  date?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => DailyUpsertDto)
  upserts?: DailyUpsertDto[];

  @IsOptional()
  @IsArray()
  @IsUUID('all', { each: true })
  removals?: string[];
}
