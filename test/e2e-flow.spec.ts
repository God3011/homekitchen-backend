/**
 * Homely Backend — End-to-End Flow Test
 *
 * HOW TO RUN
 * ----------
 *   1. Start Postgres:  docker-compose up -d db
 *   2. Run the test:    npm run test:e2e
 *
 * WHAT HAPPENS
 * ------------
 * - Creates a temporary "homekitchen_test" database, pushes the Prisma
 *   schema, seeds PlatformConfig + Zone + Admin + Customer, runs the full
 *   lifecycle, and drops the database on teardown.
 * - Firebase auth is MOCKED — no emulator, no real tokens.  Three fixed
 *   Bearer tokens map to three roles:
 *       "kitchen-test-token"  → kitchen (signs up during test)
 *       "customer-test-token" → customer (pre-seeded)
 *       "admin-test-token"    → admin    (pre-seeded)
 *   The real FirebaseAuthGuard still runs; only FirebaseService.verifyIdToken
 *   is stubbed, so role resolution from the DB is fully exercised.
 * - NotificationsService is mocked to avoid a dependency on a live
 *   Firebase app for FCM messaging.
 */

import { execSync } from 'child_process';
import * as path from 'path';
import { Test } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { FirebaseService } from '../src/auth/firebase.service';
import { NotificationsService } from '../src/notifications/notifications.service';
import { StorageService } from '../src/storage/storage.service';

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const TEST_DB = 'homekitchen_test';
const PG_BASE = 'postgresql://homekitchen:homekitchen@localhost:5432';
const TEST_DB_URL = `${PG_BASE}/${TEST_DB}?schema=public`;

// Must be set before NestJS reads process.env
process.env.DATABASE_URL = TEST_DB_URL;

// Fake decoded-token payloads keyed by Bearer token string
const DECODED_TOKENS: Record<string, { uid: string; phone_number?: string }> = {
  'kitchen-test-token': { uid: 'fb-kitchen-001', phone_number: '+919876543210' },
  'kitchen2-test-token': { uid: 'fb-kitchen-002', phone_number: '+919876543299' },
  'customer-test-token': { uid: 'fb-customer-001' },
  'admin-test-token': { uid: 'fb-admin-001' },
};

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class MockFirebaseService {
  onModuleInit() {
    /* no-op — skip real Firebase Admin SDK init */
  }
  async verifyIdToken(token: string) {
    const decoded = DECODED_TOKENS[token];
    if (!decoded) throw new Error(`Unknown test token: ${token}`);
    return decoded;
  }
}

class MockNotificationsService {
  onModuleInit() {
    /* no-op — skip getMessaging() which needs a live Firebase app */
  }
  registerToken() {
    return Promise.resolve({});
  }
  removeToken() {
    return Promise.resolve({ removed: true });
  }
  sendPush() {
    return Promise.resolve();
  }
  sendWhatsApp() {
    return Promise.resolve();
  }
  notifyOrderEvent() {
    return Promise.resolve();
  }
}

