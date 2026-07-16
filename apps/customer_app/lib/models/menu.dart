// Customer-facing menu view models for `GET /api/menu/kitchens/:kitchenId`.
//
// Unlike the shared `MenuItem`, these carry TODAY's plate availability so the
// menu can show "N left" / "Sold out" and disable adding unavailable dishes.

/// One dish on a kitchen's menu, with today's availability folded in.
class MenuDish {
  final String id;
  final String name;
  final int pricePaise;
  final String? photoUrl;
  final List<String> preferences;
  final int platesRemaining;
  final bool isAvailable;

  const MenuDish({
    required this.id,
    required this.name,
    required this.pricePaise,
    this.photoUrl,
    this.preferences = const [],
    this.platesRemaining = 0,
    this.isAvailable = false,
  });

  factory MenuDish.fromJson(Map<String, dynamic> json) {
    // availability is filtered to today server-side → 0 or 1 element.
    final avail = (json['availability'] as List<dynamic>?) ?? const [];
    final today = avail.isNotEmpty ? avail.first as Map<String, dynamic> : null;
    final remaining = today?['platesRemaining'] as int? ?? 0;
    final flag = today?['isAvailable'] as bool? ?? false;
    return MenuDish(
      id: json['id'] as String,
      name: json['name'] as String,
      pricePaise: json['pricePaise'] as int,
      photoUrl: json['photoUrl'] as String?,
      preferences: ((json['preferences'] as List<dynamic>?) ?? const [])
          .map((e) => (e as Map<String, dynamic>)['preference'] as String)
          .toList(),
      platesRemaining: remaining,
      // A dish is orderable only if flagged available AND has plates left today.
      isAvailable: flag && remaining > 0,
    );
  }
}

/// A named group of dishes (a category, or the catch-all "Other").
class MenuSection {
  final String name;
  final List<MenuDish> dishes;

  const MenuSection({required this.name, required this.dishes});
}

/// A kitchen's full menu, grouped into sections (empty groups omitted).
class KitchenMenu {
  final List<MenuSection> sections;

  const KitchenMenu({this.sections = const []});

  bool get isEmpty => sections.every((s) => s.dishes.isEmpty);

  factory KitchenMenu.fromJson(Map<String, dynamic> json) {
    final sections = <MenuSection>[];

    for (final c in (json['categories'] as List<dynamic>? ?? const [])) {
      final cat = c as Map<String, dynamic>;
      final dishes = ((cat['items'] as List<dynamic>?) ?? const [])
          .map((e) => MenuDish.fromJson(e as Map<String, dynamic>))
          .toList();
      if (dishes.isNotEmpty) {
        sections.add(MenuSection(name: cat['name'] as String, dishes: dishes));
      }
    }

    final uncategorized = ((json['uncategorized'] as List<dynamic>?) ?? const [])
        .map((e) => MenuDish.fromJson(e as Map<String, dynamic>))
        .toList();
    if (uncategorized.isNotEmpty) {
      sections.add(MenuSection(name: 'Other', dishes: uncategorized));
    }

    return KitchenMenu(sections: sections);
  }
}
