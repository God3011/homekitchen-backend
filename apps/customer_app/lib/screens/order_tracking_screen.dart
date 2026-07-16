import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared/shared.dart';

import '../providers/api_provider.dart';
import '../providers/orders_provider.dart';
import '../widgets/rate_sheet.dart';
import '../widgets/status_badge.dart';

/// Live pickup screen: status, ETA, the handover code the customer reads aloud
/// at pickup, a map to the kitchen, cancel-before-accept, and post-pickup rate.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Poll while the order is in flight — FCM also nudges, this is the backstop.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.invalidate(orderProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  bool _isTerminal(OrderStatus s) =>
      s == OrderStatus.completed ||
      s == OrderStatus.rejected ||
      s == OrderStatus.cancelled;

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text(
            'You can only cancel before the kitchen accepts. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep order')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel order')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .patch('/orders/${widget.orderId}/cancel', body: {'reason': 'customer'});
      ref.invalidate(orderProvider(widget.orderId));
      ref.invalidate(ordersHistoryProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not cancel — the kitchen may have accepted.')));
        ref.invalidate(orderProvider(widget.orderId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(widget.orderId));

    // Stop polling once terminal.
    orderAsync.whenData((o) {
      if (_isTerminal(o.status)) {
        _poll?.cancel();
        _poll = null;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Your order')),
      body: orderAsync.when(
        data: (order) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(orderProvider(widget.orderId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(order.kitchen?.kitchenName ?? 'Kitchen',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 16),
              _StatusMessage(order: order),
              const SizedBox(height: 16),
              if (order.status == OrderStatus.ready ||
                  order.status == OrderStatus.preparing ||
                  order.status == OrderStatus.received)
                _HandoverCard(order: order),
              const SizedBox(height: 16),
              _ItemsCard(order: order),
              const SizedBox(height: 16),
              if (order.kitchen?.lat != null && order.kitchen?.lng != null)
                _KitchenMap(kitchen: order.kitchen!),
              const SizedBox(height: 16),
              if (order.status == OrderStatus.received)
                OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel order'),
                ),
              if (order.status == OrderStatus.completed &&
                  order.rating == null)
                ElevatedButton.icon(
                  onPressed: () => showRateSheet(
                    context,
                    ref,
                    orderId: order.id,
                    kitchenId: order.kitchenId,
                  ),
                  icon: const Icon(Icons.star),
                  label: const Text('Rate this order'),
                ),
              if (order.rating != null)
                Row(
                  children: [
                    const Text('You rated: '),
                    for (var i = 0; i < order.rating!.stars; i++)
                      Icon(Icons.star, size: 18, color: Colors.amber.shade700),
                  ],
                ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load your order.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(orderProvider(widget.orderId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    String msg;
    switch (order.status) {
      case OrderStatus.received:
        msg = 'Waiting for the kitchen to accept your order.';
        break;
      case OrderStatus.preparing:
        msg = order.etaMinutes != null
            ? 'Your food is being prepared. Ready in about ${order.etaMinutes} min.'
            : 'Your food is being prepared.';
        break;
      case OrderStatus.ready:
        msg = 'Your order is ready! Head to the kitchen and share your pickup code.';
        break;
      case OrderStatus.completed:
        msg = 'Picked up. Enjoy your meal!';
        break;
      case OrderStatus.rejected:
        msg = order.rejectReason != null && order.rejectReason!.isNotEmpty
            ? 'The kitchen declined: ${order.rejectReason}. You will not be charged.'
            : 'The kitchen could not take your order. You will not be charged.';
        break;
      case OrderStatus.cancelled:
        msg = 'This order was cancelled.';
        break;
      default:
        msg = '';
    }
    if (msg.isEmpty) return const SizedBox.shrink();
    return Text(msg, style: Theme.of(context).textTheme.bodyLarge);
  }
}

class _HandoverCard extends StatelessWidget {
  const _HandoverCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final code = order.handoverCode;
    if (code == null || code.isEmpty) return const SizedBox.shrink();
    final ready = order.status == OrderStatus.ready;
    return Card(
      color: ready
          ? Colors.green.withValues(alpha: 0.08)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Your pickup code',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              code,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
            ),
            const SizedBox(height: 4),
            const Text('Share this with the cook at pickup',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${item.quantity} × ${item.itemName}'),
                    ),
                    Text(formatPaise(item.unitPricePaise * item.quantity)),
                  ],
                ),
              ),
            const Divider(),
            _row(context, 'Food total', order.foodTotalPaise),
            _row(context, 'Platform fee', order.platformFeePaise),
            _row(context, 'Total', order.grandTotalPaise, bold: true),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payments_outlined, size: 16),
                const SizedBox(width: 6),
                Text('Payment: ${order.payment?.status ?? 'pending'}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, int paise,
      {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatPaise(paise), style: style),
        ],
      ),
    );
  }
}

class _KitchenMap extends StatelessWidget {
  const _KitchenMap({required this.kitchen});
  final Kitchen kitchen;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(kitchen.lat!, kitchen.lng!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pickup location',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        if (kitchen.addressLine != null && kitchen.addressLine!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(kitchen.addressLine!,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        SizedBox(
          height: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(initialCenter: point, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.homely.customer_app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_pin,
                        color: Colors.red, size: 40),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
