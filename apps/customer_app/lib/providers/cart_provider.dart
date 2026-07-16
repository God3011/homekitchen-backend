import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

/// Single-kitchen cart. Adding a dish from a different kitchen replaces the
/// cart (the UI confirms first via [isForOtherKitchen]). One line per dish;
/// the most recently chosen preferences win.
class CartNotifier extends StateNotifier<Cart?> {
  CartNotifier() : super(null);

  /// True when there's a non-empty cart for a DIFFERENT kitchen.
  bool isForOtherKitchen(String kitchenId) {
    final cart = state;
    return cart != null && !cart.isEmpty && cart.kitchenId != kitchenId;
  }

  int quantityOf(String menuItemId) {
    final cart = state;
    if (cart == null) return 0;
    for (final l in cart.lines) {
      if (l.menuItemId == menuItemId) return l.quantity;
    }
    return 0;
  }

  void addDish({
    required String kitchenId,
    required String kitchenName,
    required String menuItemId,
    required String itemName,
    required int unitPricePaise,
    List<String> preferences = const [],
  }) {
    var cart = state;
    // Start a fresh cart if none exists or it's for another kitchen.
    if (cart == null || cart.kitchenId != kitchenId) {
      cart = Cart(kitchenId: kitchenId, kitchenName: kitchenName);
    }

    final lines = [...cart.lines];
    final idx = lines.indexWhere((l) => l.menuItemId == menuItemId);
    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(
        quantity: lines[idx].quantity + 1,
        preferences: preferences,
      );
    } else {
      lines.add(CartLine(
        menuItemId: menuItemId,
        itemName: itemName,
        unitPricePaise: unitPricePaise,
        quantity: 1,
        preferences: preferences,
      ));
    }
    state = cart.copyWith(lines: lines);
  }

  void setQuantity(String menuItemId, int quantity) {
    final cart = state;
    if (cart == null) return;
    final lines = <CartLine>[];
    for (final l in cart.lines) {
      if (l.menuItemId == menuItemId) {
        if (quantity > 0) lines.add(l.copyWith(quantity: quantity));
        // quantity <= 0 → drop the line
      } else {
        lines.add(l);
      }
    }
    state = lines.isEmpty ? null : cart.copyWith(lines: lines);
  }

  void increment(String menuItemId) =>
      setQuantity(menuItemId, quantityOf(menuItemId) + 1);

  void decrement(String menuItemId) =>
      setQuantity(menuItemId, quantityOf(menuItemId) - 1);

  void setPreferences(String menuItemId, List<String> preferences) {
    final cart = state;
    if (cart == null) return;
    final lines = cart.lines
        .map((l) =>
            l.menuItemId == menuItemId ? l.copyWith(preferences: preferences) : l)
        .toList();
    state = cart.copyWith(lines: lines);
  }

  void clear() => state = null;
}

final cartProvider =
    StateNotifierProvider<CartNotifier, Cart?>((_) => CartNotifier());
