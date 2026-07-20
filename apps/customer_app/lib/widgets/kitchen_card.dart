import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// A tappable, photo-forward discovery card: image header with a favourite tap
/// and distance overlay, then name, cook, sage rating pill, signature dish, and
/// verified / cooking-today status badges. Dormant kitchens are dimmed but still
/// open to view.
class KitchenCard extends StatelessWidget {
  const KitchenCard({super.key, required this.kitchen, required this.onTap});

  final DiscoveryKitchen kitchen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final serviceable = kitchen.serviceable;
    final photo = kitchen.cookPhotoUrl;
    final hasRating = kitchen.ratingAvg != null && kitchen.ratingCount > 0;

    return Opacity(
      opacity: serviceable ? 1 : 0.62,
      child: Container(
        decoration: BoxDecoration(
          color: HomelyColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HomelyColors.lineSoft),
          boxShadow: [
            BoxShadow(
              color: HomelyColors.ink.withValues(alpha: 0.10),
              blurRadius: 18,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Photo header ──
                Stack(
                  children: [
                    SizedBox(
                      height: 132,
                      width: double.infinity,
                      child: photo != null && photo.isNotEmpty
                          ? Image.network(photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const _PhotoFallback())
                          : const _PhotoFallback(),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite_border,
                            size: 17, color: HomelyColors.nonVeg),
                      ),
                    ),
                    if (kitchen.distanceLabel != null)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: _OverlayChip(
                          icon: Icons.place_outlined,
                          label: kitchen.distanceLabel!,
                        ),
                      ),
                  ],
                ),
                // ── Body ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(kitchen.kitchenName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                if (kitchen.cookName != null &&
                                    kitchen.cookName!.isNotEmpty)
                                  Text('by ${kitchen.cookName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: HomelyColors.inkFaint)),
                              ],
                            ),
                          ),
                          if (hasRating) ...[
                            const SizedBox(width: 8),
                            _RatingPill(average: kitchen.ratingAvg!),
                          ],
                        ],
                      ),
                      if (kitchen.signatureDish != null &&
                          kitchen.signatureDish!.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 15, color: HomelyColors.gold),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(kitchen.signatureDish!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: HomelyColors.inkSoft)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          const _Badge(
                            icon: Icons.verified_rounded,
                            label: 'Verified',
                            fg: HomelyColors.sageDeep,
                            bg: HomelyColors.sageTint,
                          ),
                          if (serviceable)
                            const _Badge(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Cooking Today',
                              fg: Colors.white,
                              bg: HomelyColors.sage,
                            )
                          else if (kitchen.dormantLabel != null)
                            _Badge(
                              icon: Icons.schedule_rounded,
                              label: kitchen.dormantLabel!,
                              fg: HomelyColors.goldDeep,
                              bg: HomelyColors.goldTint,
                            ),
                        ],
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

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.average});
  final double average;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: HomelyColors.sage,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 2),
          Text(average.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: HomelyColors.ink.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HomelyColors.gold, HomelyColors.goldDeep],
        ),
      ),
      child: const Center(
        child: Icon(Icons.restaurant_rounded, color: Colors.white, size: 34),
      ),
    );
  }
}
