import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import 'rating_stars.dart';

/// A tappable discovery card: photo, name, rating, signature dish, open/closed,
/// and distance when known.
class KitchenCard extends StatelessWidget {
  const KitchenCard({super.key, required this.kitchen, required this.onTap});

  final DiscoveryKitchen kitchen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = kitchen.cookPhotoUrl;
    return Opacity(
      // Dim dormant kitchens — still tappable/viewable, just not orderable now.
      opacity: kitchen.serviceable ? 1 : 0.6,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: photo != null && photo.isNotEmpty
                      ? Image.network(photo, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _PhotoFallback())
                      : const _PhotoFallback(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kitchen.kitchenName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (kitchen.signatureDish != null &&
                        kitchen.signatureDish!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('⭐ ${kitchen.signatureDish}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        RatingStars(
                            average: kitchen.ratingAvg,
                            count: kitchen.ratingCount),
                        const Spacer(),
                        _StatusChip(kitchen: kitchen),
                      ],
                    ),
                    if (kitchen.distanceLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 13, color: Colors.grey),
                            const SizedBox(width: 2),
                            Text(kitchen.distanceLabel!,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.kitchen});
  final DiscoveryKitchen kitchen;

  @override
  Widget build(BuildContext context) {
    final serviceable = kitchen.serviceable;
    final label = serviceable ? 'Available' : (kitchen.dormantLabel ?? 'Closed');
    final color = serviceable ? Colors.green : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.deepOrange.withValues(alpha: 0.08),
      child: const Icon(Icons.restaurant, color: Colors.deepOrange),
    );
  }
}
