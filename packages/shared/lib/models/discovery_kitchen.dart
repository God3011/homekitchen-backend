/// A kitchen as it appears in the customer discovery list
/// (`GET /api/kitchens`). This is a trimmed, enriched projection — it carries a
/// server-computed rating summary, open-now flag, and optional distance, but
/// NOT the full Kitchen fields (phone, status, hours, …). Use [Kitchen] for the
/// detail screen.
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
  final bool isOpenNow;
  final int? distanceM;

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
    this.isOpenNow = false,
    this.distanceM,
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
      isOpenNow: json['isOpenNow'] as bool? ?? false,
      distanceM: json['distanceM'] as int?,
    );
  }

  /// Human-friendly distance, e.g. "800 m" or "2.3 km". Null when unknown.
  String? get distanceLabel {
    final d = distanceM;
    if (d == null) return null;
    if (d < 1000) return '$d m';
    return '${(d / 1000).toStringAsFixed(1)} km';
  }
}
