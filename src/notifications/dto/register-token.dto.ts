import { IsOptional, IsString } from 'class-validator';

export class RegisterTokenDto {
  @IsString()
  fcmToken: string;

  @IsOptional()
  @IsString()
  deviceInfo?: string;
}

export class RemoveTokenDto {
  @IsString()
  fcmToken: string;
}
