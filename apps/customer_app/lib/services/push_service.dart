import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared/shared.dart';

/// Customer-app half of push: how each order event is worded. All the plumbing
/// (channel setup, local rendering, token registration) lives in shared.
final customerPush = PushConfig(
  channelId: 'homely_customer_orders',
  channelName: 'Order updates',
  channelDescription: 'Updates as your order is prepared and ready for pickup',
  deviceInfo: 'customer-android',
  text: (data) {
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
  },
);

/// Background / terminated handler — MUST be a top-level function, and must stay
/// in the app: it runs in a fresh isolate with none of `main()`'s state.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await showPush(customerPush, message);
}

/// Call once from `main()` after `Firebase.initializeApp()`.
Future<void> initPushForApp() =>
    initPush(customerPush, firebaseMessagingBackgroundHandler);

/// Register this device's FCM token with the backend.
Future<void> registerDeviceTokenForApp(ApiClient api) =>
    registerDeviceToken(api, customerPush);
