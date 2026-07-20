import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared/shared.dart';

import '../providers/api_provider.dart';
import '../providers/orders_provider.dart';
import '../widgets/rate_sheet.dart';

/// Live pickup screen: a status hero, a step timeline, the handover code the
/// customer reads aloud at pickup, a map to the kitchen, cancel-before-accept,
/// and a post-pickup rating.
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
              _StatusHero(order: order),
              const SizedBox(height: 16),
              // Pickup code only once the order is actually paid + confirmed.
              if (order.status == OrderStatus.ready ||
                  order.status == OrderStatus.preparing ||
                  (order.status == OrderStatus.received && orderIsPaid(order)))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _HandoverCard(order: order),
                ),
              if (!_isTerminal(order.status) ||
                  order.status == OrderStatus.completed)
                _Timeline(order: order),
              const SizedBox(height: 8),
              _ItemsCard(order: order),
              const SizedBox(height: 16),
              if (order.kitchen?.lat != null && order.kitchen?.lng != null)
                _KitchenMap(kitchen: order.kitchen!),
              const SizedBox(height: 16),
              if (order.status == OrderStatus.received)
                OutlinedButton.icon(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomelyColors.danger,
                    side: const BorderSide(color: HomelyColors.danger),
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel order'),
                ),
              if (order.status == OrderStatus.completed &&
                  order.rating == null)
                FilledButton.icon(
                  style: HomelyStyles.accentButton,
                  onPressed: () => showRateSheet(
                    context,
                    ref,
                    orderId: order.id,
                    kitchenId: order.kitchenId,
                  ),
                  icon: const Icon(Icons.star_rounded),
                  label: const Text('Rate this order'),
                ),
              if (order.rating != null)
                Row(
                  children: [
                    const Text('You rated: '),
                    for (var i = 0; i < order.rating!.stars; i++)
                      const Icon(Icons.star_rounded,
                          size: 18, color: HomelyColors.gold),
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

/// An order is confirmed to the kitchen only once its payment is captured.
bool orderIsPaid(Order order) => order.payment?.status == 'captured';

String _shortId(Order o) =>
    o.id.substring(o.id.length - 4).toUpperCase();

String _statusMessage(Order order) {
  switch (order.status) {
    case OrderStatus.received:
      return orderIsPaid(order)
          ? 'Waiting for the kitchen to accept your order.'
          : 'Confirming your payment…';
    case OrderStatus.preparing:
      return order.etaMinutes != null
          ? 'Your food is being prepared. Ready in about ${order.etaMinutes} min.'
          : 'Your food is being prepared.';
    case OrderStatus.ready:
      return 'Head to the kitchen and share your pickup code.';
    case OrderStatus.completed:
      return 'Picked up. Enjoy your meal!';
    case OrderStatus.rejected:
      return order.rejectReason != null && order.rejectReason!.isNotEmpty
          ? 'The kitchen declined: ${order.rejectReason}. You will not be charged.'
          : 'The kitchen could not take your order. You will not be charged.';
    case OrderStatus.cancelled:
      return order.cancelReason != null && order.cancelReason!.isNotEmpty
          ? 'This order was cancelled: ${order.cancelReason}. You can reorder to try again.'
          : 'This order was cancelled.';
    default:
      return '';
  }
}

/// Colour-coded status hero: blue while in progress, gold when ready to collect
/// (urgency), sage when picked up, red/neutral when declined or cancelled.
class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final paid = orderIsPaid(order);
    final failed = order.payment?.status == 'failed';

    late final Color bg;
    late final String title;
    var onDark = true;

    switch (order.status) {
      case OrderStatus.completed:
        bg = HomelyColors.sageDeep;
        title = 'Picked up 🎉';
      case OrderStatus.rejected:
        bg = HomelyColors.danger;
        title = 'Order declined';
      case OrderStatus.cancelled:
        bg = HomelyColors.inkSoft;
        title = 'Order cancelled';
      case OrderStatus.ready:
        bg = HomelyColors.gold;
        title = 'Ready for pickup 🍲';
        onDark = false; // ink text on gold
      case OrderStatus.received when !paid:
        bg = failed ? HomelyColors.danger : HomelyColors.gold;
        title = failed ? 'Payment failed' : 'Awaiting payment';
        onDark = failed;
      case OrderStatus.received:
        bg = HomelyColors.blueDeep;
        title = 'Order placed';
      case OrderStatus.preparing:
        bg = HomelyColors.blueDeep;
        title = 'Preparing your food';
      default:
        bg = HomelyColors.blueDeep;
        title = 'Your order';
    }

    final fg = onDark ? Colors.white : HomelyColors.ink;
    final fgSoft = fg.withValues(alpha: 0.85);
    final awaiting = order.status == OrderStatus.received && !paid && !failed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (awaiting) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.kitchen?.kitchenName ?? 'Kitchen'} · Order #${_shortId(order)}',
            style: TextStyle(color: fgSoft, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Text(_statusMessage(order),
              style: TextStyle(color: fgSoft, fontSize: 14, height: 1.35)),
        ],
      ),
    );
  }
}

