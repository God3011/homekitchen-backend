/// A single line in the cart: one dish, a quantity, and the customer's chosen
/// preference toggles for it. Prices are in paise.
class CartLine {
  final String menuItemId;
  final String itemName;
  final int unitPricePaise;
  final int quantity;
  final List<String> preferences;

  const CartLine({
    required this.menuItemId,
    required this.itemName,
    required this.unitPricePaise,
    required this.quantity,
    this.preferences = const [],
  });

  int get lineTotalPaise => unitPricePaise * quantity;

  CartLine copyWith({int? quantity, List<String>? preferences}) {
    return CartLine(
      menuItemId: menuItemId,
      itemName: itemName,
      unitPricePaise: unitPricePaise,
      quantity: quantity ?? this.quantity,
      preferences: preferences ?? this.preferences,
    );
  }

  /// The shape `POST /api/orders` expects for each item.
  Map<String, dynamic> toOrderItemJson() {
    return {
      'menuItemId': menuItemId,
      'quantity': quantity,
      if (preferences.isNotEmpty) 'preferences': preferences,
    };
  }
}

/// Client-side, single-kitchen cart. Enforcing "one kitchen per cart" keeps the
/// order model simple (an order belongs to exactly one kitchen). The platform
/// fee shown here is an estimate for display; the server is authoritative.
class Cart {
  final String kitchenId;
  final String kitchenName;
  final List<CartLine> lines;
  final int platformFeePaise;

  const Cart({
    required this.kitchenId,
    required this.kitchenName,
    this.lines = const [],
    this.platformFeePaise = 500, // ₹5 flat (mirrors PlatformConfig default)
  });

  bool get isEmpty => lines.isEmpty;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);

  int get foodTotalPaise => lines.fold(0, (sum, l) => sum + l.lineTotalPaise);

  /// Pickup-first v1: no delivery fee. grand = food + platform fee.
  int get grandTotalPaise => foodTotalPaise + platformFeePaise;

  Cart copyWith({List<CartLine>? lines}) {
    return Cart(
      kitchenId: kitchenId,
      kitchenName: kitchenName,
      lines: lines ?? this.lines,
      platformFeePaise: platformFeePaise,
    );
  }
}
