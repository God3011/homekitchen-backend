# Homely — Customer (Buyer) App: Comprehensive Plan

> Planning document. Companion task list tracks **Phase 0 (backend foundation)**.

## 1. Context & Goal
The seller app is functionally complete, but a marketplace is one-sided without
buyers. This plan delivers the **customer Flutter app** (`apps/customer_app`)
**plus the backend gaps it depends on** — taking Homely from "sellers can list"
to "customers can discover → order → pay → pick up → rate."

**Non-negotiables (CLAUDE.md), enforced server-side already:** pickup-first v1,
money in **paise**, **₹5** flat platform fee, **₹200** per-item cap, **no cart
total cap**, menu **snapshot at order time**, race-safe **plate** decrement,
**handover OTP**, Gachibowli **zone**, Firebase **phone OTP**, **Razorpay UPI**,
**R2** images.

## 2. Reuse vs. Build (grounded in current code)

**✅ Exists — reuse as-is**
| Capability | Endpoint / Asset |
|---|---|
| Browse kitchens in a zone (verified + cooking-today, w/ ratings) | `GET /api/kitchens?zoneId=` |
| Kitchen detail | `GET /api/kitchens/:id` |
| Full menu for a kitchen | `GET /api/menu/kitchens/:kitchenId` |
| Place order (snapshot, plate decrement, ₹5 fee, handover code) | `POST /api/orders` |
| Order detail (returns `handoverCode` to customer) | `GET /api/orders/:id` |
| Cancel order (restores plates) | `PATCH /api/orders/:id/cancel` |
| Razorpay: create order + verify + webhook | `POST /payments/:orderId/razorpay-order`, `/payments/verify`, `/payments/webhook` |
| FCM token register + customer event routing | `POST /notifications/device-tokens`, `NotificationsService.notifyOrderEvent` |
| Zones + geocode (built this session) | `GET /zones`, `/zones/resolve`, `/geocode/reverse`, `/geocode/search` |
| Shared Flutter package | `ApiClient`, `AuthService` (phone OTP), `AppTheme`, models, analytics |

**🔴 Must build — backend gaps**
1. **Customer onboarding** — no `POST /customers/signup`, no `customer.create`
   anywhere. **Blocking**: the `FirebaseAuthGuard` resolves a customer by
   `firebaseUid` but never creates one; `@Roles('customer')` fails until a
   Customer row exists.
2. **Ratings** — `Rating` model exists (one per order, `orderId` unique), no
   submit endpoint.
3. **Favorites** — `Favorite` model exists (composite `[customerId, kitchenId]`),
   zero endpoints.
4. **Authorization holes** — order actions have no role/ownership guard;
   `POST /orders` trusts body `customerId`; `GET /orders/:id` has no ownership
   check.
5. **Discovery refinements** — list returns raw `ratings:[{stars}]` (needs
   server-side average), filters only on cooking-today (not open-now / distance).

## 3. Architecture
- **New app:** `apps/customer_app`, mirroring `apps/kitchen_app` (Riverpod,
  `apiClientProvider`, Firebase auth gate, `--dart-define=API_BASE_URL`).
- **Reuse `packages/shared`** for `ApiClient`, `AuthService`, `AppTheme`, models.
- **Firebase:** second Android app (`com.homely.customer_app`) in the **same**
  project → its own `google-services.json` (gitignored, shared out-of-band).
- **Payments:** add `razorpay_flutter`; backend flow already exists.

## 4. Backend Work — Phase 0 (foundation; unblocks everything)
**4.1 Customers module** (`src/customers/`) — keystone
- `POST /api/customers/signup` (`@Public`, token verified in service like
  `kitchens/signup`): create Customer from Firebase `uid`+`phone_number`,
  `{ name, lat?, lng? }`; resolve `homeZoneId` via `ZonesService.resolveOrCreate`.
- `GET /api/customers/me`, `PATCH /api/customers/me` (`@Roles('customer')`).

**4.2 Authorization hardening** (touches order/payment controllers — regression-
test kitchen app + e2e)
- `POST /orders`: drop body `customerId`; use `@CurrentUser().userId` +
  `@Roles('customer')`.
- `accept/ready/reject/handover`: `@Roles('kitchen')` + verify
  `order.kitchenId === user.userId`.
- `cancel`: `@Roles('customer')` + ownership. `GET /orders/:id`: owning
  customer or its kitchen only.
- *Impact:* update the kitchen app's order calls and `test/e2e-flow.spec.ts`.

