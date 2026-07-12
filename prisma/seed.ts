import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  // Single-row platform config: ₹5 fee, ₹50/day seller fee, ₹200 cap.
  await prisma.platformConfig.upsert({
    where: { id: 1 },
    update: {},
    create: { id: 1 },
  });

  // One starter zone so discovery has something to return in dev.
  const zone = await prisma.zone.upsert({
    where: { id: '00000000-0000-0000-0000-000000000001' },
    update: {},
    create: {
      id: '00000000-0000-0000-0000-000000000001',
      name: 'Gachibowli',
      centerLat: 17.4401,
      centerLng: 78.3489,
      radiusM: 5000,
    },
  });

  console.log('Seeded platform config + zone:', zone.name);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
