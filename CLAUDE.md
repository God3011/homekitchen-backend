# Homely Food Marketplace — Backend (project brief for AI coding agents)

You are working on the **shared backend** for a two-sided home-food marketplace
in Hyderabad (Gachibowli zone). Home cooks sell homely lunch/dinner; customers
order pickup. One backend serves the Seller app, the Customer app, and Admin.

**Read this file fully before writing code. `src/orders/` is the reference
pattern — match its structure and conventions in every new module.**

## Stack (do not swap without being asked)
- **NestJS + TypeScript** (backend), **Prisma 6** (ORM), **PostgreSQL 16**.
- **Firebase** for Auth (phone/OTP) and FCM (push) only — NOT for data.
- **Razorpay** for payments (UPI-first, no card data stored).
- **Cloudflare R2** for images. **Docker** for local + deploy. **DO Bangalore** in prod.
- **Firebase Analytics** for event tracking in the apps (NOT AppsFlyer — see ANALYTICS.md).

## Hard rules (these are decisions, not suggestions)
- **Prisma 6, never 7.** Prisma 7 drops `url` from the datasource block and breaks
  this schema. Always run `npx prisma@6 ...` or the package.json scripts, never bare `npx prisma`.
- **Money is stored in paise (integers).** Never floats for currency. ₹5 = 500.
- **Pickup-first for v1.** The `delivery` fulfillment type + delivery-fee fields
  exist in the schema for forward-compat, but do NOT build delivery flows for v1.
- **Enforce the product rules in code, not just docs:** ₹200 food cap, flat ₹5
  platform fee, ₹50/day seller fee. These live in the `PlatformConfig` row.
- **Snapshot menu name + price onto order items** at order time (already done in
  OrdersService) so later menu edits never rewrite order history.
- **Guarded state transitions only.** An order can't jump states illegally
  (see `OrdersService.transition`). Reuse that helper.
- **Never commit `.env`.** Always commit `prisma/migrations/`.

## Build order (do these in sequence)
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

## Conventions
- Validate all input with class-validator DTOs (see `src/orders/dto`).
- One Postgres schema (`public`); modules are logical, not separate DB schemas.
- Wrap multi-write operations in `prisma.$transaction`.
- Health check lives at `GET /api/health`; global prefix is `/api`.

## What to verify before saying a task is done
- `npx prisma@6 validate` passes.
- `npm run build` compiles with no TS errors.
- New endpoints have DTO validation and guarded auth.
