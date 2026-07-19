import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../models/discovery_result.dart';
import '../models/menu.dart';
import 'addresses_provider.dart';
import 'api_provider.dart';
import 'location_provider.dart';

/// The point discovery searches around: the active saved location when the
/// customer has one, else the device GPS (with a Gachibowli fallback). Switching
/// the active address recomputes this, which re-runs [discoveryProvider].
final discoveryCenterProvider =
    FutureProvider.autoDispose<({double lat, double lng})>((ref) async {
  final active = ref.watch(activeAddressProvider);
  if (active != null) return (lat: active.lat, lng: active.lng);
  return ref.watch(discoveryLocationProvider.future);
});

/// Radius-based discovery near the active location. Returns the
/// `{ state, kitchens }` envelope so the screen can render the three states
/// (serviceable / dormant_only / none_in_radius).
final discoveryProvider =
    FutureProvider.autoDispose<DiscoveryResult>((ref) async {
  final api = ref.watch(apiClientProvider);
  final loc = await ref.watch(discoveryCenterProvider.future);

  final data = await api.get('/kitchens', queryParams: {
    'lat': loc.lat.toString(),
    'lng': loc.lng.toString(),
  });
  final result =
      DiscoveryResult.fromJson(data, lat: loc.lat, lng: loc.lng);

  trackEvent('kitchen_list_viewed', {
    'zone_id': '',
    'kitchen_count_shown': result.kitchens.length,
  });
  return result;
});

/// Full kitchen detail (header, hours, ratings, rating summary).
final kitchenDetailProvider =
    FutureProvider.autoDispose.family<Kitchen, String>((ref, kitchenId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/kitchens/$kitchenId');
  return Kitchen.fromJson(data);
});

/// A kitchen's menu (grouped into sections, with today's plate counts).
final kitchenMenuProvider = FutureProvider.autoDispose
    .family<KitchenMenu, String>((ref, kitchenId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/menu/kitchens/$kitchenId');
  return KitchenMenu.fromJson(data);
});
