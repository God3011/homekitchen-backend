# Homely — Internal Analytics & Admin Dashboard (v1) — Planning Document

> **Status:** proposal for founder review. **Nothing is built.** This document
> captures the plan only; the build is gated on explicit approval.
>
> **Audience:** the two founders (internal, not customer-facing).
> **Principle:** simple > pretty; read-only; **our Postgres is the source of
> truth for business metrics**; **Firebase Analytics stays the tool for in-app
> behavioral funnels** — we do not rebuild what the Firebase console shows.
>
> **Proposed location:** `apps/admin_web/` (matches the `apps/` monorepo
> convention; `packages/shared` is Flutter/Dart, so the web app is a separate
> JS toolchain).

---

## 0. Money & data conventions (apply everywhere)
- **All money stays `int` paise** across API responses. `₹` formatting happens
  **only** in the web display layer (a `formatPaise()` helper mirroring the
  Flutter one). No floats, ever.
- **Timestamps** are `timestamptz`. The backend already standardizes "service
  day" as **UTC-midnight of the local (IST) day** (`OrdersService.serviceDate()`).
  All day-bucketing in analytics must use the **same** rule or IST trends will be
  off by a day.
- **The "order unit" matters.** Since the pay-first changes, three order
  populations are distinct and must never be conflated:
  - **Placed** = any `orders` row (intent; includes abandoned/failed-payment).
  - **Paid** = `payments.status = 'captured'` (the real transaction; the kitchen
    only ever sees these).
  - **Completed** = `orders.status = 'completed'` (picked up).
  - **Rule:** GMV, revenue, and kitchen operational metrics use **paid** orders.
    Funnel/conversion uses placed→paid.

---

## 1. Questions the dashboard answers

### TODAY (live ops — poll every 30–60s)
| Question | Tables / fields | Query shape |
|---|---|---|
| How many **paid orders** today? | `orders.placed_at` (today) ⋈ `payments.status='captured'` | count of today's orders with captured payment |
| **GMV today** | `orders.grand_total_paise` for paid orders today | sum |
| Which **kitchens are cooking today**? | `kitchen_daily_status(service_date=today, is_cooking=true)` ⋈ `kitchens` | join; count + list |
| **Paid orders stuck in `received` > X min** (kitchen ignoring a paid order — the real ops alert) | `orders.status='received'` ⋈ `payments.status='captured'`, `placed_at < now()-X` | filter + list (kitchen, customer, age, ₹) |
| **Failed / abandoned payments today** | `payments.status='failed'`, or `status='created'` on a `cancelled` order today | count + list by reason |
| Orders by hour today | `orders.placed_at` (paid) | count group by `date_trunc('hour')` |

### GROWTH (on-load, date-range)
| Question | Tables / fields | Query shape |
|---|---|---|
| Orders/day trend | `orders.placed_at` (paid) | count group by day over range |
| New customers / week | `customers.created_at` | count group by week |
| New kitchens / week | `kitchens.created_at` (and `verified_at`) | count group by week |
| Repeat-order rate | `orders.customer_id` (paid) | customers with ≥2 paid ÷ customers with ≥1 paid |
| Zone health | `zones` ⋈ `orders.zone_id`, `kitchens.zone_id`, `customers.home_zone_id` | per-zone: paid orders, active kitchens, customers |

### KITCHEN HEALTH (per-kitchen, date-range)
| Question | Tables / fields | Query shape |
|---|---|---|
| Orders (paid) | `orders` ⋈ `payments` | count by kitchen |
| Acceptance rate | `orders.accepted_at` vs `status='rejected'` (paid only) | accepted ÷ (accepted+rejected) |
| Avg **response time** | `orders.accepted_at − placed_at` (accepted, paid) | avg (+ p50/p90 if raw SQL) |
| Avg **prep time** | `orders.ready_at − accepted_at` (reached ready) | avg |
| Rating avg / count | `ratings.stars` by `kitchen_id` | avg, count |
| **Plate sell-through %** | `menu_daily_availability(plates_total, plates_remaining)` ⋈ item→kitchen | Σ(total−remaining) ÷ Σ(total) |
| Days cooked | `kitchen_daily_status(is_cooking=true)` | count of service_dates in range |