/// Big, dashed-gold pickup-code card. The code is proof-of-pickup the customer
/// reads to the cook.
class _HandoverCard extends StatelessWidget {
  const _HandoverCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final code = order.handoverCode;
    if (code == null || code.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: HomelyColors.goldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomelyColors.gold, width: 1.5),
      ),
      child: Column(
        children: [
          Text('SHOW AT PICKUP',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: HomelyColors.goldDeep)),
          const SizedBox(height: 6),
          Text(
            code,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 10,
                  color: HomelyColors.ink,
                ),
          ),
          const SizedBox(height: 4),
          const Text('The kitchen confirms this code on handover',
              style: TextStyle(fontSize: 12, color: HomelyColors.inkFaint)),
        ],
      ),
    );
  }
}

/// Vertical status timeline. Sage = done, gold = the current step, faint = to
/// come. Skipped entirely for rejected / cancelled orders (the hero explains).
class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});
  final Order order;

  static const _labels = [
    'Order received',
    'Preparing',
    'Ready for pickup',
    'Picked up',
  ];

  int get _current => switch (order.status) {
        OrderStatus.received => 0,
        OrderStatus.preparing => 1,
        OrderStatus.ready ||
        OrderStatus.customer_en_route ||
        OrderStatus.customer_arrived =>
          2,
        OrderStatus.completed => 3,
        _ => 0,
      };

  String? _time(int i) {
    final d = switch (i) {
      0 => order.placedAt,
      1 => order.acceptedAt,
      _ => null,
    };
    if (d == null) return null;
    final l = d.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    return '$h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Column(
      children: [
        for (var i = 0; i < _labels.length; i++)
          _TimelineStep(
            label: _labels[i],
            time: i == 2 && current == 2 ? 'Any moment now' : _time(i),
            state: i < current
                ? _StepState.done
                : (i == current ? _StepState.active : _StepState.pending),
            isLast: i == _labels.length - 1,
          ),
      ],
    );
  }
}

enum _StepState { done, active, pending }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.time,
    required this.state,
    required this.isLast,
  });
  final String label;
  final String? time;
  final _StepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (dotColor, ring) = switch (state) {
      _StepState.done => (HomelyColors.sage, false),
      _StepState.active => (HomelyColors.gold, true),
      _StepState.pending => (HomelyColors.line, false),
    };
    final muted = state == _StepState.pending;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: ring
                      ? [
                          BoxShadow(
                              color: HomelyColors.gold.withValues(alpha: 0.25),
                              spreadRadius: 4)
                        ]
                      : null,
                ),
                child: state == _StepState.done
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : state == _StepState.active
                        ? const Icon(Icons.local_fire_department_rounded,
                            size: 13, color: HomelyColors.ink)
                        : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: state == _StepState.done
                        ? HomelyColors.sage
                        : HomelyColors.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                              color: muted ? HomelyColors.inkFaint : null)),
                  if (time != null)
                    Text(time!,
                        style: const TextStyle(
                            fontSize: 12, color: HomelyColors.inkFaint)),
                ],
              ),
            ),
          ),
        ],
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
                const Icon(Icons.payments_outlined,
                    size: 16, color: HomelyColors.inkFaint),
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
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
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
                        color: HomelyColors.blueDeep, size: 40),
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
