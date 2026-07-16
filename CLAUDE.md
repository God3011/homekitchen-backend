# Homely Food Marketplace — Backend (project brief for AI coding agents)

You are working on the **shared backend** for a two-sided home-food marketplace
in Hyderabad (Gachibowli zone). Home cooks sell homely lunch/dinner; customers
order pickup. One backend serves the Seller app, the Customer app, and Admin.

**Read this file fully before writing code. `src/orders/` is the reference
pattern — match its structure and conventions in every new module.**

---

## Stack (do not swap without being asked)
- **NestJS + TypeScript** (backend), **Prisma 6** (ORM), **PostgreSQL 16**.
- **Firebase** for Auth (phone/OTP) and FCM (push) only — NOT for data.
- **Razorpay** for payments (UPI-first, no card data stored).
- **Cloudflare R2** for images. **Docker** for local + deploy. **DO Bangalore** in prod.
- **Firebase Analytics** for event tracking in the apps (NOT AppsFlyer — see ANALYTICS.md).

---

## Hard rules (these are decisions, not suggestions)
- **Prisma 6, never 7.** Prisma 7 drops `url` from the datasource block and breaks
  this schema. Always run `npx prisma@6 ...` or the package.json scripts, never bare `npx prisma`.
- **Money is stored in paise (integers).** Never floats for currency. ₹5 = 500.
- **Pickup-first for v1.** The `delivery` fulfillment type + delivery-fee fields
  exist in the schema for forward-compat, but do NOT build delivery flows for v1.
- **Enforce the product rules in code, not just docs:** ₹200 per-item price cap
  (enforced in `MenuService.createItem()` and `MenuService.updateItem()`), flat ₹5
  platform fee, ₹50/day seller fee. These live in the `PlatformConfig` row. There
  is NO cart/order total cap — customers can order as many plates as are available.
- **Plate-based stock management:** Items auto-disable (`isAvailable = false`) when
  `platesRemaining` hits zero. Kitchen gets low-stock push alerts when plates drop
  to or below `PlatformConfig.lowStockThreshold` (default: 3). Rejecting or
  cancelling an order restores plates and re-enables availability.
- **Snapshot menu name + price onto order items** at order time (already done in
  OrdersService) so later menu edits never rewrite order history.
- **Guarded state transitions only.** An order can't jump states illegally
  (see `OrdersService.transition`). Reuse that helper. `reject()` and `cancel()`
  bypass `transition()` because they also restore plate counts in a `$transaction`.
- **Never commit `.env`.** Always commit `prisma/migrations/`.

---

## Architecture overview

```
src/
├── app.module.ts            # Root module — imports all feature modules
├── main.ts                  # Bootstrap: global prefix /api, ValidationPipe
├── prisma/                  # Global PrismaService (DB access for all modules)
├── auth/                    # Firebase token guard + role-based access
├── kitchens/                # Seller signup, profile, docs, hours, daily status
├── menu/                    # Categories, dishes, preferences, daily availability
├── orders/                  # Order placement, lifecycle transitions, cancellation
├── payments/                # Razorpay order creation, webhook verification
├── notifications/           # FCM push (high-priority DATA), WhatsApp fallback
└── health/                  # GET /api/health liveness check
```

### Module dependency graph

```
AppModule
├── ConfigModule.forRoot({ isGlobal: true })
├── PrismaModule (global — injected everywhere)
├── AuthModule
│   └── Provides: FirebaseService, FirebaseAuthGuard (APP_GUARD), RolesGuard (APP_GUARD)
├── KitchensModule
│   └── imports: AuthModule (for FirebaseService during signup)
├── MenuModule
├── OrdersModule
│   └── imports: NotificationsModule (for low-stock & sold-out alerts)
├── PaymentsModule
├── NotificationsModule (exports NotificationsService)
└── HealthController (registered directly in AppModule)
```

---

## Authentication & authorization

All routes are protected by two global guards (registered as `APP_GUARD`):

