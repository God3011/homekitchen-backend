# Homely Food Marketplace — Backend

Shared backend for the Seller App, Customer App, and Admin panel.
**Stack:** NestJS + Prisma + PostgreSQL. One database, one event taxonomy.

## What's here

```
prisma/schema.prisma   # 20 models — the single source of truth (validated)
prisma/seed.ts         # platform config (₹5 / ₹50 / ₹200) + a starter zone
src/
  prisma/              # global PrismaService
  health/              # GET /api/health  → wire to UptimeRobot
  orders/              # ✅ fully implemented reference module
  kitchens/ menu/ auth # 🔜 stubs for the next sprint
docker-compose.yml     # db + backend + nginx
Dockerfile             # multi-stage; runs `migrate deploy` on boot
```

## Run locally (no Docker)

```bash
cp .env.example .env          # adjust DATABASE_URL if needed
npm install
npx prisma migrate dev --name init   # creates the DB + first migration
npm run db:seed
npm run start:dev             # http://localhost:3000/api
```

You need a local Postgres, or just `docker compose up db -d` for one.

## Run the whole stack in Docker

```bash
docker compose up --build     # → http://localhost/api/health
```

## Order lifecycle (implemented)

`received → preparing (seller accepts + sets ETA) → ready → completed (handover OTP)`
plus `rejected`. The `customer_en_route` / `customer_arrived` states exist in the
schema for the "I'm Leaving / I've Arrived" pickup loop — wire them to endpoints
next.

### Try it (after seeding + creating a kitchen/menu)

```bash
# Place an order
curl -X POST localhost:3000/api/orders -H 'Content-Type: application/json' -d '{
  "customerId": "<uuid>", "kitchenId": "<uuid>", "fulfillment": "pickup",
  "items": [{ "menuItemId": "<uuid>", "quantity": 2, "preferences": ["less_spicy"] }]
}'

# Seller accepts with a 20-min ETA
curl -X PATCH localhost:3000/api/orders/<id>/accept -H 'Content-Type: application/json' -d '{"etaMinutes":20}'

# Seller marks ready, customer reads the code at pickup
curl -X PATCH localhost:3000/api/orders/<id>/ready
curl -X PATCH localhost:3000/api/orders/<id>/handover -H 'Content-Type: application/json' -d '{"code":"1234"}'
```

## Next sprint

1. **Auth** — Firebase phone/OTP token guard.
2. **Kitchens** — signup, profile, docs, verification, "Cooking Today" toggle.
3. **Menu** — dishes, per-dish preference toggles, daily plates.
4. **Payments** — Razorpay order creation + webhook → mark `Payment.captured`.
5. **Notifications** — FCM (high-priority data messages + foreground service) and WhatsApp order-ready.
