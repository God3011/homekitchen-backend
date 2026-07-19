import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/kitchen_provider.dart';
import '../widgets/order_card.dart';
import 'order_detail_screen.dart';

// ── date helpers ──────────────────────────────────────────────────────────────
DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _humanDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  Timer? _pollTimer;
  String? _statusFilter;

  // null = "All dates"; otherwise filters by that local calendar day.
  DateTime? _dateFilter = _today();

  static const _statusFilters = <String?, String>{
    null: 'All',
    'received': 'New',
    'preparing': 'Preparing',
    'ready': 'Ready',
    'completed': 'Completed',
  };

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.invalidate(ordersProvider(_statusFilter));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool _matchesDate(Order order) {
    if (_dateFilter == null) return true;
    final l = order.placedAt.toLocal();
    return DateTime(l.year, l.month, l.day) == _dateFilter;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider(_statusFilter));

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          // ── Date chips (same style as Menu screen) ─────────────────
          _OrderDateChips(
            selected: _dateFilter,
            onSelect: (d) => setState(() => _dateFilter = d),
          ),
          const Divider(height: 1),
          // ── Status filter chips ─────────────────────────────────────
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _statusFilters.entries.map((e) {
                final selected = _statusFilter == e.key;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) => setState(() => _statusFilter = e.key),
                  ),
                );
              }).toList(),
            ),
          ),
          // ── Orders list ─────────────────────────────────────────────
          Expanded(
            child: ordersAsync.when(
              data: (allOrders) {
                final orders = allOrders.where(_matchesDate).toList();
                final dateLabel = _dateFilter == null
                    ? 'any date'
                    : _humanDate(_dateFilter!);

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 48,
                            color: Theme.of(context).colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        Text(
                          'No orders for $dateLabel',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(ordersProvider(_statusFilter)),
                  child: ListView.builder(
                    itemCount: orders.length,
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemBuilder: (context, i) => OrderCard(
                      order: orders[i],
                      onTap: () => _openDetail(context, orders[i]),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
    );
  }
}

// ── Date chip selector (mirrors Menu screen _DateChips + adds "All") ──────────
class _OrderDateChips extends StatelessWidget {
  const _OrderDateChips({required this.selected, required this.onSelect});

  /// null = all dates.
  final DateTime? selected;
  final ValueChanged<DateTime?> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = _today();
    final yesterday = today.subtract(const Duration(days: 1));

    final isAll = selected == null;
    final isToday = selected == today;
    final isYesterday = selected == yesterday;
    final isOther = !isAll && !isToday && !isYesterday;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        // "All dates" chip
        ChoiceChip(
          label: const Text('All dates'),
          selected: isAll,
          onSelected: (_) => onSelect(null),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Today'),
          selected: isToday,
          onSelected: (_) => onSelect(today),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Yesterday'),
          selected: isYesterday,
          onSelected: (_) => onSelect(yesterday),
        ),
        const SizedBox(width: 8),
        // Calendar chip — shows the picked date when a specific other day
        // is selected; otherwise shows "Select date".
        ChoiceChip(
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(isOther ? _humanDate(selected!) : 'Select date'),
          selected: isOther,
          onSelected: (_) async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selected ?? today,
              firstDate: DateTime(2024),
              lastDate: today,
              helpText: 'Filter by order date',
            );
            if (picked != null && context.mounted) {
              onSelect(DateTime(picked.year, picked.month, picked.day));
            }
          },
        ),
      ]),
    );
  }
}