1. **FirebaseAuthGuard** (`src/auth/firebase-auth.guard.ts`):
   - Checks `Authorization: Bearer <firebaseIdToken>` header.
   - Verifies token via `FirebaseService.verifyIdToken()`.
   - Resolves user from DB by Firebase UID. One UID may exist in more than one
     actor table (a person can be both buyer and seller); the app sends an
     `X-Client-App: customer|kitchen|admin` header so the guard resolves to the
     matching identity. Without the header it falls back to customer → kitchen → admin.
   - Attaches `{ role, userId, firebaseUid }` to `request.user`.
   - Routes marked `@Public()` skip verification entirely.

2. **RolesGuard** (`src/auth/roles.guard.ts`):
   - If route has `@Roles('kitchen')` → only kitchen users pass; others get 403.
   - If no `@Roles()` decorator → any authenticated user is allowed.

**Decorators** (`src/auth/decorators.ts`):
- `@Public()` — skip auth (used on signup, health, webhooks).
- `@CurrentUser()` — parameter decorator injecting the authenticated user.
- `@Roles('kitchen' | 'customer' | 'admin')` — role enforcement.

---

## Database schema (Prisma)

Single source of truth: `prisma/schema.prisma` (20+ models, one `public` schema).

### Key models

| Model | Purpose |
|-------|---------|
| `PlatformConfig` | Single-row config: `platformFeePaise` (500), `sellerDailyFeePaise` (5000), `itemPriceCapPaise` (20000), `lowStockThreshold` (3) |
| `Zone` | Geographic zones (Gachibowli etc.), customers + kitchens belong to zones |
| `Customer` | Customer App users, linked by `firebaseUid` |
| `Kitchen` | Seller App users, status lifecycle: `pending_review → verified → suspended` |
| `KitchenDocument` | FSSAI / ID proof uploads for verification |
| `KitchenHours` | Per-day operating hours (day 0–6, open/close time strings) |
| `KitchenDailyStatus` | "Cooking Today" toggle per kitchen per date |
| `MenuCategory` | Groups of dishes (e.g., "South Indian", "Breads") |
| `MenuItem` | Individual dishes with price in paise, active flag |
| `MenuItemPreference` | Which preference toggles a dish offers (spice levels, no-onion, etc.) |
| `MenuDailyAvailability` | Per-item per-day plate counts (`platesTotal`, `platesRemaining`, `isAvailable`) |
| `Order` | Core order: customer, kitchen, fulfillment type, money fields, status, handover code |
| `OrderItem` | Snapshotted line items (name + price frozen at order time) |
| `OrderItemPreference` | Customer's chosen preferences per order item |
| `OrderStatusHistory` | Audit trail: every status transition is logged |
| `Payment` | Razorpay integration: order ID, payment ID, status (`created → captured`) |
| `Rating` | Post-order star rating + comment |
| `Payout` | Kitchen payout records |
| `Favorite` | Customer ↔ Kitchen favorites |
| `AuditLog` | Generic audit trail |
| `DeviceToken` | FCM tokens per customer/kitchen for push notifications |
| `Admin` | Admin panel users |

### Enums

- `OrderStatus`: `received → preparing → ready → customer_en_route → customer_arrived → completed` + `rejected`, `cancelled`, `out_for_delivery` (v2)
- `FulfillmentType`: `pickup`, `delivery` (v2 only)
- `KitchenStatus`: `pending_review`, `verified`, `suspended`
- `PreferenceType`: `less_spicy`, `normal_spicy`, `extra_spicy`, `no_onion`, `no_garlic`, `less_oil`, `extra_rice`
- `PaymentStatus`: `created`, `authorized`, `captured`, `failed`, `refunded`
- `DocType`: `fssai`, `id_proof`

---

## Business rules enforced in code

### Per-item price cap (MenuService)
- No single dish can cost more than `PlatformConfig.itemPriceCapPaise` (₹200 = 20000 paise).
- Enforced in `MenuService.createItem()` and `MenuService.updateItem()`.
- There is **no cart/order total cap**. A customer can order 10 × ₹200 = ₹2000 if plates are available.

