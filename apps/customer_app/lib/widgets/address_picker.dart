import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../providers/api_provider.dart';

class AddressResult {
  final double lat;
  final double lng;
  final String address;
  const AddressResult({
    required this.lat,
    required this.lng,
    required this.address,
  });
}

/// Home-location picker: type-to-search (autocomplete), "use my location", or
/// tap the map to drop a pin. All paths reverse-geocode to a readable address
/// and report lat/lng + address via [onChanged].
class AddressPicker extends ConsumerStatefulWidget {
  const AddressPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
    required this.onChanged,
  });
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;
  final void Function(AddressResult) onChanged;

  @override
  ConsumerState<AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends ConsumerState<AddressPicker> {
  static const _fallback = LatLng(17.4401, 78.3489); // Gachibowli
  final _searchController = TextEditingController();
  final _mapController = MapController();
  late LatLng _pin;
  String _address = '';
  List<Map<String, dynamic>> _suggestions = [];
  bool _busy = false;
  Timer? _debounce;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pin = (widget.initialLat != null && widget.initialLng != null)
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : _fallback;
    _address = widget.initialAddress ?? '';
    _searchController.text = _address;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _report() => widget.onChanged(
        AddressResult(
            lat: _pin.latitude, lng: _pin.longitude, address: _address),
      );

  Future<void> _reverse(LatLng p) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(apiClientProvider).get('/geocode/reverse', queryParams: {
        'lat': p.latitude.toString(),
        'lng': p.longitude.toString(),
      });
      setState(() {
        _address = (data['address'] as String?) ?? '';
        _searchController.text = _address;
        _suggestions = [];
      });
      _report();
    } catch (_) {
      setState(() => _error = 'Address lookup failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    // Debounce — Nominatim allows ~1 req/sec.
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final list = await ref
            .read(apiClientProvider)
            .getList('/geocode/search', queryParams: {'q': q.trim()});
        if (mounted) {
          setState(() => _suggestions = list.cast<Map<String, dynamic>>());
        }
      } catch (_) {/* ignore transient search errors */}
    });
  }

  void _selectSuggestion(Map<String, dynamic> s) {
    setState(() {
      _pin = LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble());
      _address = s['label'] as String;
      _searchController.text = _address;
      _suggestions = [];
    });
    _mapController.move(_pin, 15);
    _report();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location is off — turn on GPS.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission denied.';
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _pin = LatLng(pos.latitude, pos.longitude));
      _mapController.move(_pin, 16);
      await _reverse(_pin);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search your address',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 190),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in _suggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, size: 18),
                    title: Text(s['label'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                    onTap: () => _selectSuggestion(s),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _useCurrentLocation,
          icon: const Icon(Icons.my_location),
          label: const Text('Use current location'),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pin,
                initialZoom: 15,
                onTap: (_, latlng) {
                  setState(() => _pin = latlng);
                  _reverse(latlng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.homely.customer_app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: _pin,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_pin,
                        color: Colors.red, size: 40),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Tap the map to set your exact spot',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ),
      ],
    );
  }
}