**4.3 Ratings** — `POST /api/orders/:id/rating` (`@Roles('customer')`):
`{ stars 1–5, comment? }`; order must be the customer's, `completed`, not already
rated. Kitchen average derived from the `ratings` relation.

**4.4 Favorites** — `POST /api/favorites/:kitchenId`, `DELETE .../:kitchenId`,
`GET /api/favorites` (`@Roles('customer')`).

**4.5 Discovery refinements** — extend `kitchens.list`: `ratingAvg`/`ratingCount`,
optional **open-now** filter (reuse `OrdersService` hours logic), **distance**
from customer lat/lng (haversine in `ZonesService`); default `zoneId` to the
customer's `homeZoneId`.

**4.6 Payments** — code exists; **verify** end-to-end with Razorpay test-mode
keys (create→pay→verify→webhook, `Payment.captured`, idempotency).

**4.7 Customer FCM** — endpoint + event routing exist; wire the app side.

## 5. Shared Package Additions
- New models: `Customer`, `Rating`, `Favorite`, client-side `Cart` (single-
  kitchen; food total + ₹5 fee).
- Extend: `Kitchen` (+`ratingAvg`, `ratingCount`, `distanceM`), `Payment`
  (Razorpay ids/status).

## 6. Customer App — Screens & Flows (phased)
- **P1 Onboarding:** phone→OTP (reuse `AuthService`) → auth gate → profile setup
  (name + home location via the `AddressPicker`) → `POST /customers/signup`.
  Bottom nav: Home · Orders · Favorites · Profile.
- **P2 Discovery:** kitchens in zone (cards: photo, name, rating, signature dish,
  open/closed, distance); search + filters; empty state.
- **P3 Kitchen detail & menu:** header (photos, story, rating, hours, ♥),
  category-grouped menu, dish rows (price, plates-left, prefs), add-to-cart.
- **P4 Cart & checkout:** single-kitchen cart, qty/prefs, totals (food + ₹5),
  place order → `POST /orders`.
- **P5 Payment:** `POST /payments/:orderId/razorpay-order` → `razorpay_flutter`
  UPI → `POST /payments/verify`; failure/retry; webhook backstop.
- **P6 Tracking & pickup:** live status (received→preparing+ETA→ready→completed),
  **handover code shown to customer**, cancel-before-accept, FCM pushes, kitchen
  map (reuse flutter_map).
- **P7 Post-order:** rate+comment, reorder, order history, favorites.

## 7. External Dependencies & Setup
- Firebase phone → **Blaze plan** for real SMS (test numbers free for dev).
- **Razorpay** account + test-mode keys (already scaffolded in `.env`).
- Second Firebase Android app + `google-services.json` for `com.homely.customer_app`.
- FCM Cloud Messaging API (enabled this session). Reuse zones + geocode.

## 8. Sequencing / Milestones
0. **Backend foundation** (customer signup + authz + ratings/favorites) — do the
   authz refactor here and re-green the e2e suite.
1. App shell + onboarding. 2. Discovery + menu. 3. Cart + order placement
   (no payment). 4. Payments (test mode). 5. Tracking + FCM + handover.
6. Post-order. 7. Hardening + customer e2e + on-device pass.

## 9. Testing & Verification
- Extend `test/e2e-flow.spec.ts` (or new `customer-flow.spec.ts`): signup →
  browse → cart → order → mock-payment → track → complete → rate; mock
  `RazorpayService` like `StorageService`/`FirebaseService`.
- On-device: LAN-IP/`--dart-define` loop against a running seller kitchen.
- Razorpay test cards/UPI incl. webhook.

## 10. Risks & Open Decisions
- 🔴 **Authz refactor blast radius** — order-endpoint changes hit the kitchen app
  *and* e2e; update both in the same phase.
- 🔴 **Payment realism** — test-mode, webhook signature/idempotency, and the
  "order created / payment pending or failed" state (do unpaid orders hold
  plates? TTL/auto-cancel?).
- 🟡 One vs. two Firebase apps (recommend one project, two Android apps).
- 🟡 Cart scope (single-kitchen recommended; client-only vs. persisted).
- 🟡 Discovery ranking (distance vs. rating vs. cooking-now).
- 🟡 SMS cost (Blaze before real customers).

## 11. Definition of Done
A customer can: sign up (phone) → set home location → see kitchens cooking near
them → open a menu → build a cart → place & **pay** → **track live** with a
handover code → pick up → **rate** — money in paise, ₹5 fee applied, plates
decremented safely, pushes on every status change. Backend authz closed;
customer e2e green; both apps regression-tested.
