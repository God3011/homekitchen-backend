import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared/shared.dart';

import '../providers/auth_provider.dart';
import '../providers/kitchen_provider.dart';

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
  
  final _picker = ImagePicker();
  XFile? _newCookPhoto;
  late final List<String> _existingKitchenPhotos =
      List.from(widget.kitchen.kitchenPhotoUrls);
  final List<XFile> _newKitchenPhotos = [];

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
      final api = ref.read(apiClientProvider);

      // Upload new cook photo if picked
      String? cookPhotoUrl = widget.kitchen.cookPhotoUrl;
      if (_newCookPhoto != null) {
        final res = await api.postMultipart('/kitchens/me/upload-photo',
            files: {'photo': [_newCookPhoto!.path]});
        cookPhotoUrl = res['photoUrl'] as String?;
      }

      // Upload new kitchen photos
      final allKitchenPhotos = [..._existingKitchenPhotos];
      for (final f in _newKitchenPhotos) {
        final res = await api.postMultipart('/kitchens/me/upload-photo',
            files: {'photo': [f.path]});
        if (res['photoUrl'] != null) {
          allKitchenPhotos.add(res['photoUrl'] as String);
        }
      }

      await api.patch('/kitchens/me', body: {
        'kitchenName': name,
        'cookName': _cookName.text.trim(),
        'cookPhotoUrl': cookPhotoUrl,
        'kitchenPhotoUrls': allKitchenPhotos,
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
          Center(
            child: GestureDetector(
              onTap: () async {
                final picked = await _picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 80);
                if (picked != null) setState(() => _newCookPhoto = picked);
              },
              child: CircleAvatar(
                radius: 40,
                backgroundColor: HomelyColors.surface,
                backgroundImage: _newCookPhoto != null
                    ? FileImage(File(_newCookPhoto!.path))
                    : (widget.kitchen.cookPhotoUrl != null
                        ? NetworkImage(widget.kitchen.cookPhotoUrl!)
                        : null) as ImageProvider?,
                child: (_newCookPhoto == null &&
                        widget.kitchen.cookPhotoUrl == null)
                    ? const Icon(Icons.add_a_photo,
                        color: HomelyColors.inkFaint)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
              child: Text('Cook Photo',
                  style: TextStyle(color: HomelyColors.inkFaint, fontSize: 12))),
          const SizedBox(height: 24),

          _field(_kitchenName, 'Kitchen Name *'),
          _field(_cookName, 'Your Name'),

          Text('Banner Photos', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final url in _existingKitchenPhotos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(url,
                              width: 120, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => setState(
                                () => _existingKitchenPhotos.remove(url)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.close,
                                  size: 16, color: HomelyColors.danger),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final f in _newKitchenPhotos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(f.path),
                              width: 120, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _newKitchenPhotos.remove(f)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.close,
                                  size: 16, color: HomelyColors.danger),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                InkWell(
                  onTap: () async {
                    final picked = await _picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 80);
                    if (picked != null) {
                      setState(() => _newKitchenPhotos.add(picked));
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: HomelyColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HomelyColors.surfaceAlt),
                    ),
                    child: const Icon(Icons.add_a_photo,
                        color: HomelyColors.inkFaint),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _field(_signatureDish, 'Signature Dish'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child:
                Text('Address', style: Theme.of(context).textTheme.titleSmall),
          ),
          AddressPicker(
            api: ref.read(apiClientProvider),
            userAgentPackageName: 'com.homely.kitchen_app',
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
