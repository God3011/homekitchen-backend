import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/kitchen_provider.dart';
import '../services/push_service.dart';
import 'documents_screen.dart';
import 'edit_profile_screen.dart';
import 'operating_hours_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(kitchenProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load profile: $e')),
        data: (k) {
          if (k == null) {
            return const Center(child: Text('No profile found.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(kitchenProfileProvider),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: k.cookPhotoUrl != null
                        ? NetworkImage(k.cookPhotoUrl!)
                        : null,
                    child: k.cookPhotoUrl == null
                        ? const Icon(Icons.person, size: 48, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(k.kitchenName,
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                if (k.cookName != null)
                  Center(
                    child: Text(k.cookName!,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                const SizedBox(height: 8),
                Center(child: _StatusChip(status: k.status)),
                const SizedBox(height: 24),
                _InfoRow(label: 'Phone', value: k.phone),
                if (k.addressLine != null)
                  _InfoRow(label: 'Address', value: k.addressLine!),
                if (k.story != null && k.story!.isNotEmpty)
                  _InfoRow(label: 'Story', value: k.story!),
                const SizedBox(height: 24),
                if (k.kitchenPhotoUrls.isNotEmpty) ...[
                  Text('Kitchen photos',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: k.kitchenPhotoUrls.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(k.kitchenPhotoUrls[i],
                            width: 110, height: 110, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],
                const Divider(height: 40),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(kitchen: k),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Operating Hours'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OperatingHoursScreen(),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Verification Documents'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DocumentsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    // Remove the FCM token before signing out (still authed here).
                    await unregisterDeviceToken(ref.read(apiClientProvider));
                    await ref.read(authServiceProvider).signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final verified = status == 'verified';
    return Chip(
      backgroundColor: verified ? Colors.green.shade100 : Colors.orange.shade100,
      label: Text(status.replaceAll('_', ' ')),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