// Avoids real R2 uploads — returns fake public URLs for signup/dish photos.
class MockStorageService {
  get isConfigured() {
    return true;
  }
  uploadImage() {
    return Promise.resolve('https://r2.test/img.jpg');
  }
  uploadImages(files: unknown[]) {
    return Promise.resolve(files.map(() => 'https://r2.test/img.jpg'));
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Mirrors OrdersService.serviceDate() — local midnight, then take its UTC
 *  date string so Prisma stores the same DATE value in Postgres. */
function todayDateStr(): string {
  // Local calendar day as "YYYY-MM-DD" — matches OrdersService.serviceDate(),
  // which now resolves to UTC-midnight of the local day.
  const n = new Date();
  return `${n.getFullYear()}-${String(n.getMonth() + 1).padStart(2, '0')}-${String(n.getDate()).padStart(2, '0')}`;
}

/** Create / drop the test database via a throw-away PrismaClient aimed at
 *  the default "postgres" database. */
async function adminExec(sql: string) {
  const client = new PrismaClient({
    datasources: { db: { url: `${PG_BASE}/postgres?schema=public` } },
  });
  await client.$connect();
  try {
    await client.$executeRawUnsafe(sql);
  } finally {
    await client.$disconnect();
  }
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------
describe('E2E: Full order lifecycle', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const ZONE_ID = '54653fb6-c8dc-47b9-a736-20261b5c889e';
  let kitchenId: string;
  let customerId: string;
  let categoryId: string;
  let menuItemId: string;
  let orderId: string;
  let handoverCode: string;

  // ── Global setup ──────────────────────────────────────────────────────
  beforeAll(async () => {
    // 1. Create a fresh test database
    await adminExec(`
      SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname = '${TEST_DB}' AND pid <> pg_backend_pid()
    `);
    await adminExec(`DROP DATABASE IF EXISTS "${TEST_DB}"`);
    await adminExec(`CREATE DATABASE "${TEST_DB}"`);

    // 2. Push Prisma schema (no migrations needed for tests)
    execSync('npx prisma@6 db push --skip-generate --accept-data-loss', {
      cwd: path.join(__dirname, '..'),
      env: { ...process.env, DATABASE_URL: TEST_DB_URL },
      stdio: 'pipe',
    });

    // 3. Boot NestJS with mocked Firebase + Notifications
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(FirebaseService)
      .useClass(MockFirebaseService)
      .overrideProvider(NotificationsService)
      .useClass(MockNotificationsService)
      .overrideProvider(StorageService)
      .useClass(MockStorageService)
      .compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();

    prisma = moduleRef.get(PrismaService);

    // 4. Seed reference data
    await prisma.platformConfig.create({ data: { id: 1 } }); // defaults: ₹5 fee, ₹200 per-item cap, lowStockThreshold: 3
    await prisma.zone.create({
      data: {
        id: ZONE_ID,
        name: 'Gachibowli',
        centerLat: 17.4401,
        centerLng: 78.3489,
      },
    });
    await prisma.admin.create({
      data: {
        firebaseUid: DECODED_TOKENS['admin-test-token'].uid,
        email: 'admin@homely.test',
        name: 'Test Admin',
      },
    });
    const cust = await prisma.customer.create({
      data: {
        firebaseUid: DECODED_TOKENS['customer-test-token'].uid,
        phone: '+919876543211',
        name: 'Test Customer',
        homeZoneId: ZONE_ID,
      },
    });
    customerId = cust.id;
  }, 60_000);

  // ── Global teardown ───────────────────────────────────────────────────
  afterAll(async () => {
    await app?.close();
    try {
      await adminExec(`
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE datname = '${TEST_DB}' AND pid <> pg_backend_pid()
      `);
      await adminExec(`DROP DATABASE IF EXISTS "${TEST_DB}"`);
    } catch {
      /* best-effort cleanup */
    }
  }, 30_000);

  // =====================================================================
  // Step 1 — Kitchen signup
  // =====================================================================
  it('1. Kitchen signs up (starts pending_review)', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/kitchens/signup')
      .set('Authorization', 'Bearer kitchen-test-token')
      .field('kitchenName', 'Amma Kitchen')
      .field('zoneId', ZONE_ID)
      .attach('kitchenPhotos', Buffer.from('fake-image'), 'kitchen.jpg')
      .attach('selfPhoto', Buffer.from('fake-image'), 'self.jpg');

    expect(res.status).toBe(201);
    kitchenId = res.body.id;
    expect(res.body.status).toBe('pending_review');
    expect(res.body.kitchenName).toBe('Amma Kitchen');
    expect(res.body.firebaseUid).toBe('fb-kitchen-001');
    expect(res.body.phone).toBe('+919876543210');
  });

  // =====================================================================
  // Step 2 — Admin verifies kitchen
  // =====================================================================
  it('2. Admin verifies the kitchen via PATCH …/:id/verify', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/kitchens/${kitchenId}/verify`)
      .set('Authorization', 'Bearer admin-test-token')
      .expect(200);

    expect(res.body.status).toBe('verified');
    expect(res.body.verifiedAt).toBeTruthy();
  });

  // =====================================================================
  // Step 3 — Kitchen sets up menu, preferences, availability, hours, toggle
  // =====================================================================
  it('3a. Kitchen creates a menu category', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/menu/categories')
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ name: 'South Indian', sortOrder: 1 })
      .expect(201);

    categoryId = res.body.id;
    expect(res.body.name).toBe('South Indian');
  });

  it('3b. Kitchen creates a menu item (₹150) with initial preferences', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/menu/items')
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({
        name: 'Hyderabadi Biryani',
        categoryId,
        pricePaise: 15000,
        preferences: ['less_spicy', 'extra_rice'],
      })
      .expect(201);

    menuItemId = res.body.id;
    expect(res.body.name).toBe('Hyderabadi Biryani');
    expect(res.body.pricePaise).toBe(15000);
    expect(res.body.preferences).toHaveLength(2);
  });

  it('3c. Kitchen replaces preference toggles', async () => {
    const res = await request(app.getHttpServer())
      .put(`/api/menu/items/${menuItemId}/preferences`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ preferences: ['less_spicy', 'no_onion', 'extra_rice'] })
      .expect(200);

    expect(res.body).toHaveLength(3);
  });

  it('3d. Kitchen sets daily plate availability (20 plates)', async () => {
    const res = await request(app.getHttpServer())
      .put(`/api/menu/items/${menuItemId}/availability`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ serviceDate: todayDateStr(), platesTotal: 20 })
      .expect(200);

    expect(res.body.platesTotal).toBe(20);
    expect(res.body.platesRemaining).toBe(20);
  });

  it('3e. Kitchen toggles "Cooking Today" ON', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/kitchens/me/daily-status')
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ serviceDate: todayDateStr(), isCooking: true })
      .expect(201);

    expect(res.body.isCooking).toBe(true);
  });

  it('3f. Kitchen sets operating hours covering current time', async () => {
    const dayOfWeek = new Date().getDay(); // 0=Sun … 6=Sat
    const res = await request(app.getHttpServer())
      .put('/api/kitchens/me/hours')
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({
        hours: [{ dayOfWeek, openTime: '00:00', closeTime: '23:59' }],
      })
      .expect(200);

    expect(res.body).toHaveLength(1);
    expect(res.body[0].openTime).toBe('00:00');
  });

  // =====================================================================
  // Step 4 — Customer lists kitchens in zone
  // =====================================================================
  it('4. Customer lists verified kitchens → Amma Kitchen appears', async () => {
    const res = await request(app.getHttpServer())
      .get(`/api/kitchens?zoneId=${ZONE_ID}`)
      .set('Authorization', 'Bearer customer-test-token')
      .expect(200);

    expect(Array.isArray(res.body)).toBe(true);
    const found = res.body.find((k: any) => k.id === kitchenId);
    expect(found).toBeTruthy();
    expect(found.kitchenName).toBe('Amma Kitchen');
  });

  // =====================================================================
  // Step 5 — Order placement & business rules
  // =====================================================================
  it('5a. ₹250 menu item rejected at creation (per-item price cap)', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/menu/items')
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({
        name: 'Expensive Dish',
        categoryId,
        pricePaise: 25000, // ₹250 > ₹200 cap
      })
      .expect(400);

    expect(res.body.message).toContain('per-item cap');
  });

  it('5b. 3 × ₹150 = ₹450 order SUCCEEDS (no cart cap)', async () => {
    // Reset plate availability to 20
    await request(app.getHttpServer())
      .put(`/api/menu/items/${menuItemId}/availability`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ serviceDate: todayDateStr(), platesTotal: 20 })
      .expect(200);

    const res = await request(app.getHttpServer())
      .post('/api/orders')
      .set('Authorization', 'Bearer customer-test-token')
      .send({
        customerId,
        kitchenId,
        fulfillment: 'pickup',
        items: [{ menuItemId, quantity: 3 }],
      })
      .expect(201);

    expect(res.body.foodTotalPaise).toBe(45000); // 3 × ₹150
    expect(res.body.grandTotalPaise).toBe(45500); // + ₹5 platform fee
  });

  it('5c. 5 plates requested, only 3 remain → 400 insufficient plates', async () => {
    // Set availability to 3 plates
    await request(app.getHttpServer())
      .put(`/api/menu/items/${menuItemId}/availability`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ serviceDate: todayDateStr(), platesTotal: 3 })
      .expect(200);

    const res = await request(app.getHttpServer())
      .post('/api/orders')
      .set('Authorization', 'Bearer customer-test-token')
      .send({
        customerId,
        kitchenId,
        fulfillment: 'pickup',
        items: [{ menuItemId, quantity: 5 }],
      })
      .expect(400);

    expect(res.body.message).toContain('insufficient plates');
  });

  it('5d. Concurrent orders for last 2 plates → exactly one 201, one 400', async () => {
    // Set availability to 2 plates
    await request(app.getHttpServer())
      .put(`/api/menu/items/${menuItemId}/availability`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ serviceDate: todayDateStr(), platesTotal: 2 })
      .expect(200);

    const [r1, r2] = await Promise.all([
      request(app.getHttpServer())
        .post('/api/orders')
        .set('Authorization', 'Bearer customer-test-token')
        .send({
          customerId,
          kitchenId,
          fulfillment: 'pickup',
          items: [{ menuItemId, quantity: 2 }],
        }),
      request(app.getHttpServer())
        .post('/api/orders')
        .set('Authorization', 'Bearer customer-test-token')
        .send({
          customerId,
          kitchenId,
          fulfillment: 'pickup',
          items: [{ menuItemId, quantity: 2 }],
        }),
    ]);

    const statuses = [r1.status, r2.status].sort();
    expect(statuses).toEqual([201, 400]);
  });

  it('5e. Reject order → platesRemaining restored + isAvailable re-enabled', async () => {
    // Set availability to 5 plates
    await request(app.getHttpServer())
      .put(`/api/menu/items/${menuItemId}/availability`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ serviceDate: todayDateStr(), platesTotal: 5 })
      .expect(200);

    // Place an order for 3 plates
    const orderRes = await request(app.getHttpServer())
      .post('/api/orders')
      .set('Authorization', 'Bearer customer-test-token')
      .send({
        customerId,
        kitchenId,
        fulfillment: 'pickup',
        items: [{ menuItemId, quantity: 3 }],
      })
      .expect(201);

    const rejectOrderId = orderRes.body.id;

    // Verify plates went down to 2
    const availBefore = await prisma.menuDailyAvailability.findUnique({
      where: {
        menuItemId_serviceDate: {
          menuItemId,
          serviceDate: new Date(todayDateStr()),
        },
      },
    });
    expect(availBefore!.platesRemaining).toBe(2);

    // Reject the order
    await request(app.getHttpServer())
      .patch(`/api/orders/${rejectOrderId}/reject`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ reason: 'Out of ingredients' })
      .expect(200);

    // Verify plates restored to 5
    const availAfter = await prisma.menuDailyAvailability.findUnique({
      where: {
        menuItemId_serviceDate: {
          menuItemId,
          serviceDate: new Date(todayDateStr()),
        },
      },
    });
    expect(availAfter!.platesRemaining).toBe(5);
    expect(availAfter!.isAvailable).toBe(true);
  });

  it('5f. Order exhausting plates → isAvailable false + sendPush called with stock_alert', async () => {
    // Set availability to exactly 2 plates
    await request(app.getHttpServer())
      .put(`/api/menu/items/${menuItemId}/availability`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ serviceDate: todayDateStr(), platesTotal: 2 })
      .expect(200);

    // Spy on the mock's sendPush
    const notificationsService = app.get(NotificationsService);
    const sendPushSpy = jest.spyOn(notificationsService, 'sendPush');
    sendPushSpy.mockClear();

    // Place order for all 2 plates → sold out
    await request(app.getHttpServer())
      .post('/api/orders')
      .set('Authorization', 'Bearer customer-test-token')
      .send({
        customerId,
        kitchenId,
        fulfillment: 'pickup',
        items: [{ menuItemId, quantity: 2 }],
      })
      .expect(201);

    // isAvailable should be false now
    const avail = await prisma.menuDailyAvailability.findUnique({
      where: {
        menuItemId_serviceDate: {
          menuItemId,
          serviceDate: new Date(todayDateStr()),
        },
      },
    });
    expect(avail!.platesRemaining).toBe(0);
    expect(avail!.isAvailable).toBe(false);

    // sendPush should have been called with stock_alert
    expect(sendPushSpy).toHaveBeenCalledWith(
      'kitchen',
      kitchenId,
      expect.objectContaining({ type: 'stock_alert' }),
    );

    sendPushSpy.mockRestore();
  });

  it('5g. Order bringing plates below threshold → sendPush called with low-stock warning', async () => {
    // Set availability to 5 plates (threshold defaults to 3)
    await request(app.getHttpServer())
      .put(`/api/menu/items/${menuItemId}/availability`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ serviceDate: todayDateStr(), platesTotal: 5 })
      .expect(200);

    // Spy on the mock's sendPush
    const notificationsService = app.get(NotificationsService);
    const sendPushSpy = jest.spyOn(notificationsService, 'sendPush');
    sendPushSpy.mockClear();

    // Place order for 3 plates → 2 remaining (below threshold of 3)
    await request(app.getHttpServer())
      .post('/api/orders')
      .set('Authorization', 'Bearer customer-test-token')
      .send({
        customerId,
        kitchenId,
        fulfillment: 'pickup',
        items: [{ menuItemId, quantity: 3 }],
      })
      .expect(201);

    // sendPush should have been called with low-stock warning
    expect(sendPushSpy).toHaveBeenCalledWith(
      'kitchen',
      kitchenId,
      expect.objectContaining({
        type: 'stock_alert',
        remaining: '2',
      }),
    );

    sendPushSpy.mockRestore();
  });

  it('5h. Valid order: correct totals, handover code, Payment row', async () => {
    // Reset plates to 20
    await request(app.getHttpServer())
      .put(`/api/menu/items/${menuItemId}/availability`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ serviceDate: todayDateStr(), platesTotal: 20 })
      .expect(200);

    const res = await request(app.getHttpServer())
      .post('/api/orders')
      .set('Authorization', 'Bearer customer-test-token')
      .send({
        customerId,
        kitchenId,
        fulfillment: 'pickup',
        items: [{ menuItemId, quantity: 1 }],
      })
      .expect(201);

    orderId = res.body.id;
    handoverCode = res.body.handoverCode;

    // --- Price assertions ---
    expect(res.body.foodTotalPaise).toBe(15000); // ₹150
    expect(res.body.platformFeePaise).toBe(500); // ₹5 flat fee
    expect(res.body.deliveryFeePaise).toBe(0); // pickup
    expect(res.body.grandTotalPaise).toBe(15500); // food + platform fee
    expect(res.body.status).toBe('received');

    // --- Handover code ---
    expect(typeof handoverCode).toBe('string');
    expect(handoverCode).toMatch(/^\d{4}$/);

    // --- Payment row ---
    expect(res.body.payment).toBeTruthy();
    expect(res.body.payment.amountPaise).toBe(15500);
    expect(res.body.payment.status).toBe('created');

    // --- Snapshotted item ---
    expect(res.body.items).toHaveLength(1);
    expect(res.body.items[0].itemName).toBe('Hyderabadi Biryani');
    expect(res.body.items[0].unitPricePaise).toBe(15000);
    expect(res.body.items[0].quantity).toBe(1);
  });

  // =====================================================================
  // Step 6 — Walk the order through accept → ready → handover → completed
  // =====================================================================
  it('6a. Seller accepts with ETA → preparing', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/orders/${orderId}/accept`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ etaMinutes: 25 })
      .expect(200);

    expect(res.body.status).toBe('preparing');
    expect(res.body.etaMinutes).toBe(25);
    expect(res.body.acceptedAt).toBeTruthy();
  });

  it('6b. Seller marks ready → ready', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/orders/${orderId}/ready`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .expect(200);

    expect(res.body.status).toBe('ready');
    expect(res.body.readyAt).toBeTruthy();
  });

  it('6c. Wrong handover code is rejected', async () => {
    // "0000" is never generated (range is 1000–9999)
    const res = await request(app.getHttpServer())
      .patch(`/api/orders/${orderId}/handover`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ code: '0000' })
      .expect(400);

    expect(res.body.message).toContain('Handover code');
  });

  it('6d. Correct handover code → completed', async () => {
    const res = await request(app.getHttpServer())
      .patch(`/api/orders/${orderId}/handover`)
      .set('Authorization', 'Bearer kitchen-test-token')
      .send({ code: handoverCode })
      .expect(200);

    expect(res.body.status).toBe('completed');
    expect(res.body.completedAt).toBeTruthy();
  });

  // =====================================================================
  // Step 6e — Kitchen lists its own orders
  // =====================================================================
  it('6e. Kitchen lists its own orders with full details', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/kitchens/me/orders')
      .set('Authorization', 'Bearer kitchen-test-token')
      .expect(200);

    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThanOrEqual(1);

    const order = res.body.find((o: any) => o.id === orderId);
    expect(order).toBeTruthy();
    expect(order.status).toBe('completed');
    expect(order.fulfillment).toBe('pickup');
    expect(order.foodTotalPaise).toBe(15000);
    expect(order.platformFeePaise).toBe(500);
    expect(order.grandTotalPaise).toBe(15500);
    expect(order.etaMinutes).toBe(25);
    // Seller-facing responses must NOT expose the handover code (proof-of-pickup).
    expect(order.handoverCode).toBeUndefined();
    expect(order.items).toHaveLength(1);
    expect(order.items[0].itemName).toBe('Hyderabadi Biryani');
    expect(order.items[0].preferences).toBeDefined();
    expect(order.payment).toBeTruthy();
  });

  it('6f. Kitchen can filter orders by status', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/kitchens/me/orders?status=completed')
      .set('Authorization', 'Bearer kitchen-test-token')
      .expect(200);

    expect(res.body.length).toBeGreaterThanOrEqual(1);
    expect(res.body.every((o: any) => o.status === 'completed')).toBe(true);

    // The lifecycle order (5h) should not be among received orders
    const received = await request(app.getHttpServer())
      .get('/api/kitchens/me/orders?status=received')
      .set('Authorization', 'Bearer kitchen-test-token')
      .expect(200);

    const lifecycleOrderInReceived = received.body.find((o: any) => o.id === orderId);
    expect(lifecycleOrderInReceived).toBeUndefined();
  });

  it('6g. Another kitchen CANNOT see this kitchen\'s orders', async () => {
    // Sign up a second kitchen
    await request(app.getHttpServer())
      .post('/api/kitchens/signup')
      .set('Authorization', 'Bearer kitchen2-test-token')
      .field('kitchenName', 'Other Kitchen')
      .field('zoneId', ZONE_ID)
      .attach('kitchenPhotos', Buffer.from('fake-image'), 'kitchen.jpg')
      .attach('selfPhoto', Buffer.from('fake-image'), 'self.jpg')
      .expect(201);

    // Second kitchen's order list must be empty
    const res = await request(app.getHttpServer())
      .get('/api/kitchens/me/orders')
      .set('Authorization', 'Bearer kitchen2-test-token')
      .expect(200);

    expect(res.body).toHaveLength(0);
  });

  // =====================================================================
  // Step 7 — Assert order status history
  // =====================================================================
  it('7. order_status_history logged every transition', async () => {
    const history = await prisma.orderStatusHistory.findMany({
      where: { orderId },
      orderBy: { changedAt: 'asc' },
    });

    expect(history).toHaveLength(4);
    expect(history.map((h) => h.status)).toEqual([
      'received',
      'preparing',
      'ready',
      'completed',
    ]);
  });
});
