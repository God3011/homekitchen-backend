/// A single preference toggle on a menu item.
/// Identified by (menuItemId, preference) on the backend — there is no `id`.
class MenuItemPreference {
  final String preference;

  const MenuItemPreference({required this.preference});

  factory MenuItemPreference.fromJson(Map<String, dynamic> json) {
    return MenuItemPreference(
      preference: json['preference'] as String,
    );
  }

}

/// MenuItem model — mirrors the backend MenuItem entity.
/// Price is stored in paise (integers). Format to rupees only at display time.
class MenuItem {
  final String id;
  final String kitchenId;
  final String name;
  final int pricePaise;
  final String? photoUrl;
  final bool isVeg;
  final bool isActive;
  final List<MenuItemPreference> preferences;

  const MenuItem({
    required this.id,
    required this.kitchenId,
    required this.name,
    required this.pricePaise,
    this.photoUrl,
    this.isVeg = true,
    required this.isActive,
    this.preferences = const [],
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      kitchenId: json['kitchenId'] as String,
      name: json['name'] as String,
      pricePaise: json['pricePaise'] as int,
      photoUrl: json['photoUrl'] as String?,
      isVeg: json['isVeg'] as bool? ?? true,
      isActive: json['isActive'] as bool,
      preferences: (json['preferences'] as List<dynamic>?)
              ?.map((e) =>
                  MenuItemPreference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }


  @override
  String toString() => 'MenuItem(id: $id, name: $name, pricePaise: $pricePaise)';
}
