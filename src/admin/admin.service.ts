import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { KitchensService } from '../kitchens/kitchens.service';
import { parseServiceDate } from '../common/service-date';
import { CreatePayoutDto } from './dto/create-payout.dto';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly kitchens: KitchensService,
  ) {}

  /**
   * Record a manual UPI payout (v1 payouts are scheduled/manual — this is how
   * ops logs the transfer). Rejects a payout larger than the kitchen's current
   * pending balance so recorded payouts can never exceed net earnings.
   */
  async createPayout(dto: CreatePayoutDto) {
    const kitchen = await this.prisma.kitchen.findUnique({
      where: { id: dto.kitchenId },
      select: { id: true },
    });
    if (!kitchen) throw new NotFoundException('Kitchen not found.');

    let payoutDate: Date;
    try {
      payoutDate = parseServiceDate(dto.payoutDate);
    } catch (e) {
      throw new BadRequestException((e as Error).message);
    }

    const pending = await this.kitchens.pendingBalancePaise(dto.kitchenId);
    if (dto.amountPaise > pending) {
      throw new BadRequestException(
        `Payout (₹${dto.amountPaise / 100}) exceeds the kitchen's pending balance (₹${pending / 100}).`,
      );
    }

    return this.prisma.payout.create({
      data: {
        kitchenId: dto.kitchenId,
        amountPaise: dto.amountPaise,
        payoutDate,
        note: dto.note,
      },
    });
  }
}
