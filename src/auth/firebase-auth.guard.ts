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

    // The same phone number (Firebase UID) can be BOTH a customer and a kitchen.
    // Each app declares which role it's acting as via the `X-Client-App` header
    // so we resolve to the right identity; without it we fall back to a fixed
    // order. Resolution never lets an app claim a role it isn't registered for —
    // it only picks among the tables the UID actually exists in.
    const clientApp = (
      request.headers['x-client-app'] as string | undefined
    )?.toLowerCase();

    const user = await this.resolveUser(firebaseUid, clientApp);
    if (!user) {
      throw new UnauthorizedException(
        'No account linked to this Firebase UID. Complete signup first.',
      );
    }

    request.user = user;
    return true;
  }

  private async resolveUser(
    firebaseUid: string,
    preferred?: string,
  ): Promise<RequestUser | null> {
    const lookups: Record<
      RequestUser['role'],
      () => Promise<RequestUser | null>
    > = {
      customer: async () => {
        const c = await this.prisma.customer.findUnique({
          where: { firebaseUid },
          select: { id: true },
        });
        return c ? { role: 'customer', userId: c.id, firebaseUid } : null;
      },
      kitchen: async () => {
        const k = await this.prisma.kitchen.findUnique({
          where: { firebaseUid },
          select: { id: true },
        });
        return k ? { role: 'kitchen', userId: k.id, firebaseUid } : null;
      },
      admin: async () => {
        const a = await this.prisma.admin.findUnique({
          where: { firebaseUid },
          select: { id: true },
        });
        return a ? { role: 'admin', userId: a.id, firebaseUid } : null;
      },
    };

    // Default order (customer first) preserved when no/invalid header is sent.
    const defaultOrder: RequestUser['role'][] = ['customer', 'kitchen', 'admin'];
    const order =
      preferred && preferred in lookups
        ? [
            preferred as RequestUser['role'],
            ...defaultOrder.filter((r) => r !== preferred),
          ]
        : defaultOrder;

    for (const role of order) {
      const found = await lookups[role]();
      if (found) return found;
    }
    return null;
  }
}
