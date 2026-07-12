import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/kitchen_provider.dart';
import '../widgets/status_badge.dart';

/// Provider that fetches a single order by ID.
final orderDetailProvider =
    FutureProvider.autoDispose.family<Order, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/orders/$orderId');
  return Order.fromJson(data);
});

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Detail')),
      body: orderAsync.when(
        data: (order) => _OrderDetailBody(order: order),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  final Order order;
  const _OrderDetailBody({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header: ID + status
        Row(
          children: [
            Text(
              '#${order.id.substring(order.id.length - 8).toUpperCase()}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            StatusBadge(status: order.status),
          ],
        ),
        const SizedBox(height: 4),
        Text('${order.fulfillment.toUpperCase()} order',
            style: Theme.of(context).textTheme.bodySmall),
        if (order.etaMinutes != null) ...[
          const SizedBox(height: 4),
          Text('ETA: ${order.etaMinutes} minutes',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.orange)),
        ],
        const Divider(height: 32),

        // Items
        Text('Items',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...order.items.map((item) => _buildItemRow(context, item)),
        const Divider(height: 32),

        // Totals
        _totalRow(context, 'Food total', order.foodTotalPaise),
        _totalRow(context, 'Platform fee', order.platformFeePaise),
        if (order.deliveryFeePaise > 0)
          _totalRow(context, 'Delivery fee', order.deliveryFeePaise),
        const SizedBox(height: 4),
        _totalRow(context, 'Grand total', order.grandTotalPaise, bold: true),
        const Divider(height: 32),

        // Handover code — only show when ready or later
        if (_showHandoverCode(order.status)) ...[
          Center(
            child: Column(
              children: [
                Text('Handover Code',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.handoverCode,
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Action buttons
        _buildActions(context, ref),
      ],
    );
  }

  Widget _buildItemRow(BuildContext context, OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${item.quantity}x',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName),
                if (item.preferences.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.preferences.map((p) => p.preference).join(', '),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          Text(formatPaise(item.unitPricePaise * item.quantity)),
        ],
      ),
    );
  }

  Widget _totalRow(BuildContext context, String label, int paise,
      {bool bold = false}) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(formatPaise(paise), style: style)],
      ),
    );
  }

  bool _showHandoverCode(OrderStatus s) =>
      s == OrderStatus.ready ||
      s == OrderStatus.customer_en_route ||
      s == OrderStatus.customer_arrived;

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    switch (order.status) {
      case OrderStatus.received:
        return ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Accept Order'),
          onPressed: () => _acceptOrder(context, ref),
        );
      case OrderStatus.preparing:
        return ElevatedButton.icon(
          icon: const Icon(Icons.done_all),
          label: const Text('Mark Ready'),
          onPressed: () => _markReady(context, ref),
        );
      case OrderStatus.ready:
      case OrderStatus.customer_en_route:
      case OrderStatus.customer_arrived:
        return ElevatedButton.icon(
          icon: const Icon(Icons.handshake),
          label: const Text('Confirm Handover'),
          onPressed: () => _confirmHandover(context, ref),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _acceptOrder(BuildContext context, WidgetRef ref) async {
    final eta = await showDialog<int>(
      context: context,
      builder: (ctx) => _EtaPickerDialog(),
    );
    if (eta == null) return;

    final api = ref.read(apiClientProvider);
    await api.patch('/orders/${order.id}/accept', body: {'etaMinutes': eta});

    final responseTime =
        DateTime.now().difference(order.placedAt).inSeconds;
    trackEvent('order_accepted', {
      'order_id': order.id,
      'response_time_seconds': responseTime,
    });

    ref.invalidate(orderDetailProvider(order.id));
    ref.invalidate(ordersProvider(null));
  }

  Future<void> _markReady(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiClientProvider);
    await api.patch('/orders/${order.id}/ready');

    final prepTime = order.acceptedAt != null
        ? DateTime.now().difference(order.acceptedAt!).inSeconds
        : 0;
    trackEvent('order_marked_ready', {
      'order_id': order.id,
      'prep_time_seconds': prepTime,
    });

    ref.invalidate(orderDetailProvider(order.id));
    ref.invalidate(ordersProvider(null));
  }

  Future<void> _confirmHandover(BuildContext context, WidgetRef ref) async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => _HandoverCodeDialog(),
    );
    if (code == null) return;

    final api = ref.read(apiClientProvider);
    try {
      await api.patch('/orders/${order.id}/handover', body: {'code': code});

      trackEvent('order_handover_confirmed', {'order_id': order.id});

      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(ordersProvider(null));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrong code. Try again.')),
        );
      }
    }
  }
}

class _EtaPickerDialog extends StatefulWidget {
  @override
  State<_EtaPickerDialog> createState() => _EtaPickerDialogState();
}

class _EtaPickerDialogState extends State<_EtaPickerDialog> {
  int _eta = 20;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Prep Time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_eta minutes',
              style: Theme.of(context).textTheme.headlineMedium),
          Slider(
            value: _eta.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            label: '$_eta min',
            onChanged: (v) => setState(() => _eta = v.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _eta),
          child: const Text('Accept'),
        ),
      ],
    );
  }
}

class _HandoverCodeDialog extends StatefulWidget {
  @override
  State<_HandoverCodeDialog> createState() => _HandoverCodeDialogState();
}

class _HandoverCodeDialogState extends State<_HandoverCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Handover Code'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        maxLength: 4,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
        decoration: const InputDecoration(
          hintText: '1234',
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final code = _controller.text.trim();
            if (code.length == 4) Navigator.pop(context, code);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
