import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('No profile found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: HomelyColors.blueTint,
                      child: Text(
                        (customer.name?.isNotEmpty ?? false)
                            ? customer.name![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: HomelyColors.blueDeep),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(customer.name ?? 'Add your name',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(customer.phone,
                        style: const TextStyle(color: HomelyColors.inkFaint)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(customer.name ?? 'Add your name'),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => _editName(context, ref, customer),
              ),
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(customer.homeZoneName ?? 'Home zone not set'),
                subtitle: const Text('Home area'),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const _EditLocationScreen(),
                )),
              ),
              const Divider(height: 32),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomelyColors.danger,
                  side: const BorderSide(color: HomelyColors.danger),
                ),
                onPressed: () async {
                  // Unregister the FCM token while still authenticated.
                  await unregisterDeviceToken(ref.read(apiClientProvider));
                  await ref.read(authServiceProvider).signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load profile.')),
      ),
    );
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, Customer customer) async {
    final controller = TextEditingController(text: customer.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    try {
      await ref
          .read(apiClientProvider)
          .patch('/customers/me', body: {'name': newName});
      ref.invalidate(customerProfileProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update name.')));
      }
    }
  }
}

/// Update the customer's home location (re-resolves their home zone server-side).
class _EditLocationScreen extends ConsumerStatefulWidget {
  const _EditLocationScreen();

  @override
  ConsumerState<_EditLocationScreen> createState() =>
      _EditLocationScreenState();
}

class _EditLocationScreenState extends ConsumerState<_EditLocationScreen> {
  AddressResult? _addr;
  bool _saving = false;

  Future<void> _save() async {
    if (_addr == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).patch('/customers/me', body: {
        'lat': _addr!.lat,
        'lng': _addr!.lng,
      });
      ref.invalidate(customerProfileProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update location.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home location')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AddressPicker(
            api: ref.read(apiClientProvider),
            userAgentPackageName: 'com.homely.customer_app',
            onChanged: (r) => setState(() => _addr = r),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_addr == null || _saving) ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save location'),
          ),
        ],
      ),
    );
  }
}
