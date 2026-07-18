import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Discovery centre: the device's current GPS when available, else a Gachibowli
/// fallback so discovery still works if location is off/denied. Radius search on
/// the backend keys off whatever point this returns.
final discoveryLocationProvider =
    FutureProvider.autoDispose<({double lat, double lng})>((ref) async {
  const fallback = (lat: 17.4401, lng: 78.3489); // Gachibowli centre
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return fallback;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return fallback;
    }
    final pos = await Geolocator.getCurrentPosition();
    return (lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    return fallback;
  }
});
