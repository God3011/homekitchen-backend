import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../models/customer_address.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

/// The customer's saved locations, default (active) first. App-wide (not
/// autoDispose) so the home header and discovery share one cached source.
///
/// Rebuilds whenever the signed-in Firebase user changes. Without this, the
/// provider (kept alive permanently by [activeAddressProvider]) would keep
/// serving the previous account's addresses after a logout/login — and
/// switching/editing one of those would 404 on the backend, since it belongs to
/// a different customer.
final addressesProvider = FutureProvider<List<CustomerAddress>>((ref) async {
  ref.watch(authStateProvider.select((a) => a.valueOrNull?.uid));
  final api = ref.watch(apiClientProvider);
  final data = await api.getList('/customers/me/addresses');
  return data
      .map((e) => CustomerAddress.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// The active (default) saved location, or null if none is set yet. This is the
/// app-wide "where am I searching" state that the home header and discovery both
/// read.
final activeAddressProvider = Provider<CustomerAddress?>((ref) {
  final list = ref.watch(addressesProvider).valueOrNull ?? const [];
  for (final a in list) {
    if (a.isDefault) return a;
  }
  return list.isEmpty ? null : list.first;
});

/// Create a saved location. First address (or isActive=true) becomes the active
/// search centre server-side. Refreshes the list and re-runs discovery.
Future<CustomerAddress> addAddress(
  WidgetRef ref, {
  required String label,
  String? addressLine,
  required double lat,
  required double lng,
  bool isActive = false,
}) async {
  final api = ref.read(apiClientProvider);
  final data = await api.post('/customers/me/addresses', body: {
    'label': label,
    if (addressLine != null && addressLine.isNotEmpty) 'addressLine': addressLine,
    'lat': lat,
    'lng': lng,
    'isDefault': isActive,
  });
  ref.invalidate(addressesProvider);
  trackEvent('address_added', {'set_active': isActive});
  return CustomerAddress.fromJson(data);
}

/// Edit an existing saved location's label / display line / coordinates.
Future<void> updateAddress(
  WidgetRef ref,
  String id, {
  String? label,
  String? addressLine,
  double? lat,
  double? lng,
}) async {
  final api = ref.read(apiClientProvider);
  await api.patch('/customers/me/addresses/$id', body: {
    'label': ?label,
    'addressLine': ?addressLine,
    'lat': ?lat,
    'lng': ?lng,
  });
  ref.invalidate(addressesProvider);
}

/// Make a saved location the active search centre; re-runs discovery.
Future<void> setActiveAddress(WidgetRef ref, String id) async {
  final api = ref.read(apiClientProvider);
  await api.patch('/customers/me/addresses/$id/default');
  ref.invalidate(addressesProvider);
  trackEvent('address_switched', {'address_id': id});
}

/// Delete a saved location. If it was active, the backend promotes another so a
/// customer with addresses always keeps exactly one active.
Future<void> deleteAddress(WidgetRef ref, String id) async {
  final api = ref.read(apiClientProvider);
  await api.delete('/customers/me/addresses/$id');
  ref.invalidate(addressesProvider);
}