### Plate-based stock management (OrdersService)
- Each menu item has daily availability via `MenuDailyAvailability` (plates total / remaining).
- Order placement atomically decrements `platesRemaining` using `updateMany` with
  `isAvailable: true` and `platesRemaining >= quantity` in the WHERE clause — this
  ensures race-safe concurrent ordering.
- **After order placement:**
  - If `platesRemaining === 0` → auto-set `isAvailable = false` + send "SOLD OUT" push to kitchen.
  - If `0 < platesRemaining <= lowStockThreshold` → send "low stock" push to kitchen (item stays available).
- **On reject/cancel:** plates are restored (`increment: quantity`) and `isAvailable` is re-set to `true`.

### Order lifecycle
```
received ──→ preparing (seller accepts, sets ETA)
         └─→ rejected (seller declines — plates restored)
         └─→ cancelled (customer cancels — plates restored)

preparing ──→ ready (seller marks ready)

ready ──→ completed (handover OTP confirmed)
      └─→ completed (also allowed from customer_arrived)

customer_en_route ──→ customer_arrived (pickup loop, v2)
```

### Pricing formula
```
foodTotal       = Σ (item.pricePaise × quantity)     — no cap on total
platformFee     = PlatformConfig.platformFeePaise     — ₹5 (500 paise)
deliveryFee     = Σ item.deliveryFeePaise             — ₹0 for pickup (v1)
grandTotal      = foodTotal + platformFee + deliveryFee
```

---

## API endpoints

Global prefix: `/api`. All endpoints require Firebase Bearer token unless marked `@Public()`.

### Health
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/health` | Public | Liveness + DB check |

### Auth / Kitchens
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/kitchens/signup` | Public (token in header) | Kitchen signup, creates kitchen from Firebase token |
| GET | `/api/kitchens/me` | Kitchen | Get own profile |
| PATCH | `/api/kitchens/me` | Kitchen | Update own profile |
| POST | `/api/kitchens/me/documents` | Kitchen | Upload verification doc |
| GET | `/api/kitchens/me/documents` | Kitchen | List own documents |
| PUT | `/api/kitchens/me/hours` | Kitchen | Set operating hours |
| GET | `/api/kitchens/me/hours` | Kitchen | Get own hours |
| POST | `/api/kitchens/me/daily-status` | Kitchen | Set "Cooking Today" toggle |
| GET | `/api/kitchens/me/daily-status?date=` | Kitchen | Get daily status |
| GET | `/api/kitchens/me/orders` | Kitchen | List own incoming orders (optional `?status=` filter) |
| PATCH | `/api/kitchens/:id/verify` | Admin | Verify a kitchen |
| PATCH | `/api/kitchens/:id/suspend` | Admin | Suspend a kitchen |
| GET | `/api/kitchens` | Authenticated | Customer-facing: list kitchens (optional `?zoneId=`) |
| GET | `/api/kitchens/:id` | Authenticated | Customer-facing: kitchen detail |

### Menu
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/menu/categories` | Kitchen | Create category |
| GET | `/api/menu/categories` | Kitchen | List own categories |
| PATCH | `/api/menu/categories/:id` | Kitchen | Update category |
| DELETE | `/api/menu/categories/:id` | Kitchen | Delete category (orphans items) |
| POST | `/api/menu/items` | Kitchen | Create dish (enforces ₹200 per-item cap) |
| GET | `/api/menu/items` | Kitchen | List own items |
| PATCH | `/api/menu/items/:id` | Kitchen | Update dish (enforces price cap if price changed) |
| DELETE | `/api/menu/items/:id` | Kitchen | Deactivate dish |
| PUT | `/api/menu/items/:id/availability` | Kitchen | Set daily plate count |
| PUT | `/api/menu/items/:id/preferences` | Kitchen | Set preference toggles |
| GET | `/api/menu/kitchens/:kitchenId` | Authenticated | Customer-facing: full menu for a kitchen |

### Orders
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/orders` | Authenticated | Place order (decrements plates, triggers stock alerts) |
| GET | `/api/orders/:id` | Authenticated | Get order detail |
| PATCH | `/api/orders/:id/accept` | Authenticated | Seller accepts, sets ETA (body: `{ etaMinutes }`) |
| PATCH | `/api/orders/:id/reject` | Authenticated | Seller rejects (restores plates, body: `{ reason? }`) |
| PATCH | `/api/orders/:id/cancel` | Authenticated | Cancel order (restores plates, body: `{ reason? }`) |
| PATCH | `/api/orders/:id/ready` | Authenticated | Seller marks ready |
| PATCH | `/api/orders/:id/handover` | Authenticated | Confirm handover (body: `{ code }` — 4-digit OTP) |

