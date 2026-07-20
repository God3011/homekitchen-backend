import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Customer-facing label + color for an order status.
({String label, Color color}) statusPresentation(OrderStatus status) {
  switch (status) {
    case OrderStatus.received:
      return (label: 'Order placed', color: HomelyColors.blueDeep);
    case OrderStatus.preparing:
      return (label: 'Preparing', color: HomelyColors.goldDeep);
    case OrderStatus.ready:
      return (label: 'Ready for pickup', color: HomelyColors.sageDeep);
    case OrderStatus.customer_en_route:
      return (label: 'On the way', color: HomelyColors.blueDeep);
    case OrderStatus.customer_arrived:
      return (label: 'Arrived', color: HomelyColors.blueDeep);
    case OrderStatus.out_for_delivery:
      return (label: 'Out for delivery', color: HomelyColors.blueDeep);
    case OrderStatus.completed:
      return (label: 'Completed', color: HomelyColors.sageDeep);
    case OrderStatus.rejected:
      return (label: 'Declined', color: HomelyColors.danger);
    case OrderStatus.cancelled:
      return (label: 'Cancelled', color: HomelyColors.inkFaint);
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
