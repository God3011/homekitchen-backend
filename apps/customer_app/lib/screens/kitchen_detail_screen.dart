import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/cart_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/dish_row.dart';
import '../widgets/rating_stars.dart';
import 'cart_screen.dart';

class KitchenDetailScreen extends ConsumerWidget {
  const KitchenDetailScreen({
    super.key,
    required this.kitchenId,
    this.serviceable = true,
    this.dormantReason,
  });

  final String kitchenId;
  // From the discovery card. When not serviceable the profile is viewable but
  // ordering is disabled (the backend enforces this too).
  final bool serviceable;
  final String? dormantReason;

  String get _dormantLabel {
    switch (dormantReason) {
      case 'not_cooking_today':
        return 'Not cooking today';
      case 'outside_hours':
        return 'Closed right now';
      case 'sold_out':
        return 'Sold out for today';
      default:
        return 'Not available right now';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(kitchenDetailProvider(kitchenId));
    final menu = ref.watch(kitchenMenuProvider(kitchenId));
    final favIds = ref.watch(favoriteIdsProvider).valueOrNull ?? const {};
    final isFav = favIds.contains(kitchenId);

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.kitchenName ?? 'Kitchen'),
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.red : null),
            onPressed: () async {
              try {
                await toggleFavorite(ref, kitchenId, isFavorite: isFav);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Could not update favorite.')));
                }
              }
            },
          ),
        ],
      ),
      body: detail.when(
        data: (kitchen) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(kitchenDetailProvider(kitchenId));
            ref.invalidate(kitchenMenuProvider(kitchenId));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(kitchen: kitchen),
              if (!serviceable)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('$_dormantLabel — you can\'t order now.',
                            style: const TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 32),
              menu.when(
                data: (m) => m.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                            child: Text('This kitchen has no dishes today.')),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final section in m.sections) ...[
                            Text(section.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            for (final dish in section.dishes)
                              DishRow(
                                dish: dish,
                                kitchenId: kitchenId,
                                kitchenName: kitchen.kitchenName,
                                orderingEnabled: serviceable,
                              ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('Could not load the menu.')),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load kitchen.')),
      ),
      bottomNavigationBar: serviceable ? const _CartBar() : null,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.kitchen});
  final Kitchen kitchen;

  @override
  Widget build(BuildContext context) {
    final photos = [
      if (kitchen.cookPhotoUrl != null && kitchen.cookPhotoUrl!.isNotEmpty)
        kitchen.cookPhotoUrl!,
      ...kitchen.kitchenPhotoUrls,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty)
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(photos[i],
                    width: 240, height: 160, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                          width: 240,
                          color: Colors.deepOrange.withValues(alpha: 0.08),
                          child: const Icon(Icons.restaurant,
                              color: Colors.deepOrange),
                        )),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(kitchen.kitchenName,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        if (kitchen.cookName != null && kitchen.cookName!.isNotEmpty)
          Text('by ${kitchen.cookName}',
              style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        RatingStars(
            average: kitchen.ratingAvg, count: kitchen.ratingCount, size: 18),
        if (kitchen.signatureDish != null &&
            kitchen.signatureDish!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('⭐ Signature: ${kitchen.signatureDish}',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (kitchen.story != null && kitchen.story!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(kitchen.story!, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (kitchen.addressLine != null && kitchen.addressLine!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(kitchen.addressLine!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Sticky "View cart" bar — visible only when the cart holds items for THIS
/// kitchen.
class _CartBar extends ConsumerWidget {
  const _CartBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart == null || cart.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${cart.itemCount} item${cart.itemCount != 1 ? 's' : ''}'),
              const Text('View cart'),
              Text(formatPaise(cart.foodTotalPaise)),
            ],
          ),
        ),
      ),
    );
  }
}
