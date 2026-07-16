import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'api_provider.dart';

/// The customer's favorite kitchens (verified only), newest first.
/// Each entry's nested `kitchen` carries a rating summary.
final favoritesProvider =
    FutureProvider.autoDispose<List<DiscoveryKitchen>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.getList('/favorites');
  return data
      .map((e) => DiscoveryKitchen.fromJson(
          (e as Map<String, dynamic>)['kitchen'] as Map<String, dynamic>))
      .toList();
});

/// Just the favorited kitchen ids — handy for heart toggles on other screens.
final favoriteIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final favorites = await ref.watch(favoritesProvider.future);
  return favorites.map((k) => k.id).toSet();
});

/// Add or remove a favorite, then refresh the favorites list.
Future<void> toggleFavorite(
  WidgetRef ref,
  String kitchenId, {
  required bool isFavorite,
}) async {
  final api = ref.read(apiClientProvider);
  if (isFavorite) {
    await api.delete('/favorites/$kitchenId');
  } else {
    await api.post('/favorites/$kitchenId');
  }
  ref.invalidate(favoritesProvider);
}
