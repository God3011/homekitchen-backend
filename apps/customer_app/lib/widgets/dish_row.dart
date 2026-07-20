import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../models/menu.dart';
import '../providers/cart_provider.dart';
import 'rating_stars.dart';

/// One dish on the kitchen menu, with an add-to-cart stepper. Handles the
/// "start a new cart for a different kitchen?" confirmation and per-dish
/// preference selection.
class DishRow extends ConsumerWidget {
  const DishRow({
    super.key,
    required this.dish,
    required this.kitchenId,
    required this.kitchenName,
    this.orderingEnabled = true,
  });

  final MenuDish dish;
  final String kitchenId;
  final String kitchenName;
  // False when the kitchen is dormant — the dish shows but can't be added.
  final bool orderingEnabled;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
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
      final chosen = await _pickPreferences(context);
      if (chosen == null) return; // cancelled
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

  Future<List<String>?> _pickPreferences(BuildContext context) {
    final selected = <String>{};
    return showModalBottomSheet<List<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
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
                            selected: selected.contains(p),
                            onSelected: (v) => setModalState(() {
                              v ? selected.add(p) : selected.remove(p);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(ctx, selected.toList()),
                      child: const Text('Add to cart'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    VegBadge(isVeg: dish.isVeg, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(dish.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(formatPaise(dish.pricePaise),
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                if (soldOut)
                  const Text('Sold out',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))
                else if (dish.platesRemaining <= 3)
                  Text('Only ${dish.platesRemaining} left',
                      style: TextStyle(
                          color: Colors.orange.shade800, fontSize: 12)),
                if (dish.preferences.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      dish.preferences.map(prettyPreference).join(' · '),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!orderingEnabled)
            const SizedBox.shrink()
          else if (soldOut)
            const SizedBox.shrink()
          else if (qty == 0)
            OutlinedButton(
              // Override the theme's full-width (double.infinity) min size —
              // inside a Row that would demand infinite width and crash layout.
              // Gold "appetite" treatment: this is a food action.
              style: OutlinedButton.styleFrom(
                foregroundColor: HomelyColors.goldDeep,
                backgroundColor: HomelyColors.goldTint,
                side: const BorderSide(color: HomelyColors.gold, width: 1.4),
                minimumSize: const Size(72, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () => _add(context, ref),
              child: const Text('ADD'),
            )
          else
            _Stepper(
              quantity: qty,
              onRemove: () =>
                  ref.read(cartProvider.notifier).decrement(dish.id),
              onAdd: qty < dish.platesRemaining
                  ? () => ref.read(cartProvider.notifier).increment(dish.id)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.onRemove,
    required this.onAdd,
  });

  final int quantity;
  final VoidCallback onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HomelyColors.gold,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18, color: HomelyColors.ink),
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
          ),
          Text('$quantity',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: HomelyColors.ink)),
          IconButton(
            icon: const Icon(Icons.add, size: 18, color: HomelyColors.ink),
            visualDensity: VisualDensity.compact,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
