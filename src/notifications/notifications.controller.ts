import { Body, Controller, Post } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { RegisterTokenDto, RemoveTokenDto } from './dto/register-token.dto';
import { CurrentUser, RequestUser } from '../auth/decorators';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  /** Register an FCM device token for the authenticated user. */
  @Post('device-tokens')
  registerToken(
    @CurrentUser() user: RequestUser,
    @Body() dto: RegisterTokenDto,
  ) {
    return this.notifications.registerToken(
      user.role,
      user.userId,
      dto.fcmToken,
      dto.deviceInfo,
    );
  }

  /** Remove an FCM device token (e.g. on logout). */
  @Post('device-tokens/remove')
  removeToken(@Body() dto: RemoveTokenDto) {
    return this.notifications.removeToken(dto.fcmToken);
  }
}