*Note:* `order_status_history(order_id, status, changed_at)` is the audit trail;
response/prep timers can also be reconstructed from it, but the denormalized
`orders.accepted_at/ready_at/completed_at` columns are simpler and are what we'll
use (history is the fallback/verification source).

### MONEY (date-range)
| Question | Tables / fields | Query shape |
|---|---|---|
| **GMV** | `orders.grand_total_paise` (paid) | sum |
| **Platform-fee revenue** | `orders.platform_fee_paise` (paid) | sum (Homely's take from customers) |
| **Seller ₹50/day fees owed / collected** | `kitchen_daily_status(is_cooking=true, fee_charged)` × `platform_config.seller_daily_fee_paise` | count cooking-days; split by `fee_charged` |
| **Payout ledger / outstanding per kitchen** | `orders.food_total_paise` (paid/completed) − seller fees − `payouts.amount_paise` | per-kitchen reconciliation |

### QUALITY (date-range)
| Question | Tables / fields | Query shape |
|---|---|---|
| Rejection reasons | `orders.reject_reason` where `status='rejected'` | count group by reason |
| Cancellations (customer vs auto-expire) | `orders.cancel_reason` where `status='cancelled'` | group by reason (`'Payment not completed in time'` / `'Payment failed'` = system) |
| **Handover failures** | ⚠️ **not currently measurable** (wrong-code attempts return 400 but aren't persisted) | *proxy:* orders with `ready_at` set, `completed_at` null, aged out |

---

## 2. Metric definitions (lock these so numbers are consistent)
- **Paid order** — `payments.status = 'captured'`. The unit for GMV & kitchen metrics.
- **Active kitchen** — two definitions, both reported: **cooking today**
  (`kitchen_daily_status` today, `is_cooking=true`) for live ops; **active this
  week** (≥1 `is_cooking=true` day in trailing 7 days) for growth. *(Open #4.)*
- **New customer/kitchen** — `created_at` within the window.
- **Repeat-order rate** — `count(customers with ≥2 paid orders) ÷ count(customers
  with ≥1 paid order)`, lifetime by default (window variant later). Placed-but-
  never-paid customers are excluded.
- **Acceptance rate** — of **paid** orders the kitchen actually had to decide on
  (reached `received` and ended `preparing`-or-later, or `rejected`), the share
  **accepted** = `accepted ÷ (accepted + rejected)`. Customer-cancelled-after-paid
  orders are **excluded from the denominator** (the kitchen never got to decide).
- **Response time** — `accepted_at − placed_at`, seconds, over accepted paid
  orders. *Caveat:* under pay-first the kitchen sees the order at **capture**, not
  placement; we don't store a `captured_at`, so this slightly overstates kitchen
  latency by the (usually seconds) pay window. *(Open #6.)*
- **Prep time** — `ready_at − accepted_at`, seconds, over orders that reached `ready`.
- **Sell-through %** — per kitchen/day: `Σ(plates_total − plates_remaining) ÷
  Σ(plates_total)`, only rows with `plates_total > 0` (guard divide-by-zero →
  null, render "—").
- **Days cooked** — count of `kitchen_daily_status` rows with `is_cooking=true` in range.
- **GMV** — `Σ grand_total_paise` of paid orders (total customer-paid value). Food
  subtotal (`food_total_paise`) and fees reported separately. *(Open #10.)*
- **Stuck order** — a **paid** order in `received` older than **X = 15 min**
  (aligns with the unpaid-order TTL). *(Open #7.)*
- **Seller fee owed** — `(cooking-days where fee_charged=false) ×
  seller_daily_fee_paise`. **Collected** = `fee_charged=true`.

---

## 3. API plan — `AnalyticsModule` (read-only, admin-guarded)

**Auth (explicit):** every endpoint carries `@Roles('admin')`. The web app
authenticates with **Firebase email/password** (Firebase Web SDK) → obtains the
ID token → sends `Authorization: Bearer <token>` → the **existing**
`FirebaseAuthGuard` resolves it to an `Admin` row by `firebase_uid` → `RolesGuard`
enforces `admin`. **No new auth code.** Prereq: the two founders each need (a) a
Firebase account and (b) a seeded `Admin` row (`firebase_uid`, `email`, `name`).
*(There is no admin-signup endpoint today; seed via a script — the one manual
step.)* All endpoints live under **`/api/admin/analytics/...`** and return
**paise ints**. Common params: `from`, `to` (default last 7/30 days), optional
`zoneId`, `kitchenId`.

| Endpoint | Purpose | Approach | Index flag |
|---|---|---|---|
| `GET /overview` | TODAY tiles: paid orders, GMV, kitchens cooking, stuck count, failed-payment count | Prisma `aggregate`/`count` + a couple raw counts | `orders(status, placed_at)`, `kitchen_daily_status(service_date, is_cooking)` |
| `GET /orders?…&status&paid&page&pageSize` | Orders explorer (paginated table) | Prisma `findMany` + joins (`customer`, `kitchen`, `payment`), `count` for total | `orders(placed_at)`, `orders(zone_id, placed_at)` if zone-filtered |
| `GET /orders/timeseries?interval=day` | Orders/day trend | **raw SQL** `date_trunc` group-by | `orders(placed_at)` |
| `GET /growth` | new customers/kitchens per week, repeat rate | raw SQL (weekly buckets; repeat-rate = 2 counts) | `customers(created_at)`, `kitchens(created_at)` (optional at v1 scale) |
| `GET /kitchens?…` | Per-kitchen health table | **raw SQL** (acceptance/response/prep/sell-through need conditional aggregates + join to availability) | `orders(kitchen_id, status)` ✅; `ratings(kitchen_id)` ✅ |
| `GET /kitchens/:id?…` | Kitchen drill-down (metrics + time series + recent orders + ratings) | reuse `/kitchens` agg scoped to one id + `findMany` recents | (as above) |
| `GET /money?…` | GMV, platform-fee revenue, seller fees owed/collected, payout summary | raw SQL sums + `kitchen_daily_status` counts + `payouts` sums | `payouts(kitchen_id, payout_date)` ✅ |
| `GET /quality?…` | rejection & cancellation reason breakdowns, stuck-in-ready proxy | Prisma `groupBy(reject_reason)` / `groupBy(cancel_reason)` | none |
| `GET /zones?…` | zone health table | raw SQL grouped by `zone_id` | `orders(zone_id, placed_at)` |
| `GET /orders/:id` | admin order detail incl. handover code + status history (support) | Prisma `findUnique` + `statusHistory` | `order_status_history(order_id, changed_at)` ✅ |

**Indexes to add (migration in Slice 0):**
1. `orders(status, placed_at)` — stuck-order + global date-range scans (today only
   have `(kitchen_id,status)` and `(customer_id,placed_at)`).
2. `payments(status)` (or `(status, created_at)`) — failed-payment counts and
   paid-filter joins.
3. `kitchen_daily_status(service_date, is_cooking)` — "who's cooking today / days
   cooked across kitchens" (PK leads with `kitchen_id`, so `service_date` alone
   isn't well-served).
4. `orders(zone_id, placed_at)` — zone trends (only if zone filtering proves slow).
5. *(defer)* `customers(created_at)`, `kitchens(created_at)` — growth buckets;
   trivial at Gachibowli scale, add when tables grow.

**Schema addition to consider (not required v1):** `payments.captured_at
timestamptz` → precise response-time/payment-latency *(Open #6)*. And, if handover
failures matter, an `audit_logs` write on wrong-code entry (the table already
exists) *(Open #9)*.

---

## 4. Screen-by-screen plan
Charts limited to **counts, day-bucketed trends (bar/line), and tables**. No
pies/gauges/vanity.

### Page 1 — Overview (Today) · *live-ish, poll 60s*
**Purpose:** the "is everything OK right now" glance.
```
┌ Homely Admin ───────────────── [Overview] Orders Kitchens Money Growth  (founder ▾)┐
│ [ Paid orders: 12 ] [ GMV: ₹4,320 ] [ Cooking now: 4 ] [ Stuck >15m: 2 ⚠ ] [ Failed pay: 3 ] │
│                                                                                     │
│ ⚠ Orders needing attention (paid, unaccepted >15m)                                  │
│  ┌ time  customer   kitchen   ₹      age ┐                                          │
│  │ 12:31 Sha        Meals     ₹255   18m │ → row click → order drawer               │
│  └───────────────────────────────────────┘                                          │
│  Orders by hour today  ▁▂▅▇▆▃  (bar)                                                 │
└─────────────────────────────────────────────────────────────────────────────────────┘
```
Widgets → endpoints: tiles ← `/overview`; attention table ←
`/orders?status=received&paid=true&stuckMin=15`; hourly bar ←
`/orders/timeseries?interval=hour&day=today`. **Empty:** "No orders yet today."
**Error:** inline "Couldn't load — retry." Stuck tile turns **red** when >0.

### Page 2 — Orders explorer · *on-load + manual refresh*
**Purpose:** find/inspect any order. **Filters:** date range, zone, kitchen, order
status, payment status.
```
[from]-[to] [zone ▾] [kitchen ▾] [status ▾] [payment ▾]      [Refresh] [Export CSV]
Orders/day  ▁▃▅▇▆▅▃ (bar over range)                           ← /orders/timeseries
┌ placed  customer  kitchen  items  ₹total  pay      status     resp  prep ┐
│ ...                                                                       │  ← /orders (paged)
└───────────────────────────────────────────────────────────────────────── ┘   pagination
```
Row → **order drawer** (`/orders/:id`: items, timestamps, status history, payment,
handover code for support). **Empty:** "No orders match." One **basic CSV export**
of the current filter.

### Page 3 — Kitchens table (+ drill-down) · *on-load*
**Purpose:** rank kitchen health. **Filters:** date range, zone. Sortable columns.
```
[from]-[to] [zone ▾]
┌ kitchen  zone  status  daysCooked  paid  accept%  avgResp  avgPrep  ★avg  sell% ┐
│ Meals    Gach  verified   5         37    92%      2m10s    18m      4.6   78%  │ → row → detail
└──────────────────────────────────────────────────────────────────────────────── ┘
```
← `/kitchens`. **Kitchen detail** (`/kitchens/:id`): header (name/status/zone/★),
stat tiles (same metrics), orders/day trend, recent orders, recent ratings,
this-kitchen rejection/cancellation breakdown. *(v1 vs v1.1 — Open #3.)*
**Empty:** "No kitchens in this zone/range."

### Page 4 — Money · *on-load*
**Purpose:** revenue & what's owed. **Filters:** date range, zone.
```
[ GMV ₹… ] [ Platform-fee revenue ₹… ] [ Seller fees billable ₹… (collected ₹… / owed ₹…) ]
GMV/day ▁▃▅▇ (bar)
Seller-fee & payout ledger
┌ kitchen  cookDays  feesBillable  feesCollected  earned(food)  paidOut  outstanding ┐
│ ...                                                                                 │  ← /money
└───────────────────────────────────────────────────────────────────────────────────┘
```
**Note:** read-only **ledger view**, not an automated payout engine.
**Empty:** "No paid orders in range."

### Page 5 — Growth (+ Quality section) · *on-load*
**Purpose:** trajectory + failure hygiene. Small page; folds Quality in.
```
[ New customers/wk ▁▃▅ ] [ New kitchens/wk ▁▂▃ ] [ Repeat-order rate: 34% ]     ← /growth
Zone health ┌ zone  paidOrders  activeKitchens  customers ┐                      ← /zones
Quality:  Rejection reasons (table)   Cancellation reasons (table: customer vs system)  ← /quality
```

---

## 5. What we deliberately DON'T build in v1
| Not building | Why | Trigger to build later |
|---|---|---|
| Cohort **retention curves** | Firebase already does app-side retention/DAU/MAU | when we run paid acquisition and need LTV cohorts |
| Configurable **CSV/BI exports** | one basic orders CSV covers support | accounting/investor data requests |
| **Alerting** (email/Slack/push on stuck orders) | v1 is a dashboard you watch; red tiles suffice | order volume too high to watch live |
| **Real-time websockets** | 60s polling is plenty for 2 users | sub-minute ops needs at scale |
| **Automated payouts/settlement** | ledger view + manual bank transfer is fine early | too many kitchens to pay by hand |
| **In-dashboard admin actions** (verify/suspend/refund) | keep v1 read-only to minimize risk; endpoints exist for later | founders want one-click ops *(Open #8)* |
| **Behavioral funnels** (screen views, add-to-cart drop-off) | **Firebase's job** (see §5a) | never here — belongs in Firebase |

### 5a. Firebase vs this dashboard (no overlap)
- **Answer in Firebase Analytics:** in-app **funnel drop-off** (`sign_up_completed
  → kitchen_list_viewed → kitchen_profile_viewed → item_added_to_cart →
  checkout_started → order_placed`), screen engagement, **retention/DAU/MAU**,
  `push_notification_opened` rates, `search_performed` usage, device/OS/app-version
  splits, crash-free rate. These are *behavioral* and Firebase captures them free.
- **Answer here (Postgres):** everything from **`order_placed` onward** — money
  (GMV, fees, payouts), fulfillment (acceptance/response/prep from timestamps),
  plate sell-through, order lifecycle/outcomes, rejection/cancellation reasons,
  live stuck orders, per-kitchen & per-zone business health. Firebase has **none**
  of the authoritative money/timestamp/plate data, nor the paid-vs-placed truth.
- **The one overlap** (`order_placed` count) is deliberately split: **Firebase
  owns the funnel up to it; we own everything after it.**

---

## 6. Build sequence (each slice shippable)
| Slice | Contents | Effort | Riskiest part |
|---|---|---|---|
| **0. Backend foundation** | `AnalyticsModule` scaffold + admin guard reuse + **`/overview`, `/orders`, `/orders/timeseries`** + the index migration + e2e tests seeding known data and asserting exact numbers | **M** | **metric-definition correctness in raw SQL** (paid-filter, IST day-bucketing); test against seeded fixtures |
| **1. Web shell + auth** | Vite React app in `apps/admin_web`, Firebase email/password login, auth gate, `ApiClient` w/ Bearer, `formatPaise`, Overview page wired | **S–M** | Firebase admin login + seeded `Admin` rows; CORS from web origin |
| **2. Orders explorer** | table + filters + trend + drawer + basic CSV | **S** | pagination + filter-index performance |
| **3. Kitchens** | `/kitchens` table; **kitchen detail** (if v1) | **M** | acceptance/response/prep/sell-through SQL; payout-adjacent definitions |
| **4. Money + Growth + Quality** | `/money`, `/growth`, `/zones`, `/quality` pages | **M** | **payout ledger reconciliation** (earned − fees − paid); repeat-rate sign-off |

Ship 0→1 first (a live Overview is immediately useful); 2–4 in any order after.

---

## 7. Open decisions for review
1. **Stack** — **DECIDED (provisional): Vite React SPA + Nest `AnalyticsModule`,
   reusing Firebase admin auth** ("do a for now"). Alternative held in reserve:
   Metabase on a read-only Postgres role (zero build/maintenance, self-serve SQL,
   but separate login + a separate service, can't reuse Firebase auth). Server-
   rendered-from-Nest rejected (Firebase auth is client-side JS → awkward SSR).
2. **Polling frequency (Overview)** — 30s vs 60s. *(rec 60s.)*
3. **Kitchen detail** — v1 or v1.1. *(rec v1.1 — ship the kitchens table first.)*
4. **"Active kitchen" definition** — cooking-today vs cooked-≥1-day-in-7. *(rec
   report both: today for ops, 7-day for growth.)*
5. **Business-metric order unit** — paid vs placed. *(rec paid for GMV/kitchen
   metrics; show placed→paid conversion separately.)*
6. **Response-time precision** — proxy (`accepted_at − placed_at`, no schema
   change) vs add `payments.captured_at`. *(rec proxy in v1.)*
7. **Stuck-order threshold X** — 10/15/20 min. *(rec 15 min — matches the unpaid
   TTL.)*
8. **Read-only admin actions in v1** (verify/suspend kitchen) — endpoints exist.
   *(rec no — keep v1 read-only; revisit v1.1.)*
9. **Handover failures** — not currently logged. Add `audit_logs` write on
   wrong-code entry now, or defer? *(rec defer; use stuck-in-`ready` proxy.)*
10. **GMV definition** — `grand_total` vs `food_total`. *(rec `grand_total` as GMV;
    report food subtotal + fees separately.)*

---

### Build gate
Nothing is built. On approval, **Slice 0** (backend `AnalyticsModule` + indexes +
tests) is the first shippable step. Decisions **#3** (kitchen-detail v1?) and the
recommended defaults for #2/#4–#10 most shape that slice.
