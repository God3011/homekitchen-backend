# Homely Food Marketplace — Backend

Shared NestJS backend for a two-sided home-food marketplace in Hyderabad.
Home cooks list homely meals, customers order for pickup. One backend serves
the **Seller App** (Flutter), the **Customer App**, and the **Admin panel**.

**Stack:** NestJS + TypeScript, Prisma 6, PostgreSQL 16, Firebase Auth/FCM, Razorpay.

> For the full AI-agent project brief with hard rules and conventions, see [`CLAUDE.md`](./CLAUDE.md).

---

## Project structure

```
prisma/
  schema.prisma              # 20+ models — single source of truth
  seed.ts                    # PlatformConfig defaults + starter zone
  migrations/                # Committed migration history

src/
  app.module.ts              # Root module — imports all feature modules
  main.ts                    # Bootstrap: global /api prefix, ValidationPipe
  prisma/                    # Global PrismaService
  auth/                      # Firebase token guard + @Roles() + @Public()
  kitchens/                  # Signup, profile, docs, hours, daily status, orders
  menu/                      # Categories, dishes, preferences, daily availability
  orders/                    # Order placement, lifecycle, cancel/reject with plate restore
  payments/                  # Razorpay order creation + webhook verification
  notifications/             # FCM push (DATA-only, high-priority) + WhatsApp stub
  health/                    # GET /api/health liveness check

test/
  e2e-flow.spec.ts           # 25 E2E tests covering full lifecycle + business rules

docker-compose.yml           # db + backend + nginx
Dockerfile                   # Multi-stage; runs migrate deploy on boot
```

---

## Run locally

```bash
cp .env.example .env               # adjust DATABASE_URL if needed
npm install
npx prisma@6 migrate dev           # apply migrations
npm run db:seed                     # seed PlatformConfig + Zone
npm run start:dev                   # http://localhost:3000/api/health
```

You need a local Postgres, or just `docker compose up db -d` for one.

## Run with Docker

```bash
docker compose up --build           # http://localhost/api/health
```

## Run tests

```bash
docker compose up db -d             # needs Postgres running
npm run test:e2e                    # 25 tests, creates temp DB automatically
```

---

## Implemented modules

All modules below are fully built and tested.

### Auth (`src/auth/`)
- Global `FirebaseAuthGuard` verifies `Authorization: Bearer <token>` on every route.
- Resolves user from DB (customer → kitchen → admin) by Firebase UID.
- `@Public()` decorator skips auth. `@Roles('kitchen')` enforces role.
- `@CurrentUser()` parameter decorator injects authenticated user.

### Kitchens (`src/kitchens/`)
- **Signup** (`POST /api/kitchens/signup`) — public, creates kitchen from Firebase token.
- **Profile** — `GET/PATCH /api/kitchens/me` for the seller's own profile.
- **Documents** — upload/list FSSAI and ID proof docs.
- **Hours** — `PUT/GET /api/kitchens/me/hours` (per day-of-week).
- **Daily status** — "Cooking Today" toggle per date.
- **Orders** — `GET /api/kitchens/me/orders` with optional `?status=` filter.
- **Admin actions** — `PATCH /api/kitchens/:id/verify` and `/suspend`.
- **Discovery** — `GET /api/kitchens` (customer-facing, optional `?zoneId=`).

### Menu (`src/menu/`)
- Menu items (CRUD with per-item ₹200 price cap enforcement).
- Per-item preference toggles (spice level, no-onion, etc.).
- Daily menu / plate counts (`GET` + `PUT /api/menu/daily`) — the only write path
  for availability.
- Customer-facing menu: `GET /api/menu/kitchens/:kitchenId`.

### Orders (`src/orders/`)
- **Placement** (`POST /api/orders`) — validates kitchen readiness (verified, cooking today,
  within hours), snapshots prices, atomically decrements plates. No cart total cap.
- **Stock alerts** — after placement, if plates hit zero → auto-disables item + sends
  "SOLD OUT" push. If plates <= threshold (default 3) → sends low-stock push.
- **Accept** (`PATCH :id/accept`) — seller sets prep ETA.
- **Reject** (`PATCH :id/reject`) — restores plates, re-enables availability.
- **Cancel** (`PATCH :id/cancel`) — same plate restoration as reject.
- **Ready** (`PATCH :id/ready`) — seller marks food ready.
- **Handover** (`PATCH :id/handover`) — verifies 4-digit pickup OTP → completes order.
- State machine: `received → preparing → ready → completed`, plus `rejected`/`cancelled`.

### Payments (`src/payments/`)
- `POST /api/payments/:orderId/razorpay-order` — creates Razorpay order.
- `POST /api/payments/verify` — client-side signature verification.
- `POST /api/payments/webhook` — server-to-server Razorpay webhook (HMAC verified, `@Public()`).

### Notifications (`src/notifications/`)
- FCM high-priority DATA-only messages (for foreground-service on budget Android).
- Auto-cleans stale FCM tokens.
- Order event dispatcher routes alerts to seller/customer based on event type.
- WhatsApp fallback for "order ready" (stub, pending provider integration).
- Stock alerts: "SOLD OUT" and "low stock" pushes to kitchen on order placement.

---

## Business rules

| Rule | Value | Where enforced |
|------|-------|----------------|
| Per-item price cap | ₹200 (20000 paise) | `MenuService.createItem()` / `updateItem()` |
| Cart/order total cap | **None** | Removed — order size limited only by plate availability |
| Platform fee | ₹5 (500 paise) per order | `OrdersService.create()` from `PlatformConfig` |
| Seller daily fee | ₹50 (5000 paise) | `PlatformConfig.sellerDailyFeePaise` |
| Low-stock threshold | 3 plates | `PlatformConfig.lowStockThreshold` — triggers push alert |
| Sold-out auto-disable | `platesRemaining === 0` | `OrdersService.create()` sets `isAvailable = false` |
| Plate restoration | On reject/cancel | `OrdersService.reject()` / `cancel()` increments plates + re-enables |
| Money format | Integer paise | All `*Paise` fields. ₹150 = 15000 |
| Price snapshot | At order time | `OrderItem.itemName` + `unitPricePaise` frozen from menu |

---

## Order lifecycle

```
received ──→ preparing  (seller accepts + sets ETA)
         ├─→ rejected   (seller declines — plates restored)
         └─→ cancelled   (customer cancels — plates restored)

preparing ──→ ready      (seller marks ready)

ready ──→ completed      (handover OTP confirmed)

customer_en_route → customer_arrived  (pickup loop — schema-ready, not wired yet)
```

---

## Database

`prisma/schema.prisma` — 20+ models in one `public` schema. Key config table:

```
PlatformConfig (single row, id=1)
├── platformFeePaise     = 500   (₹5)
├── sellerDailyFeePaise  = 5000  (₹50)
├── itemPriceCapPaise    = 20000 (₹200)
├── lowStockThreshold    = 3
└── currency             = "INR"
```

**Important:** Always use `npx prisma@6` (never bare `npx prisma`) — Prisma 7 breaks this schema.

---

## Environment variables

See `.env.example`. Key vars:
- `DATABASE_URL` — Postgres connection string.
- `FIREBASE_SERVICE_ACCOUNT` — path to Firebase Admin SDK JSON.
- `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` — Razorpay API credentials.
- `RAZORPAY_WEBHOOK_SECRET` — HMAC secret for webhook verification.
