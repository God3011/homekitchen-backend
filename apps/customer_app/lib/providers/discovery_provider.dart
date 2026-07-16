import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../models/menu.dart';
import 'api_provider.dart';

/// Whether the discovery list is filtered to kitchens open right now.
final openNowFilterProvider = StateProvider<bool>((_) => false);

/// Nearby kitchens cooking today. Zone defaults to the customer's home zone
/// server-side; the open-now filter is applied there too.
final kitchensProvider =
    FutureProvider.autoDispose<List<DiscoveryKitchen>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final openNow = ref.watch(openNowFilterProvider);
  final query = <String, String>{};
  if (openNow) query['openNow'] = 'true';

  final data = await api.getList('/kitchens', queryParams: query);
  final kitchens = data
      .map((e) => DiscoveryKitchen.fromJson(e as Map<String, dynamic>))
      .toList();

  trackEvent('kitchen_list_viewed', {
    'zone_id': '',
    'kitchen_count_shown': kitchens.length,
  });
  return kitchens;
});

/// Full kitchen detail (header, hours, ratings, rating summary).
final kitchenDetailProvider =
    FutureProvider.autoDispose.family<Kitchen, String>((ref, kitchenId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/kitchens/$kitchenId');
  return Kitchen.fromJson(data);
});

/// A kitchen's menu (grouped into sections, with today's plate counts).
final kitchenMenuProvider =
    FutureProvider.autoDispose.family<KitchenMenu, String>((ref, kitchenId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/menu/kitchens/$kitchenId');
  return KitchenMenu.fromJson(data);
});
