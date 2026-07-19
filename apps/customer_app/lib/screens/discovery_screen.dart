import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../models/discovery_result.dart';
import '../providers/addresses_provider.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/kitchen_card.dart';
import 'address_management_screen.dart';
import 'kitchen_detail_screen.dart';
import 'profile_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _vegOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DiscoveryKitchen> _filter(List<DiscoveryKitchen> all) {
    Iterable<DiscoveryKitchen> out = all;
    // Veg-only keeps kitchens that have at least one orderable veg plate today.
    if (_vegOnly) out = out.where((k) => k.hasVeg);
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((k) {
        return k.kitchenName.toLowerCase().contains(q) ||
            (k.signatureDish?.toLowerCase().contains(q) ?? false) ||
            (k.cookName?.toLowerCase().contains(q) ?? false) ||
            k.todayDishNames.any((d) => d.toLowerCase().contains(q));
      });
    }
    return out.toList();
  }

  void _onCategoryTap(String term) {
    setState(() {
      // Tapping the active category clears it (toggle behaviour).
      if (_query.trim().toLowerCase() == term.toLowerCase()) {
        _query = '';
        _searchController.clear();
      } else {
        _query = term;
        _searchController.text = term;
      }
    });
  }

  void _openKitchen(DiscoveryKitchen k) {
    trackEvent('kitchen_profile_viewed', {'kitchen_id': k.id, 'zone_id': ''});
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => KitchenDetailScreen(
        kitchenId: k.id,
        serviceable: k.serviceable,
        dormantReason: k.dormantReason,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(discoveryProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: const _ActiveAddressButton(),
        actions: const [_ProfileAvatarButton(), SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(discoveryLocationProvider);
          ref.invalidate(discoveryProvider);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            onRetry: () => ref.invalidate(discoveryProvider),
          ),
          data: (result) {
            if (result.isNoneInRadius) {
              return _NotServingArea(result: result);
            }
            final kitchens = _filter(result.kitchens);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search kitchens or dishes',
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _query = v),
                          onSubmitted: (v) => trackEvent('search_performed', {
                            'query': v.trim(),
                            'zone_id': '',
                            'result_count': _filter(result.kitchens).length,
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      VegOnlyToggle(
                        value: _vegOnly,
                        onChanged: (v) => setState(() => _vegOnly = v),
                      ),
                    ],
                  ),
                ),
                _CategoryRail(
                  selected: _query.trim(),
                  onSelected: _onCategoryTap,
                ),
                if (result.isDormantOnly)
                  const _Banner(
                    text:
                        'No kitchens are serving right now. Here\'s who\'s nearby — check back soon.',
                  ),
                Expanded(
                  child: kitchens.isEmpty
                      ? _EmptyState(hasQuery: _query.trim().isNotEmpty)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: kitchens.length,
                          itemBuilder: (_, i) {
                            final k = kitchens[i];
                            return Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 14),
                              child: KitchenCard(
                                kitchen: k,
                                onTap: () => _openKitchen(k),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Top-left header entry: the active saved location's label with a pin +
/// chevron, tappable to open Saved locations. Shows "Set location" when none.
class _ActiveAddressButton extends ConsumerWidget {
  const _ActiveAddressButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeAddressProvider);
    final label = active?.label ?? 'Set location';
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddressManagementScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Searching near',
                      style: TextStyle(
                          fontSize: 10,
                          color: theme.textTheme.bodySmall?.color)),
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Top-right header entry: a compact avatar that opens the profile section.
class _ProfileAvatarButton extends ConsumerWidget {
  const _ProfileAvatarButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(customerProfileProvider).valueOrNull?.name;
    final initial =
        (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?';
    final theme = Theme.of(context);

    return IconButton(
      tooltip: 'Profile',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, color: Colors.orange))),
        ],
      ),
    );
  }
}

/// "Not serving your area yet" + interest capture (POST /service-interest).
class _NotServingArea extends ConsumerStatefulWidget {
  const _NotServingArea({required this.result});
  final DiscoveryResult result;

  @override
  ConsumerState<_NotServingArea> createState() => _NotServingAreaState();
}

class _NotServingAreaState extends ConsumerState<_NotServingArea> {
  bool _submitting = false;
  bool _done = false;

  Future<void> _register() async {
    final phone = await showDialog<String>(
      context: context,
      builder: (_) => const _PhonePromptDialog(),
    );
    if (phone == null) return; // cancelled
    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).post('/service-interest', body: {
        'lat': widget.result.lat,
        'lng': widget.result.lng,
        if (phone.isNotEmpty) 'phone': phone,
      });
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not register interest. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "We're not serving your area yet.\nLeave your interest and we'll expand toward you.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: _done
              ? const Center(
                  child: Text('Thanks! We\'ll be in touch. 🙏',
                      style: TextStyle(fontWeight: FontWeight.w600)))
              : ElevatedButton.icon(
                  onPressed: _submitting ? null : _register,
                  icon: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.notifications_active_outlined),
                  label: const Text('Notify me when you launch here'),
                ),
        ),
      ],
    );
  }
}

class _PhonePromptDialog extends StatefulWidget {
  const _PhonePromptDialog();
  @override
  State<_PhonePromptDialog> createState() => _PhonePromptDialogState();
}

class _PhonePromptDialogState extends State<_PhonePromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stay in the loop'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          prefixText: '+91 ',
          hintText: 'Phone (optional)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: () {
            final p = _controller.text.trim();
            Navigator.pop(context, p.isEmpty ? '' : (p.startsWith('+') ? p : '+91$p'));
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.no_meals, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Center(
          child: Text(
            hasQuery ? 'No kitchens or dishes match your search.' : 'No kitchens nearby.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
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
        const Center(child: Text('Could not load kitchens.')),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}

/// Horizontal quick-filter rail of food categories, laid out right-to-left.
/// Tapping a tile sets the search query; tapping the active one clears it.
/// (Image tiles use branded placeholders until real category art is added.)
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static const _cats = <_Cat>[
    _Cat('Thali', Icons.dinner_dining, Color(0xFFE8A33D)),
    _Cat('Biryani', Icons.rice_bowl, Color(0xFFB4472F)),
    _Cat('Tiffins', Icons.bakery_dining, Color(0xFF6FB7C7)),
    _Cat('Meals', Icons.restaurant, Color(0xFF7FA88C)),
    _Cat('Curries', Icons.soup_kitchen, Color(0xFFC6841D)),
    _Cat('Sweets', Icons.cake, Color(0xFFD98BA0)),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        // Right-to-left: first tile sits at the right edge, scrolls leftward.
        reverse: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        itemCount: _cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final c = _cats[i];
          final on = selected.toLowerCase() == c.label.toLowerCase();
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(c.label),
            child: SizedBox(
              width: 104,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 58,
                      width: 104,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [c.color.withValues(alpha: 0.85), c.color],
                        ),
                        border: on
                            ? Border.all(
                                color: const Color(0xFF2E2420), width: 2)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(c.icon, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(c.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              on ? FontWeight.w800 : FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Cat {
  const _Cat(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}
