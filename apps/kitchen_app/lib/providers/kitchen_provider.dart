import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../config.dart';

final apiClientProvider = Provider<ApiClient>((_) {
  return ApiClient(baseUrl: apiBaseUrl, appRole: 'kitchen');
});

/// Daily status for today (is the kitchen cooking?).
final dailyStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final today = DateTime.now();
  final dateStr =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  try {
    final data = await api.get('/kitchens/me/daily-status',
        queryParams: {'date': dateStr});
    return data;
  } catch (_) {
    return null;
  }
});

/// Orders for the current kitchen, optionally filtered by status.
final ordersProvider =
    FutureProvider.autoDispose.family<List<Order>, String?>((ref, status) async {
  final api = ref.watch(apiClientProvider);
  final queryParams = <String, String>{};
  if (status != null && status.isNotEmpty) {
    queryParams['status'] = status;
  }
  final data =
      await api.getList('/kitchens/me/orders', queryParams: queryParams);
  return data
      .map((e) => Order.fromJson(e as Map<String, dynamic>))
      .toList();
});
