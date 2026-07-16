import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared/shared.dart';

/// Push notifications for the customer app.
///
/// The backend sends **DATA-only** FCM messages (no `notification` key) so
/// budget Android OEMs don't drop them — which means Android won't auto-display
/// anything. We render each message ourselves with a local notification, both
/// in the foreground and (via the background handler) when backgrounded/killed.

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'homely_customer_orders',
  'Order updates',
  description: 'Updates as your order is prepared and ready for pickup',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

const _androidDetails = AndroidNotificationDetails(
  'homely_customer_orders',
  'Order updates',
  channelDescription: 'Updates as your order is prepared and ready for pickup',
  importance: Importance.high,
  priority: Priority.high,
);

/// Turn a DATA-only payload into a (title, body) pair for the customer.
({String title, String body}) _text(Map<String, dynamic> data) {
  switch (data['event']) {
    case 'preparing':
      return (title: 'Order accepted 👩‍🍳', body: 'Your food is being prepared.');
    case 'ready':
      return (
        title: 'Ready for pickup! 🍱',
        body: 'Your order is ready — head over to collect it.'
      );
    case 'completed':
      return (title: 'Enjoy your meal! 🙏', body: 'Order completed. Bon appétit!');
    case 'rejected':
      return (
        title: 'Order declined',
        body: 'The kitchen could not take your order. You will not be charged.'
      );
    case 'expired':
      return (
        title: 'Order cancelled',
        body: 'Payment was not completed in time, so your order was cancelled.'
      );
    default:
      return (title: 'Order update', body: 'Tap to view your order.');
  }
}

Future<void> _show(RemoteMessage message) async {
  final t = _text(message.data);
  await _local.show(
    message.hashCode,
    t.title,
    t.body,
    const NotificationDetails(android: _androidDetails),
  );
}

/// Background / terminated handler — MUST be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _initLocal();
  await _show(message);
}

Future<void> _initLocal() async {
  const init = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await _local.initialize(init);
  await _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);
}

/// Call once from `main()` after `Firebase.initializeApp()`.
Future<void> initPush() async {
  await _initLocal();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission();
  await _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  FirebaseMessaging.onMessage.listen(_show);
}

/// Register this device's FCM token with the backend. Call once the user is
/// signed in (the ApiClient auto-attaches their Firebase bearer token).
Future<void> registerDeviceToken(ApiClient api) async {
  Future<void> send(String token) async {
    try {
      await api.post('/notifications/device-tokens',
          body: {'fcmToken': token, 'deviceInfo': 'customer-android'});
      debugPrint('FCM token registered');
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) await send(token);
  FirebaseMessaging.instance.onTokenRefresh.listen(send);
}

/// Remove this device's token (call on logout, while still authenticated).
Future<void> unregisterDeviceToken(ApiClient api) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    try {
      await api.post('/notifications/device-tokens/remove',
          body: {'fcmToken': token});
    } catch (_) {/* best-effort */}
  }
  await FirebaseMessaging.instance.deleteToken();
}
