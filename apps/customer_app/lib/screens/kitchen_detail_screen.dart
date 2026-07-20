import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../models/menu.dart';
import '../providers/cart_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/rating_stars.dart';
import 'cart_screen.dart';

class KitchenDetailScreen extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<KitchenDetailScreen> createState() =>
      _KitchenDetailScreenState();
}

class _KitchenDetailScreenState extends ConsumerState<KitchenDetailScreen> {
  bool _vegOnly = false;

  String get _dormantLabel {
    switch (widget.dormantReason) {
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
  Widget build(BuildContext context) {
    final kitchenId = widget.kitchenId;
    final serviceable = widget.serviceable;
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
              _Header(kitchen: kitchen, serviceable: serviceable),
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
                data: (m) => _MenuBody(
                  menu: m,
                  kitchenId: kitchenId,
                  kitchenName: kitchen.kitchenName,
                  serviceable: serviceable,
                  vegOnly: _vegOnly,
                  onVegChanged: (v) => setState(() => _vegOnly = v),
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

/// The menu list with a "Veg only" filter header. Dishes are shown in a 2-col
/// grid of square cards with images, grouped by section.
class _MenuBody extends ConsumerWidget {
  const _MenuBody({
    required this.menu,
    required this.kitchenId,
    required this.kitchenName,
    required this.serviceable,
    required this.vegOnly,
    required this.onVegChanged,
  });

  final KitchenMenu menu;
  final String kitchenId;
  final String kitchenName;
  final bool serviceable;
  final bool vegOnly;
  final ValueChanged<bool> onVegChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (menu.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('This kitchen has no dishes today.')),
      );
    }

    final sections = <MenuSection>[
      for (final s in menu.sections)
        if (!vegOnly)
          s
        else if (s.dishes.any((d) => d.isVeg))
          MenuSection(
            name: s.name,
            dishes: s.dishes.where((d) => d.isVeg).toList(),
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Menu',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            VegOnlyToggle(value: vegOnly, onChanged: onVegChanged),
          ],
        ),
        const SizedBox(height: 12),
        if (sections.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No veg dishes on the menu today.')),
          )
        else
          for (final section in sections) ...[
            if (section.name != 'Menu')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(section.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            // 2-column grid of square dish cards
            Builder(builder: (context) {
              final sorted = [...section.dishes]
                ..sort((a, b) {
                  if (a.isAvailable == b.isAvailable) return 0;
                  return a.isAvailable ? -1 : 1;
                });
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sorted.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.75,
                ),
                itemBuilder: (context, i) => _DishCard(
                  dish: sorted[i],
                  kitchenId: kitchenId,
                  kitchenName: kitchenName,
                  orderingEnabled: serviceable,
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

/// A square-ish dish card with an image on top, name, price, and an ADD button.
class _DishCard extends ConsumerWidget {
  const _DishCard({
    required this.dish,
    required this.kitchenId,
    required this.kitchenName,
    this.orderingEnabled = true,
  });

  final MenuDish dish;
  final String kitchenId;
  final String kitchenName;
  final bool orderingEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider.select((c) {
      if (c == null || c.kitchenId != kitchenId) return 0;
      for (final l in c.lines) {
        if (l.menuItemId == dish.id) return l.quantity;
      }
      return 0;
    }));

    final soldOut = !dish.isAvailable;

    return Container(
      decoration: BoxDecoration(
        color: HomelyColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomelyColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          AspectRatio(
            aspectRatio: 4 / 3,
            child: dish.photoUrl != null && dish.photoUrl!.isNotEmpty
                ? Image.network(
                    dish.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _DishImagePlaceholder(
                        isVeg: dish.isVeg),
                  )
                : _DishImagePlaceholder(isVeg: dish.isVeg),
          ),
          // Info area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + veg badge
                  Row(
                    children: [
                      VegBadge(isVeg: dish.isVeg, size: 13),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dish.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: HomelyColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Price (left) + action (right) on the same line
                  Row(
                    children: [
                      // Price — left side
                      Text(formatPaise(dish.pricePaise),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: HomelyColors.goldDeep)),
                      const Spacer(),
                      // ADD / stepper / sold out — right side
                      if (soldOut)
                        const Text('Sold out',
                            style: TextStyle(
                                color: HomelyColors.danger,
                                fontSize: 11,
                                fontWeight: FontWeight.w600))
                      else if (!orderingEnabled)
                        const SizedBox.shrink()
                      else if (qty == 0)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: HomelyColors.goldDeep,
                            backgroundColor: HomelyColors.goldTint,
                            side: const BorderSide(
                                color: HomelyColors.gold, width: 1.4),
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () => _addToCart(context, ref),
                          child: const Text('ADD'),
                        )
                      else
                        _MiniStepper(
                          quantity: qty,
                          onRemove: () =>
                              ref.read(cartProvider.notifier).decrement(dish.id),
                          onAdd: qty < dish.platesRemaining
                              ? () => ref
                                  .read(cartProvider.notifier)
                                  .increment(dish.id)
                              : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider.notifier);

    if (cart.isForOtherKitchen(kitchenId)) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: const Text(
              'Your cart has items from another kitchen. Adding this will clear it.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Start new')),
          ],
        ),
      );
      if (replace != true) return;
    }

    var selected = <String>[];
    if (dish.preferences.isNotEmpty && context.mounted) {
      final chosen = await showModalBottomSheet<List<String>>(
        context: context,
        builder: (ctx) {
          final picked = <String>{};
          return StatefulBuilder(
            builder: (ctx, setModalState) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preferences for ${dish.name}',
                        style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final p in dish.preferences)
                          FilterChip(
                            label: Text(prettyPreference(p)),
                            selected: picked.contains(p),
                            onSelected: (v) => setModalState(() {
                              v ? picked.add(p) : picked.remove(p);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, picked.toList()),
                      child: const Text('Add to cart'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (chosen == null) return;
      selected = chosen;
    }

    cart.addDish(
      kitchenId: kitchenId,
      kitchenName: kitchenName,
      menuItemId: dish.id,
      itemName: dish.name,
      unitPricePaise: dish.pricePaise,
      preferences: selected,
    );

    trackEvent('item_added_to_cart', {
      'item_id': dish.id,
      'kitchen_id': kitchenId,
      'price': dish.pricePaise,
      'preferences': selected.join(','),
    });
  }
}

class _DishImagePlaceholder extends StatelessWidget {
  const _DishImagePlaceholder({required this.isVeg});
  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HomelyColors.surfaceAlt,
      child: Center(
        child: Icon(
          isVeg ? Icons.eco_rounded : Icons.restaurant_rounded,
          color: HomelyColors.inkFaint,
          size: 32,
        ),
      ),
    );
  }
}

/// Compact stepper that fits inside the dish card.
class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.quantity,
    required this.onRemove,
    required this.onAdd,
  });

  final int quantity;
  final VoidCallback onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    // Content-sized (never infinite width) so it sits on the left of the
    // price/action row with the price on the right.
    return Container(
      decoration: BoxDecoration(
        color: HomelyColors.gold,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.remove, size: 15, color: HomelyColors.ink),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text('$quantity',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: HomelyColors.ink)),
          ),
          InkWell(
            onTap: onAdd,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(Icons.add,
                  size: 15,
                  color:
                      onAdd != null ? HomelyColors.ink : HomelyColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.kitchen, required this.serviceable});
  final Kitchen kitchen;
  final bool serviceable;

  @override
  Widget build(BuildContext context) {
    final photos = [
      if (kitchen.cookPhotoUrl != null && kitchen.cookPhotoUrl!.isNotEmpty)
        kitchen.cookPhotoUrl!,
      ...kitchen.kitchenPhotoUrls,
    ];
    final hasRating = kitchen.ratingAvg != null && kitchen.ratingCount > 0;
    final hasSignature =
        kitchen.signatureDish != null && kitchen.signatureDish!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero image with verified / cooking badges overlaid.
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              SizedBox(
                height: 190,
                width: double.infinity,
                child: photos.isNotEmpty
                    ? Image.network(photos.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _HeroFallback())
                    : const _HeroFallback(),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Wrap(
                  spacing: 6,
                  children: [
                    const _HeaderBadge(
                      icon: Icons.verified_rounded,
                      label: 'Verified',
                      fg: HomelyColors.sageDeep,
                      bg: Colors.white,
                    ),
                    if (serviceable)
                      const _HeaderBadge(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Cooking Today',
                        fg: Colors.white,
                        bg: HomelyColors.sage,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length - 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(photos[i + 1],
                    width: 84, height: 60, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                        width: 84, height: 60, child: _HeroFallback())),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(kitchen.kitchenName,
            style: Theme.of(context).textTheme.headlineSmall),
        if (kitchen.cookName != null && kitchen.cookName!.isNotEmpty)
          Text('by ${kitchen.cookName}',
              style: const TextStyle(color: HomelyColors.inkFaint)),
        if (hasRating || hasSignature) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasRating) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: HomelyColors.sage,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                          '${kitchen.ratingAvg!.toStringAsFixed(1)} (${kitchen.ratingCount})',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ],
                  ),
                ),
                if (hasSignature) const SizedBox(width: 10),
              ],
              if (hasSignature)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 15, color: HomelyColors.gold),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(kitchen.signatureDish!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: HomelyColors.inkSoft)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        if (kitchen.story != null && kitchen.story!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(kitchen.story!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HomelyColors.inkSoft, height: 1.4)),
        ],
        if (kitchen.addressLine != null && kitchen.addressLine!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.place_outlined,
                  size: 16, color: HomelyColors.inkFaint),
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

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
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

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();
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
        child: Icon(Icons.restaurant_rounded, color: Colors.white, size: 40),
      ),
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
          style: HomelyStyles.accentButton,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${cart.itemCount} item${cart.itemCount != 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('View cart'),
                ],
              ),
              Text(formatPaise(cart.foodTotalPaise),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
