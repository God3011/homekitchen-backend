import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'kitchen_provider.dart';

/// The kitchen's own menu items.
final menuItemsProvider =
    FutureProvider.autoDispose<List<MenuItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.getList('/menu/items');
  return data
      .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
      .toList();
});
