import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared/shared.dart';

/// Push notifications for the seller app.
///
/// The backend sends **DATA-only** FCM messages (no `notification` key) so
/// budget Android OEMs don't drop them — which means Android won't auto-display
/// anything. We therefore render each message ourselves with a local
/// notification, both in the foreground and (via the background handler) when
/// the app is backgrounded or killed.

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'homely_orders',
  'Order & stock alerts',
  description: 'New orders and low-stock / sold-out alerts',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

const _androidDetails = AndroidNotificationDetails(
  'homely_orders',
  'Order & stock alerts',
  channelDescription: 'New orders and low-stock / sold-out alerts',
  importance: Importance.high,
  priority: Priority.high,
);

/// Turn a DATA-only payload into a (title, body) pair.
({String title, String body}) _text(Map<String, dynamic> data) {
  if (data['type'] == 'stock_alert') {
    return (
      title: 'Stock alert',
      body: (data['message'] ?? 'Check your plate counts.').toString(),
    );
  }
  switch (data['event']) {
    case 'received':
      return (title: 'New order! 🎉', body: 'You have a new order — tap to view.');
    case 'cancelled':
      return (title: 'Order cancelled', body: 'A customer cancelled their order.');
    case 'customer_en_route':
      return (title: 'Customer on the way', body: 'They are heading over for pickup.');
    case 'customer_arrived':
      return (title: 'Customer arrived', body: 'The customer is here for pickup.');
    default:
      return (title: 'Order update', body: 'Tap to view your orders.');
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
          body: {'fcmToken': token, 'deviceInfo': 'kitchen-android'});
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
