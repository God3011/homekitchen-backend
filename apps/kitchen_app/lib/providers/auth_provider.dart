import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'kitchen_provider.dart';

final authServiceProvider = Provider<AuthService>((_) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// Fetches the kitchen profile for the signed-in user.
/// Returns null if no profile exists (404) so the auth gate routes to signup.
final kitchenProfileProvider = FutureProvider<Kitchen?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/kitchens/me');
    return Kitchen.fromJson(data);
  } catch (_) {
    return null;
  }
});
