import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_address.dart';
import '../providers/addresses_provider.dart';
import '../widgets/address_picker.dart';

/// Add or edit a saved location. Fields: a required label ("Home"/"Office"/…),
/// an optional display line, and a location picked via the OSM pin-drop picker.
/// lat/lng (from the picker) is the source of truth — the typed text is only a
/// label. Delivery is never involved; this just sets a discovery search centre.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.existing});

  /// When non-null, the form edits this saved location instead of creating one.
  final CustomerAddress? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _labelController = TextEditingController();
  final _addressLineController = TextEditingController();

  double? _lat;
  double? _lng;
  bool _makeActive = true;
  bool _addressLineEdited = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _labelController.text = e.label;
      _addressLineController.text = e.addressLine ?? '';
      _lat = e.lat;
      _lng = e.lng;
      _makeActive = e.isDefault;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressLineController.dispose();
    super.dispose();
  }

  void _onLocationChanged(AddressResult r) {
    setState(() {
      _lat = r.lat;
      _lng = r.lng;
      // Prefill the display line from the reverse-geocode until the user edits it.
      if (!_addressLineEdited && r.address.isNotEmpty) {
        _addressLineController.text = r.address;
      }
    });
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Give this place a name (e.g. Home, Office).');
      return;
    }
    if (_lat == null || _lng == null) {
      setState(() => _error = 'Pick a location on the map.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final addressLine = _addressLineController.text.trim();
      if (widget.isEditing) {
        await updateAddress(
          ref,
          widget.existing!.id,
          label: label,
          addressLine: addressLine,
          lat: _lat,
          lng: _lng,
        );
      } else {
        await addAddress(
          ref,
          label: label,
          addressLine: addressLine,
          lat: _lat!,
          lng: _lng!,
          isActive: _makeActive,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit location' : 'Add location'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _labelController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'Home, Office, Hostel…',
              prefixIcon: Icon(Icons.bookmark_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressLineController,
            onChanged: (_) => _addressLineEdited = true,
            decoration: const InputDecoration(
              labelText: 'Address (optional)',
              hintText: 'Landmark or flat/door number',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Text('Location', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          AddressPicker(
            initialLat: _lat,
            initialLng: _lng,
            initialAddress: widget.existing?.addressLine,
            onChanged: _onLocationChanged,
          ),
          if (!widget.isEditing) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Make this my active location'),
              subtitle: const Text('Discovery will search around here'),
              value: _makeActive,
              onChanged: (v) => setState(() => _makeActive = v),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.isEditing ? 'Save changes' : 'Save location'),
          ),
        ],
      ),
    );
  }
}
