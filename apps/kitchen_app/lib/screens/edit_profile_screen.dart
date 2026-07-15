import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/auth_provider.dart';
import '../providers/kitchen_provider.dart';
import '../widgets/address_picker.dart';

/// Edit the kitchen's text profile fields (PATCH /kitchens/me).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.kitchen});
  final Kitchen kitchen;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final _kitchenName =
      TextEditingController(text: widget.kitchen.kitchenName);
  late final _cookName =
      TextEditingController(text: widget.kitchen.cookName ?? '');
  late final _signatureDish =
      TextEditingController(text: widget.kitchen.signatureDish ?? '');
  late final _story = TextEditingController(text: widget.kitchen.story ?? '');
  AddressResult? _addr;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _kitchenName.dispose();
    _cookName.dispose();
    _signatureDish.dispose();
    _story.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _kitchenName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Kitchen name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).patch('/kitchens/me', body: {
        'kitchenName': name,
        'cookName': _cookName.text.trim(),
        'signatureDish': _signatureDish.text.trim(),
        'story': _story.text.trim(),
        if (_addr != null) ...{
          'addressLine': _addr!.address,
          'lat': _addr!.lat,
          'lng': _addr!.lng,
        },
      });
      ref.invalidate(kitchenProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _field(_kitchenName, 'Kitchen Name *'),
          _field(_cookName, 'Your Name'),
          _field(_signatureDish, 'Signature Dish'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child:
                Text('Address', style: Theme.of(context).textTheme.titleSmall),
          ),
          AddressPicker(
            initialLat: widget.kitchen.lat,
            initialLng: widget.kitchen.lng,
            initialAddress: widget.kitchen.addressLine,
            onChanged: (r) => setState(() => _addr = r),
          ),
          const SizedBox(height: 16),
          _field(_story, 'Your Story', maxLines: 3),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
          ],
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: label),
        ),
      );
}
