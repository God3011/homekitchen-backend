import 'package:shared/shared.dart';

/// The `GET /api/kitchens` envelope: a discovery [state] plus the kitchens in
/// range. Carries the queried [lat]/[lng] so the "not serving your area yet"
/// screen can register interest for that exact spot.
class DiscoveryResult {
  /// 'serviceable' | 'dormant_only' | 'none_in_radius'
  final String state;
  final List<DiscoveryKitchen> kitchens;
  final double lat;
  final double lng;

  const DiscoveryResult({
    required this.state,
    required this.kitchens,
    required this.lat,
    required this.lng,
  });

  bool get isServiceable => state == 'serviceable';
  bool get isDormantOnly => state == 'dormant_only';
  bool get isNoneInRadius => state == 'none_in_radius';

  factory DiscoveryResult.fromJson(
    Map<String, dynamic> json, {
    required double lat,
    required double lng,
  }) {
    return DiscoveryResult(
      state: json['state'] as String? ?? 'none_in_radius',
      kitchens: ((json['kitchens'] as List<dynamic>?) ?? const [])
          .map((e) => DiscoveryKitchen.fromJson(e as Map<String, dynamic>))
          .toList(),
      lat: lat,
      lng: lng,
    );
  }
}
