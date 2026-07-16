import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'api_provider.dart';

final authServiceProvider = Provider<AuthService>((_) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// Fetches the customer profile for the signed-in user.
/// Returns null if no profile exists (404) so the auth gate routes to the
/// profile-setup (signup) screen.
final customerProfileProvider = FutureProvider<Customer?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get('/customers/me');
    return Customer.fromJson(data);
  } catch (_) {
    return null;
  }
});
