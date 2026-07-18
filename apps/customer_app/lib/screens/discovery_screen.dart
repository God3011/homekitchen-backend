import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../models/discovery_result.dart';
import '../providers/api_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/kitchen_card.dart';
import 'kitchen_detail_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  String _query = '';

  List<DiscoveryKitchen> _filter(List<DiscoveryKitchen> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((k) {
      return k.kitchenName.toLowerCase().contains(q) ||
          (k.signatureDish?.toLowerCase().contains(q) ?? false) ||
          (k.cookName?.toLowerCase().contains(q) ?? false);
    }).toList();
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
      appBar: AppBar(title: const Text('Kitchens near you')),
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
                  child: TextField(
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
                                  const EdgeInsets.symmetric(horizontal: 12),
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
            hasQuery ? 'No kitchens match your search.' : 'No kitchens nearby.',
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
