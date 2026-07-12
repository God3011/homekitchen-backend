import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ForbiddenException,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RequestUser } from './decorators';

export const ROLES_KEY = 'roles';

/**
 * Route decorator — restricts access to specific roles.
 *
 * Usage:
 *   @Roles('kitchen')
 *   @Patch(':id/accept')
 *   accept(...) { ... }
 */
export const Roles = (...roles: RequestUser['role'][]) =>
  SetMetadata(ROLES_KEY, roles);

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(ctx: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<
      RequestUser['role'][] | undefined
    >(ROLES_KEY, [ctx.getHandler(), ctx.getClass()]);

    // No @Roles() decorator → allow anyone who is authenticated.
    if (!required?.length) return true;

    const user: RequestUser = ctx.switchToHttp().getRequest().user;
    if (!required.includes(user.role)) {
      throw new ForbiddenException(
        `This action requires one of: ${required.join(', ')}.`,
      );
    }
    return true;
  }
}
