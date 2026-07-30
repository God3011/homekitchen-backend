import 'package:flutter/material.dart';

import '../models/order_status.dart';
import '../theme/app_colors.dart';

/// Pill showing an order's status. The two apps word (and colour) the same
/// status differently — a `received` order is "Order placed" to the customer
/// who placed it and "New" to the kitchen that has to cook it — so pass
/// [seller] to pick the right voice.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.seller = false});

  final OrderStatus status;
  final bool seller;

  @override
  Widget build(BuildContext context) {
    final color = seller ? _sellerColor(status) : _customerColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        seller ? _sellerLabel(status) : _customerLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  static Color _customerColor(OrderStatus s) => switch (s) {
        OrderStatus.received => HomelyColors.blueDeep,
        OrderStatus.preparing => HomelyColors.goldDeep,
        OrderStatus.ready => HomelyColors.sageDeep,
        OrderStatus.customer_en_route => HomelyColors.blueDeep,
        OrderStatus.customer_arrived => HomelyColors.blueDeep,
        OrderStatus.out_for_delivery => HomelyColors.blueDeep,
        OrderStatus.completed => HomelyColors.sageDeep,
        OrderStatus.rejected => HomelyColors.danger,
        OrderStatus.cancelled => HomelyColors.inkFaint,
      };

  static String _customerLabel(OrderStatus s) => switch (s) {
        OrderStatus.received => 'Order placed',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.ready => 'Ready for pickup',
        OrderStatus.customer_en_route => 'On the way',
        OrderStatus.customer_arrived => 'Arrived',
        OrderStatus.out_for_delivery => 'Out for delivery',
        OrderStatus.completed => 'Completed',
        OrderStatus.rejected => 'Declined',
        OrderStatus.cancelled => 'Cancelled',
      };

  static Color _sellerColor(OrderStatus s) => switch (s) {
        OrderStatus.received => HomelyColors.goldDeep,
        OrderStatus.preparing => HomelyColors.blueDeep,
        OrderStatus.ready => HomelyColors.sageDeep,
        OrderStatus.completed => HomelyColors.inkFaint,
        OrderStatus.rejected => HomelyColors.danger,
        OrderStatus.cancelled => HomelyColors.nonVeg,
        _ => HomelyColors.blueDeep,
      };

  static String _sellerLabel(OrderStatus s) => switch (s) {
        OrderStatus.received => 'New',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.ready => 'Ready',
        OrderStatus.customer_en_route => 'Customer On Way',
        OrderStatus.customer_arrived => 'Customer Here',
        OrderStatus.completed => 'Completed',
        OrderStatus.rejected => 'Rejected',
        OrderStatus.cancelled => 'Cancelled',
        _ => s.name,
      };
}
