import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared/shared.dart';

import '../providers/auth_provider.dart';
import '../providers/kitchen_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _cookNameController = TextEditingController();
  final _picker = ImagePicker();

  final List<XFile> _kitchenPhotos = [];
  XFile? _selfPhoto;
  AddressResult? _addr;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _cookNameController.dispose();
    super.dispose();
  }

  Future<void> _pickKitchenPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() => _kitchenPhotos.addAll(picked));
    }
  }

  Future<void> _pickSelfPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _selfPhoto = picked);
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Kitchen name is required');
      return;
    }
    if (_kitchenPhotos.isEmpty) {
      setState(() => _error = 'Add at least one photo of your kitchen');
      return;
    }
    if (_selfPhoto == null) {
      setState(() => _error = 'Add a photo of yourself');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final fields = <String, String>{'kitchenName': name};
      final cookName = _cookNameController.text.trim();
      if (cookName.isNotEmpty) fields['cookName'] = cookName;
      if (_addr != null) {
        if (_addr!.address.isNotEmpty) fields['addressLine'] = _addr!.address;
        fields['lat'] = _addr!.lat.toString();
        fields['lng'] = _addr!.lng.toString();
      }

      final result = await api.postMultipart(
        '/kitchens/signup',
        fields: fields,
        files: {
          'kitchenPhotos': _kitchenPhotos.map((x) => x.path).toList(),
          'selfPhoto': [_selfPhoto!.path],
        },
      );

      trackEvent('seller_signup_completed', {
        'kitchen_id': result['id'] as String,
        'zone_id': result['zoneId']?.toString() ?? '',
      });

      // Refresh the profile so the auth gate navigates to home.
      ref.invalidate(kitchenProfileProvider);
    } catch (e, s) {
      debugPrint('Signup error: $e');
      debugPrint('Stack: $s');
      setState(() {
        _error = 'Signup failed: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Kitchen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Welcome! Let\'s get your kitchen listed.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Kitchen Name *'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cookNameController,
            decoration: const InputDecoration(labelText: 'Your Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),

          // --- Address ---
          Text('Address', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          AddressPicker(
            api: ref.read(apiClientProvider),
            userAgentPackageName: 'com.homely.kitchen_app',
            onChanged: (r) => setState(() => _addr = r),
          ),
          const SizedBox(height: 24),

          // --- Kitchen photos (multiple, required) ---
          Text('Photos of your kitchen *',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _PhotoRow(
            photos: _kitchenPhotos,
            onAdd: _pickKitchenPhotos,
            onRemove: (i) => setState(() => _kitchenPhotos.removeAt(i)),
          ),
          const SizedBox(height: 24),

          // --- Self photo (single, required) ---
          Text('Photo of yourself *',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _SelfPhoto(
            photo: _selfPhoto,
            onPick: _pickSelfPhoto,
            onRemove: () => setState(() => _selfPhoto = null),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create Kitchen'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}

/// Horizontal strip of kitchen-photo thumbnails plus an "add" tile.
class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> photos;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < photos.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(photos[i].path),
                        width: 96, height: 96, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => onRemove(i),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: const Icon(Icons.add_a_photo, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single circular self-photo picker.
class _SelfPhoto extends StatelessWidget {
  const _SelfPhoto({
    required this.photo,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey),
          ),
          child: const Icon(Icons.person_add_alt_1, color: Colors.grey),
        ),
      );
    }
    return Stack(
      children: [
        CircleAvatar(radius: 48, backgroundImage: FileImage(File(photo!.path))),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
