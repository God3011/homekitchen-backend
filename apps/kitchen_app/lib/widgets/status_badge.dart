import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          color: _color(status),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  static Color _color(OrderStatus s) => switch (s) {
        OrderStatus.received => Colors.blue,
        OrderStatus.preparing => Colors.orange,
        OrderStatus.ready => Colors.green,
        OrderStatus.completed => Colors.grey,
        OrderStatus.rejected => Colors.red,
        OrderStatus.cancelled => Colors.red.shade300,
        _ => Colors.blueGrey,
      };

  static String _label(OrderStatus s) => switch (s) {
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
