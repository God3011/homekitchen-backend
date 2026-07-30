import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared/shared.dart';

/// Seller-app half of push: how each order/stock event is worded, and how loudly
/// it announces itself. All the plumbing (channel setup, local rendering, token
/// registration) lives in shared.
///
/// A seller who misses a "new order" ping loses the order, so this channel is
/// deliberately aggressive: a custom chime played on the ALARM stream (audible
/// even with the ringer down), max importance for a heads-up banner, and a
/// double-buzz vibration.
///
/// The channel id carries a version suffix on purpose. Android freezes a
/// channel's sound/importance/vibration the first time that id is created, so
/// changing any of them below requires bumping `_v2` — otherwise every existing
/// install keeps the old, quieter alert.
final kitchenPush = PushConfig(
  channelId: 'homely_orders_v2',
  channelName: 'Order & stock alerts',
  channelDescription: 'New orders and low-stock / sold-out alerts',
  deviceInfo: 'kitchen-android',
  importance: Importance.max,
  sound: const RawResourceAndroidNotificationSound('order_alert'),
  audioAttributesUsage: AudioAttributesUsage.alarm,
  vibrationPattern: Int64List.fromList(const [0, 600, 250, 600]),
  text: (data) {
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
  },
);

/// Background / terminated handler — MUST be a top-level function, and must stay
/// in the app: it runs in a fresh isolate with none of `main()`'s state.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await showPush(kitchenPush, message);
}

/// Call once from `main()` after `Firebase.initializeApp()`.
Future<void> initPushForApp() =>
    initPush(kitchenPush, firebaseMessagingBackgroundHandler);

/// Register this device's FCM token with the backend.
Future<void> registerDeviceTokenForApp(ApiClient api) =>
    registerDeviceToken(api, kitchenPush);
