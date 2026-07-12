import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../prisma/prisma.service';
import { FirebaseService } from './firebase.service';
import { IS_PUBLIC_KEY, RequestUser } from './decorators';

@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor(
    private readonly firebase: FirebaseService,
    private readonly prisma: PrismaService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    // Allow @Public() routes through without a token.
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (isPublic) return true;

    const request = ctx.switchToHttp().getRequest();
    const authHeader: string | undefined = request.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing or malformed Authorization header.');
    }

    const idToken = authHeader.slice(7);
    let firebaseUid: string;
    try {
      const decoded = await this.firebase.verifyIdToken(idToken);
      firebaseUid = decoded.uid;
    } catch {
      throw new UnauthorizedException('Invalid or expired Firebase token.');
    }

    // Look up the user across all three actor tables.
    const user = await this.resolveUser(firebaseUid);
    if (!user) {
      throw new UnauthorizedException(
        'No account linked to this Firebase UID. Complete signup first.',
      );
    }

    request.user = user;
    return true;
  }

  private async resolveUser(firebaseUid: string): Promise<RequestUser | null> {
    // Check customer first (most common caller), then kitchen, then admin.
    const customer = await this.prisma.customer.findUnique({
      where: { firebaseUid },
      select: { id: true },
    });
    if (customer) {
      return { role: 'customer', userId: customer.id, firebaseUid };
    }

    const kitchen = await this.prisma.kitchen.findUnique({
      where: { firebaseUid },
      select: { id: true },
    });
    if (kitchen) {
      return { role: 'kitchen', userId: kitchen.id, firebaseUid };
    }

    const admin = await this.prisma.admin.findUnique({
      where: { firebaseUid },
      select: { id: true },
    });
    if (admin) {
      return { role: 'admin', userId: admin.id, firebaseUid };
    }

    return null;
  }
}
