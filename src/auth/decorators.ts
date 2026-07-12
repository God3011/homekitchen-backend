import {
  createParamDecorator,
  ExecutionContext,
  SetMetadata,
} from '@nestjs/common';

/** Attached to `request.user` by FirebaseAuthGuard. */
export interface RequestUser {
  /** "customer" | "kitchen" | "admin" */
  role: 'customer' | 'kitchen' | 'admin';
  /** The database row id (UUID). */
  userId: string;
  /** The Firebase UID from the verified token. */
  firebaseUid: string;
}

/**
 * Parameter decorator — extracts the authenticated user from the request.
 *
 * Usage:
 *   @Get('me')
 *   getProfile(@CurrentUser() user: RequestUser) { ... }
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): RequestUser => {
    return ctx.switchToHttp().getRequest().user;
  },
);

/** Metadata key used by FirebaseAuthGuard to skip token verification. */
export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Route decorator — marks an endpoint as public (no auth required).
 *
 * Usage:
 *   @Public()
 *   @Get('health')
 *   check() { ... }
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
