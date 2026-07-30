import 'package:flutter/material.dart';
import 'package:shared/shared.dart';


class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.fold<int>(0, (s, i) => s + i.quantity);
    final ago = _timeAgo(order.placedAt);
    final isNew = order.status == OrderStatus.received;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: HomelyColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNew
              ? HomelyColors.gold.withValues(alpha: 0.55)
              : HomelyColors.line,
          width: isNew ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
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
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(status: order.status, seller: true),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$itemCount item${itemCount != 1 ? 's' : ''}  ·  ${formatPaise(order.grandTotalPaise)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(ago,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: HomelyColors.inkFaint)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: HomelyColors.inkFaint),
              ],
            ),
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
