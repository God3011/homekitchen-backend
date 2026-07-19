import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../providers/kitchen_provider.dart';
import '../widgets/order_card.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  Timer? _pollTimer;
  String? _statusFilter;

  // Date filter — null means "show all dates"; default is today.
  DateTime? _dateFilter = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

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

  /// Returns true if [order] was placed on the selected date (local time).
  bool _matchesDate(Order order) {
    if (_dateFilter == null) return true;
    final l = order.placedAt.toLocal();
    final d = DateTime(l.year, l.month, l.day);
    return d == _dateFilter;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Filter by order date',
    );
    if (picked != null) {
      setState(
          () => _dateFilter = DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider(_statusFilter));
    final scheme = Theme.of(context).colorScheme;

    final isToday =
        _dateFilter != null && _dateFilter == _today();
    final dateLabel = _dateFilter == null
        ? 'All dates'
        : isToday
            ? 'Today'
            : DateFormat('d MMM yyyy').format(_dateFilter!);

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          // ── Date picker row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(dateLabel),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                // "Today" shortcut — shown when not already on today
                if (!isToday)
                  ActionChip(
                    label: const Text('Today'),
                    avatar: const Icon(Icons.today, size: 16),
                    onPressed: () => setState(() => _dateFilter = _today()),
                  ),
                // Clear to "all dates"
                if (_dateFilter != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: IconButton(
                      tooltip: 'Show all dates',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dateFilter = null),
                    ),
                  ),
              ],
            ),
          ),
          // ── Status filter chips ──────────────────────────────────────
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
                    onSelected: (_) {
                      setState(() => _statusFilter = e.key);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          // ── Orders list ──────────────────────────────────────────────
          Expanded(
            child: ordersAsync.when(
              data: (allOrders) {
                final orders = allOrders.where(_matchesDate).toList();

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 48, color: scheme.outlineVariant),
                        const SizedBox(height: 12),
                        Text(
                          _dateFilter != null
                              ? 'No orders on $dateLabel'
                              : 'No orders yet',
                          style: TextStyle(color: scheme.outline),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ordersProvider(_statusFilter));
                  },
                  child: ListView.builder(
                    itemCount: orders.length,
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemBuilder: (context, i) {
                      return OrderCard(
                        order: orders[i],
                        onTap: () => _openDetail(context, orders[i]),
                      );
                    },
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
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: order.id),
      ),
    );
  }
}
