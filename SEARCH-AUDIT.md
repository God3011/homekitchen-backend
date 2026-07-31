# Search — audit findings (pre-refactor)

Snapshot of how customer-facing search worked **before** the server-side
pg_trgm refactor. Kept for context on why the change was made.

## Where matching executed

**100% client-side.** There was no backend search endpoint — the only
customer-facing kitchen query was radius discovery (`GET /api/kitchens`).

| Question | Finding |
|---|---|
| Server or client? | Client. `apps/customer_app/lib/screens/discovery_screen.dart` → `_filter()`. |
| Query shape | Case-insensitive **substring** (`String.contains`) over `kitchenName`, `signatureDish`, `cookName`, and `todayDishNames`. No exact/ILIKE/full-text/trigram, no ranking, no typo tolerance. |
| Radius/serviceable scoped? | Yes — it filtered the already radius-scoped discovery list (`GET /api/kitchens?lat=&lng=`, haversine ≤ `discoveryRadiusM`). It never surfaced kitchens outside radius, but could only match what discovery already returned. |
| Data fetched to filter | Full discovery projection for **every** in-radius kitchen: id, kitchenName, cookName, story, signatureDish, addressLine, lat/lng, rating summary, distance, serviceable/dormant, hasVeg, photo URLs, and `todayDishNames` (every available plated dish name today — added in `kitchens.service.ts` specifically to power the client filter). |

## Problems

1. **Over-fetch / leakage** — shipped cook names, stories, coordinates, and
   every dish name of every in-radius kitchen to the client just to filter in
   memory.
2. **Doesn't scale** past the current small per-radius kitchen count.
3. **Blind spots** — dish search only matched `todayDishNames`, so sold-out or
   not-on-today's-menu dishes were unsearchable.
4. **No typo tolerance, no relevance ranking** — "biriyani" would not match
   "Biryani".

## Resolution

Replaced by `GET /api/search?q=&lat=&lng=` — server-side, radius-scoped
(reuses the exact discovery candidate set + three-state shape), typo-tolerant
via Postgres `pg_trgm` similarity with GIN trigram indexes on
`kitchens.kitchen_name` and `menu_items.name`, ranked by similarity with
distance as a tiebreak. No new infrastructure — stays inside Postgres.
