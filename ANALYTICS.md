# Analytics & Event Tracking — v1 Decision

## Decision
**v1 uses Firebase Analytics for all in-app event tracking. AppsFlyer (MMP) is
deferred until we run paid user-acquisition campaigns.**

Rationale: the PRDs' event-tracking requirement is about **funnel drop-off,
retention, and where users get stuck** — which Firebase Analytics covers fully,
for free. The only thing an MMP (AppsFlyer) adds is **install-source
attribution** (which ad drove an install), which is meaningless until we spend on
ads. AppsFlyer's free tier caps at 12,000 lifetime installs, then $0.07/conversion
— no reason to pay for attribution infra we can't use yet.

## Rule for the app teams
Wrap every event in ONE helper so switching/adding a provider later is a
one-function change, not a 27-call-site rewrite:

```dart
// analytics.dart — the ONLY place a provider is named
void trackEvent(String name, Map<String, Object> params) {
  FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
  // later: also call AppsFlyer here when paid acquisition starts
}
```

Call `trackEvent(...)` at each trigger point below. The backend already supplies
every parameter (IDs, prices, timestamps). `app_install` + attribution are
auto-captured by the SDK; no code needed.

## Customer App events
| Event | Fires when | Key params (all backend-supplied) |
|---|---|---|
| sign_up_completed | OTP registration done | user_id, signup_method |
| zone_detected | service zone set | zone_id, lat, lng |
| kitchen_list_viewed | nearby list shown | zone_id, kitchen_count_shown |
| kitchen_profile_viewed | kitchen page opened | kitchen_id, zone_id |
| search_performed | dish/kitchen search | query, zone_id, result_count |
| item_added_to_cart | item added | item_id, kitchen_id, price, preferences |
| checkout_started | checkout opened | cart_value, item_count, kitchen_id |
| fulfillment_type_selected | _deferred — no fulfillment selector until delivery ships in v2 (v1 is pickup-only)_ | order_type, delivery_fee |
| order_placed | order placed (purchase — fires only AFTER payment is confirmed) | order_id, value, currency, kitchen_id, order_type |
| call_kitchen_tapped | Call Kitchen tapped | order_id, kitchen_id |
| order_completed | picked up | order_id, completion_time, order_type |
| rating_submitted | rating given | order_id, kitchen_id, rating_value |
| reorder_tapped | re-order from history | original_order_id, kitchen_id |
| push_notification_opened | notif opened | notification_type, campaign_id |
| address_added | saved location added | set_active |
| address_switched | active saved location changed | address_id |

## Seller App events
| Event | Fires when | Key params |
|---|---|---|
| seller_signup_started | onboarding begins | language_selected, referral_source |
| seller_signup_completed | profile submitted | kitchen_id, zone_id |
| kitchen_verified | admin approves | kitchen_id, verification_date |
| menu_item_added | dish created | kitchen_id, item_id, price |
| today_toggle_set | Cooking Today set | kitchen_id, status, date |
| order_received | order alert delivered | order_id, kitchen_id |
| order_accepted / order_rejected | seller responds | order_id, response_time_seconds, reason |
| order_marked_ready | marked ready | order_id, prep_time_seconds |
| order_handover_confirmed | code confirmed | order_id |
| call_customer_tapped | Call Customer tapped | order_id, kitchen_id |
| earnings_viewed | earnings opened | kitchen_id, period_viewed |
| help_call_tapped | help/call tapped | kitchen_id, screen_name |

`response_time_seconds` = acceptedAt − placedAt; `prep_time_seconds` =
readyAt − acceptedAt. Both are derivable server-side from Order timestamps +
OrderStatusHistory, so the funnel survives a missed client event.

## When to add AppsFlyer
When we start paid campaigns. Sign up for the free Zero tier (12k installs is
plenty to validate first campaigns), add its call inside `trackEvent`, done.
