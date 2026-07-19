/// A saved location: a named point (label + lat/lng) the customer picks as the
/// centre that radius-based discovery searches around. NOT a delivery address —
/// the app is pickup-only. Coordinates are the source of truth; [addressLine] is
/// just an optional human-readable display line.
class CustomerAddress {
  final String id;
  final String label;
  final String? addressLine;
  final double lat;
  final double lng;
  final bool isDefault;

  const CustomerAddress({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
    required this.isDefault,
    this.addressLine,
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: json['id'] as String,
      label: json['label'] as String,
      addressLine: json['addressLine'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}
