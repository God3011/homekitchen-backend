import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_address.dart';
import '../providers/addresses_provider.dart';
import 'address_form_screen.dart';

/// Manage saved locations: set the active one (tap), add, edit, delete. The
/// active location is the centre discovery searches around, app-wide.
class AddressManagementScreen extends ConsumerWidget {
  const AddressManagementScreen({super.key});

  Future<void> _add(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddressFormScreen()),
    );
  }

  Future<void> _edit(BuildContext context, CustomerAddress a) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddressFormScreen(existing: a)),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CustomerAddress a,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete location?'),
        content: Text(
          a.isDefault
              ? '"${a.label}" is your active location. Deleting it will switch '
                  'discovery to another saved location.'
              : 'Remove "${a.label}" from your saved locations?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await deleteAddress(ref, a.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Try again.')),
        );
      }
    }
  }

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    CustomerAddress a,
  ) async {
    if (a.isDefault) return;
    try {
      await setActiveAddress(ref, a.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not switch location. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved locations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(addressesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _ErrorState(
            onRetry: () => ref.invalidate(addressesProvider),
          ),
          data: (addresses) {
            if (addresses.isEmpty) return const _EmptyState();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: addresses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = addresses[i];
                return _AddressTile(
                  address: a,
                  onTap: () => _setActive(context, ref, a),
                  onEdit: () => _edit(context, a),
                  onDelete: () => _delete(context, ref, a),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomerAddress address;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = address.isDefault;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: active
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          active ? Icons.location_on : Icons.location_on_outlined,
          color: active ? theme.colorScheme.primary : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                address.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: (address.addressLine != null &&
                address.addressLine!.isNotEmpty)
            ? Text(
                address.addressLine!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: PopupMenuButton<String>(
          onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.location_off_outlined, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'No saved locations yet.\nAdd one to choose where you discover kitchens.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Center(child: Text('Could not load saved locations.')),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
