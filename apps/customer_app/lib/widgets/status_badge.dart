import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Customer-facing label + color for an order status.
({String label, Color color}) statusPresentation(OrderStatus status) {
  switch (status) {
    case OrderStatus.received:
      return (label: 'Order placed', color: Colors.blueGrey);
    case OrderStatus.preparing:
      return (label: 'Preparing', color: Colors.orange);
    case OrderStatus.ready:
      return (label: 'Ready for pickup', color: Colors.green);
    case OrderStatus.customer_en_route:
      return (label: 'On the way', color: Colors.teal);
    case OrderStatus.customer_arrived:
      return (label: 'Arrived', color: Colors.teal);
    case OrderStatus.out_for_delivery:
      return (label: 'Out for delivery', color: Colors.teal);
    case OrderStatus.completed:
      return (label: 'Completed', color: Colors.green);
    case OrderStatus.rejected:
      return (label: 'Declined', color: Colors.red);
    case OrderStatus.cancelled:
      return (label: 'Cancelled', color: Colors.grey);
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final p = statusPresentation(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(p.label,
          style: TextStyle(
              color: p.color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
