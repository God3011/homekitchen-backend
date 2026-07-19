import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';

/**
 * Customer saved locations. A saved location is a named point (label + lat/lng),
 * NOT a delivery destination (the app is pickup-only). The customer's default
 * address is the centre that radius-based discovery searches around.
 *
 * Invariants enforced here:
 *  - Every mutation is scoped to the caller's own customerId (cross-customer
 *    access returns 404, never leaks existence).
 *  - Exactly one address per customer is `isDefault` at a time.
 *  - While a customer still has any addresses, one of them is always the default
 *    (deleting the default promotes another).
 */
@Injectable()
export class AddressesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Fetch an address that belongs to this customer, or 404. */
  private async ownedOrThrow(customerId: string, id: string) {
    const address = await this.prisma.customerAddress.findFirst({
      where: { id, customerId },
    });
    if (!address) {
      throw new NotFoundException('Address not found.');
    }
    return address;
  }

  /** List the customer's saved locations, default (active) first. */
  list(customerId: string) {
    return this.prisma.customerAddress.findMany({
      where: { customerId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'asc' }],
    });
  }

  /** Create a saved location. The first address — or any created with
   *  isDefault=true — becomes the active default and unsets the others. */
  async create(customerId: string, dto: CreateAddressDto) {
    return this.prisma.$transaction(async (tx) => {
      const count = await tx.customerAddress.count({ where: { customerId } });
      const makeDefault = dto.isDefault === true || count === 0;

      if (makeDefault) {
        await tx.customerAddress.updateMany({
          where: { customerId, isDefault: true },
          data: { isDefault: false },
        });
      }

      return tx.customerAddress.create({
        data: {
          customerId,
          label: dto.label,
          addressLine: dto.addressLine ?? null,
          lat: dto.lat,
          lng: dto.lng,
          isDefault: makeDefault,
        },
      });
    });
  }

  /** Edit label / display line / coordinates. Default flag is not changed here
   *  (use setDefault). lat and lng must be supplied together. */
  async update(customerId: string, id: string, dto: UpdateAddressDto) {
    await this.ownedOrThrow(customerId, id);

    if ((dto.lat == null) !== (dto.lng == null)) {
      throw new BadRequestException('lat and lng must be provided together.');
    }

    const data: Prisma.CustomerAddressUpdateInput = {};
    if (dto.label !== undefined) data.label = dto.label;
    if (dto.addressLine !== undefined) data.addressLine = dto.addressLine;
    if (dto.lat != null && dto.lng != null) {
      data.lat = dto.lat;
      data.lng = dto.lng;
    }

    return this.prisma.customerAddress.update({ where: { id }, data });
  }

  /** Make this address the active/default one and unset any other default. */
  async setDefault(customerId: string, id: string) {
    await this.ownedOrThrow(customerId, id);

    return this.prisma.$transaction(async (tx) => {
      await tx.customerAddress.updateMany({
        where: { customerId, isDefault: true, NOT: { id } },
        data: { isDefault: false },
      });
      return tx.customerAddress.update({
        where: { id },
        data: { isDefault: true },
      });
    });
  }

  /** Delete a saved location. If it was the default and other addresses remain,
   *  promote the oldest survivor so the customer is never left default-less. */
  async remove(customerId: string, id: string) {
    const target = await this.ownedOrThrow(customerId, id);

    return this.prisma.$transaction(async (tx) => {
      await tx.customerAddress.delete({ where: { id } });

      if (target.isDefault) {
        const next = await tx.customerAddress.findFirst({
          where: { customerId },
          orderBy: { createdAt: 'asc' },
        });
        if (next) {
          await tx.customerAddress.update({
            where: { id: next.id },
            data: { isDefault: true },
          });
        }
      }

      return { deleted: true };
    });
  }
}
