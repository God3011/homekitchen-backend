/**
 * Dev seed: populate the marketplace with home kitchens around the areas of the
 * real users currently in the DB, so radius-based discovery returns a populated,
 * serviceable list. Idempotent — re-running upserts kitchens by phone and
 * rebuilds their menu/hours/daily-status for today.
 *
 * Run:  npx ts-node scripts/seed-marketplace.ts
 */
import { PrismaClient, PreferenceType, KitchenStatus } from '@prisma/client';
import { istServiceDate } from '../src/common/service-date';

const prisma = new PrismaClient();

const serviceDate = istServiceDate();
// Broad daily window so kitchens are serviceable across typical testing hours.
const OPEN = '06:00';
const CLOSE = '23:59';

function distanceM(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

// ── Images ──────────────────────────────────────────────────────────────────
// Keyword-matched stock photos from loremflickr, with a stable `lock` per image
// so the same URL always resolves to the same picture. The apps render these via
// Image.network, so any reachable URL works. `lock` is deterministic (the arrays
// below never change order), so re-running the seed keeps images stable.
let lockCounter = 1000;
function img(keyword: string, size = '800/600'): string {
  return `https://loremflickr.com/${size}/${encodeURIComponent(keyword)}?lock=${lockCounter++}`;
}

/** Map a dish name to a food keyword so its photo actually looks like the dish. */
function dishKeyword(name: string): string {
  const n = name.toLowerCase();
  const rules: [string, string][] = [
    ['biryani', 'biryani'],
    ['dosa', 'dosa'],
    ['pesarattu', 'dosa'],
    ['idli', 'idli'],
    ['vada', 'idli'],
    ['paneer', 'paneer'],
    ['paratha', 'paratha'],
    ['prawn', 'prawn'],
    ['chepala', 'fish'],
    ['fish', 'fish'],
    ['mutton', 'mutton'],
    ['kodi', 'chicken'],
    ['chicken', 'chicken'],
    ['egg', 'egg'],
    ['thali', 'thali'],
    ['meals', 'thali'],
    ['rajma', 'curry'],
    ['chole', 'curry'],
    ['salan', 'curry'],
    ['pulusu', 'curry'],
    ['pappu', 'dal'],
    ['dal', 'dal'],
    ['sambar', 'rice'],
    ['bisi bele', 'rice'],
    ['pongal', 'rice'],
    ['rice', 'rice'],
    ['meetha', 'dessert'],
    ['kesari', 'dessert'],
    ['sarva pindi', 'snack'],
    ['sakinalu', 'snack'],
    ['upma', 'breakfast'],
  ];
  for (const [k, v] of rules) if (n.includes(k)) return v;
  return 'food';
}

type Dish = {
  name: string;
  rupees: number;
  isVeg: boolean;
  prefs?: PreferenceType[];
  platesTotal: number;
  platesRemaining?: number;
};

type KitchenSeed = {
  phone: string;
  kitchenName: string;
  cookName: string;
  signatureDish: string;
  story: string;
  addressLine: string;
  lat: number;
  lng: number;
  dishes: Dish[];
};

const P = PreferenceType;

// Cluster A — around (17.4414, 78.4530): Nanakramguda / Khajaguda / Financial
// District. Serves both users (Shanmukh's active "Home" + Sha's home zone).
const clusterA: KitchenSeed[] = [
  {
    phone: '+919000000101',
    kitchenName: 'Andhra Ruchulu',
    cookName: 'Lakshmi Devi',
    signatureDish: 'Gongura Mutton',
    story: 'Home-style Andhra meals cooked the way my grandmother taught me in Guntur.',
    addressLine: 'Nanakramguda, near Financial District',
    lat: 17.4438, lng: 78.4512,
    dishes: [
      { name: 'Gongura Mutton', rupees: 190, isVeg: false, prefs: [P.less_spicy, P.normal_spicy, P.extra_spicy], platesTotal: 20 },
      { name: 'Andhra Veg Thali', rupees: 130, isVeg: true, prefs: [P.no_onion, P.less_oil, P.extra_rice], platesTotal: 30 },
      { name: 'Kodi Vepudu', rupees: 170, isVeg: false, prefs: [P.normal_spicy, P.extra_spicy], platesTotal: 18 },
      { name: 'Pappu Charu Rice', rupees: 90, isVeg: true, prefs: [P.less_spicy, P.extra_rice], platesTotal: 25 },
    ],
  },
  {
    phone: '+919000000102',
    kitchenName: "Amma's Kitchen",
    cookName: 'Padma Rani',
    signatureDish: 'South Indian Veg Thali',
    story: 'Pure-veg homely lunch, freshly cooked every morning for working folks nearby.',
    addressLine: 'Khajaguda, near Lanco Hills',
    lat: 17.4390, lng: 78.4551,
    dishes: [
      { name: 'Full Veg Meals', rupees: 120, isVeg: true, prefs: [P.no_onion, P.no_garlic, P.extra_rice], platesTotal: 40 },
      { name: 'Curd Rice', rupees: 60, isVeg: true, prefs: [P.less_spicy], platesTotal: 25 },
      { name: 'Sambar Rice', rupees: 80, isVeg: true, prefs: [P.less_oil, P.extra_rice], platesTotal: 25 },
      { name: 'Ghee Podi Idli', rupees: 70, isVeg: true, prefs: [P.less_oil], platesTotal: 20 },
    ],
  },
  {
    phone: '+919000000103',
    kitchenName: 'Telangana Tiffins',
    cookName: 'Saroja',
    signatureDish: 'Sarva Pindi',
    story: 'Authentic Telangana breakfast and tiffins, a taste of Karimnagar at home.',
    addressLine: 'Gowlidoddi, Financial District',
    lat: 17.4452, lng: 78.4568,
    dishes: [
      { name: 'Sarva Pindi', rupees: 90, isVeg: true, prefs: [P.less_spicy, P.extra_spicy], platesTotal: 22 },
      { name: 'Sakinalu Combo', rupees: 110, isVeg: true, platesTotal: 15 },
      { name: 'Egg Dosa', rupees: 85, isVeg: false, prefs: [P.no_onion], platesTotal: 20 },
      { name: 'Ragi Sangati with Natu Kodi', rupees: 180, isVeg: false, prefs: [P.normal_spicy, P.extra_spicy], platesTotal: 12 },
    ],
  },
  {
    phone: '+919000000104',
    kitchenName: 'Hyderabadi Dawat',
    cookName: 'Ayesha Begum',
    signatureDish: 'Chicken Dum Biryani',
    story: 'Slow-cooked dum biryani and Hyderabadi curries from a family recipe of 40 years.',
    addressLine: 'Puppalaguda main road',
    lat: 17.4375, lng: 78.4498,
    dishes: [
      { name: 'Chicken Dum Biryani', rupees: 190, isVeg: false, prefs: [P.less_spicy, P.normal_spicy, P.extra_spicy], platesTotal: 35 },
      { name: 'Veg Dum Biryani', rupees: 140, isVeg: true, prefs: [P.less_spicy, P.no_onion], platesTotal: 20 },
      { name: 'Mirchi Ka Salan', rupees: 70, isVeg: true, prefs: [P.less_oil], platesTotal: 20 },
      { name: 'Double Ka Meetha', rupees: 60, isVeg: true, platesTotal: 18 },
    ],
  },
  {
    phone: '+919000000105',
    kitchenName: 'Ghar Ka Khana',
    cookName: 'Sunita Sharma',
    signatureDish: 'Rajma Chawal',
    story: 'North Indian comfort food — rotis, dal and sabzi, just like home in Delhi.',
    addressLine: 'Kokapet, near Neopolis',
    lat: 17.4468, lng: 78.4485,
    dishes: [
      { name: 'Rajma Chawal', rupees: 110, isVeg: true, prefs: [P.less_spicy, P.extra_rice], platesTotal: 24 },
      { name: 'Chole with 4 Rotis', rupees: 120, isVeg: true, prefs: [P.no_onion, P.no_garlic], platesTotal: 24 },
      { name: 'Paneer Butter Masala', rupees: 160, isVeg: true, prefs: [P.less_spicy, P.less_oil], platesTotal: 20 },
      { name: 'Aloo Paratha (2)', rupees: 90, isVeg: true, prefs: [P.less_oil], platesTotal: 20 },
    ],
  },
  {
    phone: '+919000000106',
    kitchenName: 'Coastal Curry House',
    cookName: 'Vijaya Kumari',
    signatureDish: 'Prawn Pulusu',
    story: 'Konaseema-style seafood and coastal Andhra curries, freshly made to order.',
    addressLine: 'Manikonda, near Alkapur',
    lat: 17.4420, lng: 78.4602,
    dishes: [
      { name: 'Prawn Pulusu with Rice', rupees: 195, isVeg: false, prefs: [P.normal_spicy, P.extra_spicy], platesTotal: 15 },
      { name: 'Fish Fry Meals', rupees: 185, isVeg: false, prefs: [P.less_spicy, P.normal_spicy], platesTotal: 15 },
      { name: 'Veg Meals', rupees: 100, isVeg: true, prefs: [P.no_onion, P.extra_rice], platesTotal: 20 },
      { name: 'Chepala Pulusu', rupees: 190, isVeg: false, prefs: [P.extra_spicy], platesTotal: 12 },
    ],
  },
];

// Cluster B — around (17.3660, 78.4230): Manikonda / Puppalaguda. Covers
// Shanmukh's secondary saved addresses (Honey / Hh).
const clusterB: KitchenSeed[] = [
  {
    phone: '+919000000201',
    kitchenName: 'Sri Sai Bhojanam',
    cookName: 'Radha Krishna',
    signatureDish: 'Unlimited Veg Meals',
    story: 'Simple, satisfying veg meals served with a smile since 2015.',
    addressLine: 'Manikonda X Roads',
    lat: 17.3685, lng: 78.4255,
    dishes: [
      { name: 'Unlimited Veg Meals', rupees: 130, isVeg: true, prefs: [P.no_onion, P.no_garlic, P.extra_rice], platesTotal: 40 },
      { name: 'Tomato Rice', rupees: 70, isVeg: true, prefs: [P.less_spicy], platesTotal: 20 },
      { name: 'Bisi Bele Bath', rupees: 90, isVeg: true, prefs: [P.less_oil, P.extra_rice], platesTotal: 20 },
      { name: 'Rava Kesari', rupees: 55, isVeg: true, platesTotal: 18 },
    ],
  },
  {
    phone: '+919000000202',
    kitchenName: 'Deccan Biryani Home',
    cookName: 'Imran Khan',
    signatureDish: 'Mutton Biryani',
    story: 'Small-batch mutton and chicken biryani cooked on firewood, packed hot.',
    addressLine: 'Puppalaguda, near Rajendra Nagar',
    lat: 17.3632, lng: 78.4208,
    dishes: [
      { name: 'Mutton Biryani', rupees: 200, isVeg: false, prefs: [P.less_spicy, P.normal_spicy, P.extra_spicy], platesTotal: 25 },
      { name: 'Chicken Biryani', rupees: 170, isVeg: false, prefs: [P.less_spicy, P.normal_spicy], platesTotal: 30 },
      { name: 'Egg Biryani', rupees: 120, isVeg: false, prefs: [P.normal_spicy], platesTotal: 20 },
      { name: 'Veg Biryani', rupees: 110, isVeg: true, prefs: [P.no_onion], platesTotal: 15 },
    ],
  },
  {
    phone: '+919000000203',
    kitchenName: 'Home Bites',
    cookName: 'Anitha Reddy',
    signatureDish: 'Pesarattu Upma',
    story: 'Healthy millet tiffins and everyday South Indian breakfast, home-delivered fresh.',
    addressLine: 'Narsingi, near Q City',
    lat: 17.3700, lng: 78.4190,
    dishes: [
      { name: 'Pesarattu Upma', rupees: 80, isVeg: true, prefs: [P.less_oil, P.no_onion], platesTotal: 22 },
      { name: 'Millet Pongal', rupees: 90, isVeg: true, prefs: [P.less_oil, P.less_spicy], platesTotal: 20 },
      { name: 'Idli Vada Combo', rupees: 75, isVeg: true, prefs: [P.extra_rice], platesTotal: 25 },
      { name: 'Masala Dosa', rupees: 85, isVeg: true, prefs: [P.no_onion, P.less_oil], platesTotal: 25 },
    ],
  },
];

async function upsertKitchen(k: KitchenSeed, zones: { id: string; centerLat: number; centerLng: number }[]) {
  // Nearest zone as the passive analytics label (nullable if none).
  let zoneId: string | null = null;
  let best = Infinity;
  for (const z of zones) {
    const d = distanceM(k.lat, k.lng, z.centerLat, z.centerLng);
    if (d < best) { best = d; zoneId = z.id; }
  }

  // Cook portrait + two kitchen shots (a hero of the signature dish, plus an
  // ambience photo). Built before the dish loop so lock ordering is stable.
  const cookPhotoUrl = img('chef', '600/600');
  const kitchenPhotoUrls = [img(dishKeyword(k.signatureDish)), img('restaurant')];

  const kitchen = await prisma.kitchen.upsert({
    where: { phone: k.phone },
    update: {
      kitchenName: k.kitchenName, cookName: k.cookName, signatureDish: k.signatureDish,
      story: k.story, addressLine: k.addressLine, lat: k.lat, lng: k.lng,
      status: KitchenStatus.verified, verifiedAt: new Date(), zoneId,
      cookPhotoUrl, kitchenPhotoUrls,
    },
    create: {
      phone: k.phone, kitchenName: k.kitchenName, cookName: k.cookName,
      signatureDish: k.signatureDish, story: k.story, addressLine: k.addressLine,
      lat: k.lat, lng: k.lng, status: KitchenStatus.verified, verifiedAt: new Date(),
      zoneId, cookPhotoUrl, kitchenPhotoUrls,
    },
  });

  // Operating hours: same window every day (upsert per weekday).
  for (let day = 0; day < 7; day++) {
    await prisma.kitchenHours.upsert({
      where: { kitchenId_dayOfWeek: { kitchenId: kitchen.id, dayOfWeek: day } },
      update: { openTime: OPEN, closeTime: CLOSE },
      create: { kitchenId: kitchen.id, dayOfWeek: day, openTime: OPEN, closeTime: CLOSE },
    });
  }

  // Cooking today.
  await prisma.kitchenDailyStatus.upsert({
    where: { kitchenId_serviceDate: { kitchenId: kitchen.id, serviceDate } },
    update: { isCooking: true },
    create: { kitchenId: kitchen.id, serviceDate, isCooking: true },
  });

  // Rebuild menu (cascade clears availability + preferences).
  await prisma.menuItem.deleteMany({ where: { kitchenId: kitchen.id } });
  for (const d of k.dishes) {
    const item = await prisma.menuItem.create({
      data: {
        kitchenId: kitchen.id, name: d.name, pricePaise: d.rupees * 100,
        isVeg: d.isVeg, isActive: true, photoUrl: img(dishKeyword(d.name)),
        preferences: d.prefs?.length
          ? { create: d.prefs.map((p) => ({ preference: p })) }
          : undefined,
        availability: {
          create: {
            serviceDate,
            platesTotal: d.platesTotal,
            platesRemaining: d.platesRemaining ?? d.platesTotal,
            isAvailable: true,
          },
        },
      },
    });
    void item;
  }

  return kitchen;
}

async function main() {
  const zones = await prisma.zone.findMany({
    select: { id: true, centerLat: true, centerLng: true },
  });
  const all = [...clusterA, ...clusterB];
  for (const k of all) {
    const kitchen = await upsertKitchen(k, zones);
    console.log(`✔ ${kitchen.kitchenName}  (${k.lat}, ${k.lng})  ${k.dishes.length} dishes`);
  }
  console.log(`\nSeeded ${all.length} kitchens for serviceDate ${serviceDate.toISOString().slice(0, 10)}.`);
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
