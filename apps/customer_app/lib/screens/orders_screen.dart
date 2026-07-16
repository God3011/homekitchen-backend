import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/orders_provider.dart';
import '../widgets/status_badge.dart';
import 'kitchen_detail_screen.dart';
import 'order_tracking_screen.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your orders')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ordersHistoryProvider),
        child: ordersAsync.when(
          data: (orders) {
            if (orders.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Center(child: Text('No orders yet.')),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (_, i) => _OrderTile(order: orders[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              const Center(child: Text('Could not load your orders.')),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(ordersHistoryProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends ConsumerWidget {
  const _OrderTile({required this.order});
  final Order order;

  String _date(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReorder = order.status == OrderStatus.completed;
    return Card(
      child: ListTile(
        title: Text(order.kitchen?.kitchenName ?? 'Kitchen'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${order.items.length} item${order.items.length != 1 ? 's' : ''} · ${formatPaise(order.grandTotalPaise)} · ${_date(order.placedAt)}',
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                StatusBadge(status: order.status),
                if (canReorder) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      trackEvent('reorder_tapped', {
                        'original_order_id': order.id,
                        'kitchen_id': order.kitchenId,
                      });
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            KitchenDetailScreen(kitchenId: order.kitchenId),
                      ));
                    },
                    child: const Text('Reorder'),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: order.id),
        )),
      ),
    );
  }
}
