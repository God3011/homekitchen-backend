import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';

/// Push notifications, shared by both apps.
///
/// The backend sends **DATA-only** FCM messages (no `notification` key) so
/// budget Android OEMs don't drop them — which means Android won't auto-display
/// anything. We render each message ourselves with a local notification, both in
/// the foreground and (via the app's background handler) when the app is
/// backgrounded or killed.
///
/// Everything here is app-agnostic; the per-app parts (channel identity, the
/// wording of each event, the deviceInfo tag) live in [PushConfig]. The
/// `@pragma('vm:entry-point')` background handler must stay in the app — it runs
/// in a fresh isolate that cannot see state set by `main()`.

/// The per-app half of push: channel identity, how loud to be, and how to word
/// a payload.
///
/// **Changing [importance], [sound], [audioAttributesUsage] or [vibrationPattern]
/// on a shipped channel does nothing** — Android freezes those the first time a
/// channel id is created and only the user can change them afterwards. Bump
/// [channelId] whenever you change any of them, or existing installs keep the
/// old behaviour forever.
class PushConfig {
  const PushConfig({
    required this.channelId,
    required this.channelName,
    required this.channelDescription,
    required this.deviceInfo,
    required this.text,
    this.importance = Importance.high,
    this.sound,
    this.audioAttributesUsage = AudioAttributesUsage.notification,
    this.vibrationPattern,
  });

  final String channelId;
  final String channelName;
  final String channelDescription;

  /// Tag stored alongside the token server-side, e.g. 'customer-android'.
  final String deviceInfo;

  /// Turn a DATA-only payload into the (title, body) this app should show.
  final ({String title, String body}) Function(Map<String, dynamic> data) text;

  /// [Importance.max] gets a heads-up banner; [Importance.high] is a quieter
  /// tray entry.
  final Importance importance;

  /// Custom sound, e.g. `RawResourceAndroidNotificationSound('order_alert')`
  /// backed by `android/app/src/main/res/raw/order_alert.wav`. Null = system
  /// default notification tone.
  final AndroidNotificationSound? sound;

  /// Which volume stream the sound plays on. [AudioAttributesUsage.alarm] plays
  /// at alarm volume, so it still cuts through when the ringer is turned down —
  /// the difference between a seller hearing an order and missing it.
  final AudioAttributesUsage audioAttributesUsage;

  /// Vibration as alternating off/on millisecond pairs.
  final Int64List? vibrationPattern;

  AndroidNotificationChannel get channel => AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: importance,
        playSound: true,
        sound: sound,
        enableVibration: true,
        vibrationPattern: vibrationPattern,
        audioAttributesUsage: audioAttributesUsage,
      );

  AndroidNotificationDetails get details => AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: importance,
        priority: Priority.high,
        playSound: true,
        sound: sound,
        enableVibration: true,
        vibrationPattern: vibrationPattern,
        audioAttributesUsage: audioAttributesUsage,
      );
}

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

Future<void> _initLocal(PushConfig config) async {
  const init = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await _local.initialize(init);
  await _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(config.channel);
}

/// Render one message as a local notification. Call from the app's background
/// handler (after `Firebase.initializeApp()`) — it re-inits the plugin, which a
/// fresh background isolate needs.
Future<void> showPush(PushConfig config, RemoteMessage message) async {
  await _initLocal(config);
  final t = config.text(message.data);
  await _local.show(
    message.hashCode,
    t.title,
    t.body,
    NotificationDetails(android: config.details),
  );
}

/// Call once from `main()` after `Firebase.initializeApp()`. [backgroundHandler]
/// must be the app's own top-level `@pragma('vm:entry-point')` function.
Future<void> initPush(
  PushConfig config,
  BackgroundMessageHandler backgroundHandler,
) async {
  await _initLocal(config);
  FirebaseMessaging.onBackgroundMessage(backgroundHandler);
  await FirebaseMessaging.instance.requestPermission();
  await _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  FirebaseMessaging.onMessage.listen((m) => showPush(config, m));
}

/// Register this device's FCM token with the backend. Call once the user is
/// signed in (the ApiClient auto-attaches their Firebase bearer token).
Future<void> registerDeviceToken(ApiClient api, PushConfig config) async {
  Future<void> send(String token) async {
    try {
      await api.post('/notifications/device-tokens',
          body: {'fcmToken': token, 'deviceInfo': config.deviceInfo});
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
