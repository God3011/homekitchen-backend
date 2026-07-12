import 'package:firebase_analytics/firebase_analytics.dart';

/// Single entry point for all analytics events.
///
/// Every event in both apps MUST go through this helper so that switching
/// or adding an analytics provider later (e.g. AppsFlyer for paid acquisition)
/// is a one-function change, not a 27-call-site rewrite.
///
/// See ANALYTICS.md for the full event catalog.
void trackEvent(String name, Map<String, Object> params) {
  FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
  // Later: also call AppsFlyer here when paid acquisition starts.
}
