import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared/shared.dart';

import '../providers/kitchen_provider.dart';
import '../providers/menu_provider.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(menuItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const _AddDishScreen()),
          );
          if (added == true) ref.invalidate(menuItemsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Dish'),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load menu: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('No dishes yet. Tap "Add Dish" to create one.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(menuItemsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _DishTile(
                item: items[i],
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => _EditDishScreen(item: items[i]),
                    ),
                  );
                  if (changed == true) ref.invalidate(menuItemsProvider);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DishTile extends StatelessWidget {
  const _DishTile({required this.item, this.onTap});
  final MenuItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.photoUrl != null
              ? Image.network(item.photoUrl!,
                  width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _PhotoFallback())
              : const _PhotoFallback(),
        ),
        title: Text(item.name),
        subtitle: Text(
          '₹${(item.pricePaise / 100).toStringAsFixed(0)}'
          '${item.isActive ? '' : '  ·  inactive'}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();
  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        color: Colors.grey.shade200,
        child: const Icon(Icons.restaurant, color: Colors.grey),
      );
}

const _prefLabels = <String, String>{
  'less_spicy': 'Less spicy',
  'normal_spicy': 'Normal spicy',
  'extra_spicy': 'Extra spicy',
  'no_onion': 'No onion',
  'no_garlic': 'No garlic',
  'less_oil': 'Less oil',
  'extra_rice': 'Extra rice',
};

/// Edit an existing dish: name, price, today's plates, preference toggles;
/// or remove it (DELETE deactivates).
class _EditDishScreen extends ConsumerStatefulWidget {
  const _EditDishScreen({required this.item});
  final MenuItem item;

  @override
  ConsumerState<_EditDishScreen> createState() => _EditDishScreenState();
}

class _EditDishScreenState extends ConsumerState<_EditDishScreen> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _price =
      TextEditingController(text: (widget.item.pricePaise ~/ 100).toString());
  final _plates = TextEditingController();
  late final Set<String> _prefs =
      widget.item.preferences.map((p) => p.preference).toSet();
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _plates.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final rupees = int.tryParse(_price.text.trim());
    if (name.isEmpty) return setState(() => _error = 'Dish name is required');
    if (rupees == null || rupees <= 0) {
      return setState(() => _error = 'Enter a valid price');
    }
    if (rupees > 200) return setState(() => _error = 'Price cannot exceed ₹200');

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final id = widget.item.id;
      await api.patch('/menu/items/$id',
          body: {'name': name, 'pricePaise': rupees * 100});
      await api.put('/menu/items/$id/preferences',
          body: {'preferences': _prefs.toList()});
      final plates = int.tryParse(_plates.text.trim());
      if (plates != null && plates >= 0) {
        await api.put('/menu/items/$id/availability',
            body: {'serviceDate': _todayStr(), 'platesTotal': plates});
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove dish?'),
        content: Text('"${widget.item.name}" will be removed from your menu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).delete('/menu/items/${widget.item.id}');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Failed to remove: $e';
        _deleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Dish')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Dish Name *'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Price (₹) *', prefixText: '₹ ', helperText: 'Max ₹200'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _plates,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: "Update today's plates (optional)"),
          ),
          const SizedBox(height: 24),
          Text('Preferences offered',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _prefLabels.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: _prefs.contains(entry.key),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _prefs.add(entry.key);
                    } else {
                      _prefs.remove(entry.key);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: busy ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Changes'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove Dish'),
            style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
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

/// Full-screen form to create a dish: name, price, today's plates, photo.
class _AddDishScreen extends ConsumerStatefulWidget {
  const _AddDishScreen();

  @override
  ConsumerState<_AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends ConsumerState<_AddDishScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _platesController = TextEditingController(text: '10');
  final _picker = ImagePicker();
  XFile? _photo;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _platesController.dispose();
    super.dispose();
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickPhoto() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final rupees = int.tryParse(_priceController.text.trim());
    final plates = int.tryParse(_platesController.text.trim());

    if (name.isEmpty) return setState(() => _error = 'Dish name is required');
    if (rupees == null || rupees <= 0) {
      return setState(() => _error = 'Enter a valid price');
    }
    if (rupees > 200) {
      return setState(() => _error = 'Price cannot exceed ₹200 per dish');
    }
    if (plates == null || plates < 0) {
      return setState(() => _error = 'Enter a valid plate count');
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      // 1. Create the item (price stored in paise).
      final item = await api.post('/menu/items', body: {
        'name': name,
        'pricePaise': rupees * 100,
      });
      final id = item['id'] as String;

      // 2. Upload the photo, if chosen.
      if (_photo != null) {
        await api.postMultipart('/menu/items/$id/photo', files: {
          'photo': [_photo!.path],
        });
      }

      // 3. Set today's plate count (the "quantity").
      await api.put('/menu/items/$id/availability', body: {
        'serviceDate': _todayStr(),
        'platesTotal': plates,
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Failed to add dish: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Dish')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: _photo == null
                  ? Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: const Icon(Icons.add_a_photo,
                          color: Colors.grey, size: 32),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_photo!.path),
                          width: 120, height: 120, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('Dish photo (optional)')),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Dish Name *'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price (₹) *',
              prefixText: '₹ ',
              helperText: 'Max ₹200 per dish',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _platesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Plates available today *',
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Dish'),
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
