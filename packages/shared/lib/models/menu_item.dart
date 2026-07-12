/// A single preference toggle on a menu item.
class MenuItemPreference {
  final String id;
  final String preference;

  const MenuItemPreference({
    required this.id,
    required this.preference,
  });

  factory MenuItemPreference.fromJson(Map<String, dynamic> json) {
    return MenuItemPreference(
      id: json['id'] as String,
      preference: json['preference'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'preference': preference,
    };
  }
}

/// MenuItem model — mirrors the backend MenuItem entity.
/// Price is stored in paise (integers). Format to rupees only at display time.
class MenuItem {
  final String id;
  final String kitchenId;
  final String name;
  final String? categoryId;
  final int pricePaise;
  final bool isActive;
  final List<MenuItemPreference> preferences;

  const MenuItem({
    required this.id,
    required this.kitchenId,
    required this.name,
    this.categoryId,
    required this.pricePaise,
    required this.isActive,
    this.preferences = const [],
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      kitchenId: json['kitchenId'] as String,
      name: json['name'] as String,
      categoryId: json['categoryId'] as String?,
      pricePaise: json['pricePaise'] as int,
      isActive: json['isActive'] as bool,
      preferences: (json['preferences'] as List<dynamic>?)
              ?.map((e) =>
                  MenuItemPreference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kitchenId': kitchenId,
      'name': name,
      'categoryId': categoryId,
      'pricePaise': pricePaise,
      'isActive': isActive,
      'preferences': preferences.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() => 'MenuItem(id: $id, name: $name, pricePaise: $pricePaise)';
}
