import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'api_provider.dart';

/// The customer's order history, newest first.
final ordersHistoryProvider =
    FutureProvider.autoDispose<List<Order>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.getList('/customers/me/orders');
  return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
});

/// A single order (detail) — includes the handover code for the owning
/// customer and the joined kitchen.
final orderProvider =
    FutureProvider.autoDispose.family<Order, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/orders/$orderId');
  return Order.fromJson(data);
});
