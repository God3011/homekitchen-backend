import {
  IsArray, IsEnum, IsInt, IsOptional, IsUUID, Min, ValidateNested, ArrayMinSize,
} from 'class-validator';
import { Type } from 'class-transformer';
import { FulfillmentType, PreferenceType } from '@prisma/client';

class OrderItemInput {
  @IsUUID()
  menuItemId: string;

  @IsInt()
  @Min(1)
  quantity: number;

  @IsOptional()
  @IsArray()
  @IsEnum(PreferenceType, { each: true })
  preferences?: PreferenceType[];
}

export class CreateOrderDto {
  @IsUUID()
  customerId: string;

  @IsUUID()
  kitchenId: string;

  @IsEnum(FulfillmentType)
  fulfillment: FulfillmentType;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => OrderItemInput)
  items: OrderItemInput[];
}
