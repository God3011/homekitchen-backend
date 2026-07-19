import {
  IsBoolean,
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { Type } from 'class-transformer';

// A saved location is a NAMED point (label + lat/lng), not a delivery address.
// Coordinates are required because radius-based discovery keys off lat/lng.
export class CreateAddressDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  label: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  addressLine?: string;

  @Type(() => Number)
  @IsLatitude()
  lat: number;

  @Type(() => Number)
  @IsLongitude()
  lng: number;

  // When true (or when this is the customer's first address), it becomes the
  // active/default search centre and any other default is unset.
  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}
