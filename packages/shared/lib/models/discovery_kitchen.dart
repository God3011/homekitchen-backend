/// A kitchen as it appears in the customer discovery list
/// (`GET /api/kitchens`). This is a trimmed, enriched projection — it carries a
/// server-computed rating summary, distance, and a `serviceable` flag (with a
/// `dormantReason` when not), but NOT the full Kitchen fields (phone, status,
/// hours, …). Use [Kitchen] for the detail screen.
class DiscoveryKitchen {
  final String id;
  final String kitchenName;
  final String? cookName;
  final String? cookPhotoUrl;
  final String? story;
  final String? signatureDish;
  final String? addressLine;
  final double? lat;
  final double? lng;
  final double? ratingAvg;
  final int ratingCount;
  final int? distanceM;
  // Serviceable = verified + cooking today + within hours + has plates.
  final bool serviceable;
  // 'not_cooking_today' | 'outside_hours' | 'sold_out' — set only when dormant.
  final String? dormantReason;
  // True when the kitchen has ≥1 orderable veg plate today (powers "Veg only").
  final bool hasVeg;
  // Today's available dish names — powers client-side dish search.
  final List<String> todayDishNames;

  const DiscoveryKitchen({
    required this.id,
    required this.kitchenName,
    this.cookName,
    this.cookPhotoUrl,
    this.story,
    this.signatureDish,
    this.addressLine,
    this.lat,
    this.lng,
    this.ratingAvg,
    this.ratingCount = 0,
    this.distanceM,
    this.serviceable = false,
    this.dormantReason,
    this.hasVeg = false,
    this.todayDishNames = const [],
  });

  factory DiscoveryKitchen.fromJson(Map<String, dynamic> json) {
    return DiscoveryKitchen(
      id: json['id'] as String,
      kitchenName: json['kitchenName'] as String,
      cookName: json['cookName'] as String?,
      cookPhotoUrl: json['cookPhotoUrl'] as String?,
      story: json['story'] as String?,
      signatureDish: json['signatureDish'] as String?,
      addressLine: json['addressLine'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble(),
      ratingCount: json['ratingCount'] as int? ?? 0,
      distanceM: json['distanceM'] as int?,
      serviceable: json['serviceable'] as bool? ?? false,
      dormantReason: json['dormantReason'] as String?,
      hasVeg: json['hasVeg'] as bool? ?? false,
      todayDishNames: ((json['todayDishNames'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }

  /// Human-friendly distance, e.g. "800 m" or "2.3 km". Null when unknown.
  String? get distanceLabel {
    final d = distanceM;
    if (d == null) return null;
    if (d < 1000) return '$d m';
    return '${(d / 1000).toStringAsFixed(1)} km';
  }

  /// Short customer-facing label for why a kitchen isn't orderable right now.
  String? get dormantLabel {
    switch (dormantReason) {
      case 'not_cooking_today':
        return 'Not cooking today';
      case 'outside_hours':
        return 'Closed now';
      case 'sold_out':
        return 'Sold out';
      default:
        return null;
    }
  }
}
