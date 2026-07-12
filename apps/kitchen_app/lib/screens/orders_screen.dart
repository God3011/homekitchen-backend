import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  static const _filters = <String?, String>{
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

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider(_statusFilter));

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          // Status filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _filters.entries.map((e) {
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
          // Orders list
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(child: Text('No orders yet'));
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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