### Payments
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/payments/:orderId/razorpay-order` | Customer | Create Razorpay order for checkout |
| POST | `/api/payments/verify` | Customer | Client-side payment verification |
| POST | `/api/payments/webhook` | Public | Razorpay server-to-server webhook (HMAC verified) |

### Notifications
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/notifications/device-tokens` | Authenticated | Register FCM token |
| POST | `/api/notifications/device-tokens/remove` | Public | Remove FCM token |

---

## Notification system

`NotificationsService` (`src/notifications/notifications.service.ts`):

- **`sendPush(ownerType, ownerId, data)`** — sends FCM high-priority DATA-only messages
  to all registered devices. DATA-only (no `notification` key) so the app's foreground
  service can handle display on budget Android OEMs. Auto-cleans stale FCM tokens.
- **`sendWhatsApp(phone, message)`** — stub for WhatsApp Business API fallback.
- **`notifyOrderEvent(...)`** — routes order events to the right recipient:
  - Seller gets: `received`, `customer_en_route`, `customer_arrived`, `cancelled`
  - Customer gets: `preparing`, `ready`, `completed`, `rejected`
  - WhatsApp fallback fires on `ready` (most critical pickup alert).

Stock alerts (fired from `OrdersService.create()`):
- `type: 'stock_alert'` — sent to kitchen when plates hit zero or drop below threshold.

---

## Conventions
- Validate all input with class-validator DTOs (see `src/orders/dto`).
- One Postgres schema (`public`); modules are logical, not separate DB schemas.
- Wrap multi-write operations in `prisma.$transaction`.
- Health check lives at `GET /api/health`; global prefix is `/api`.
- Ownership checks: services verify the authenticated user owns the resource
  (e.g., `ownsItem()`, `ownsCategory()` in MenuService).

---

## Build order (do these in sequence — all are implemented)
1. **Auth** — Firebase ID-token guard; verify token, attach the customer OR kitchen
   to the request. Add a `device_tokens` table (FCM tokens per customer/kitchen).
2. **Kitchens** — signup, profile, doc upload, verification status, "Cooking Today"
   toggle (`KitchenDailyStatus`), daily plate counts (`MenuDailyAvailability`).
3. **Menu** — categories, dishes, per-dish preference toggles (`MenuItemPreference`),
   prices, availability.
4. **Payments** — create Razorpay order, verify webhook signature, mark
   `Payment.captured`. Never store card data.
5. **Notifications** — FCM high-priority DATA messages for order alerts, a
   FOREGROUND-SERVICE-friendly payload, plus a WhatsApp "order ready" fallback.
   (Reliability on budget Android OEMs is the #1 risk — treat missed order alerts
   as a bug, not an edge case.)

---

## Testing

E2E tests live in `test/e2e-flow.spec.ts`. They:
- Create a temporary `homekitchen_test` database, push schema, seed data.
- Mock `FirebaseService` (no emulator needed) and `NotificationsService` (no live FCM).
- Walk through the full lifecycle: signup → verify → menu setup → order → accept → ready → handover.
- Test business rules: per-item price cap, no cart cap, plate exhaustion, concurrent
  ordering race conditions, reject/cancel plate restoration, low-stock and sold-out alerts.

```bash
npm run test:e2e    # runs all 25 tests
```

---

## What to verify before saying a task is done
- `npx prisma@6 validate` passes.
- `npm run build` compiles with no TS errors.
- `npm run test:e2e` passes (if DB is available).
- New endpoints have DTO validation and guarded auth.
