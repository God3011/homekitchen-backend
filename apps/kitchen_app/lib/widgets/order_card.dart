import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import 'status_badge.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.fold<int>(0, (s, i) => s + i.quantity);
    final ago = _timeAgo(order.placedAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${order.id.substring(order.id.length - 8).toUpperCase()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$itemCount item${itemCount != 1 ? 's' : ''}  ·  ${formatPaise(order.grandTotalPaise)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(ago,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            )),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
