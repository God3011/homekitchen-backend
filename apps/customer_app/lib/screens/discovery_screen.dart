import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/discovery_provider.dart';
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
    final result = all.where((k) {
      return k.kitchenName.toLowerCase().contains(q) ||
          (k.signatureDish?.toLowerCase().contains(q) ?? false) ||
          (k.cookName?.toLowerCase().contains(q) ?? false);
    }).toList();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final kitchensAsync = ref.watch(kitchensProvider);
    final openNow = ref.watch(openNowFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchens near you'),
      ),
      body: Column(
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
              onSubmitted: (v) {
                final count = _filter(kitchensAsync.valueOrNull ?? []).length;
                trackEvent('search_performed', {
                  'query': v.trim(),
                  'zone_id': '',
                  'result_count': count,
                });
              },
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilterChip(
                label: const Text('Open now'),
                selected: openNow,
                onSelected: (v) =>
                    ref.read(openNowFilterProvider.notifier).state = v,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(kitchensProvider),
              child: kitchensAsync.when(
                data: (all) {
                  final kitchens = _filter(all);
                  if (kitchens.isEmpty) {
                    return _EmptyState(
                      hasQuery: _query.trim().isNotEmpty || openNow,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: kitchens.length,
                    itemBuilder: (_, i) {
                      final k = kitchens[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: KitchenCard(
                          kitchen: k,
                          onTap: () {
                            trackEvent('kitchen_profile_viewed', {
                              'kitchen_id': k.id,
                              'zone_id': '',
                            });
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  KitchenDetailScreen(kitchenId: k.id),
                            ));
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  onRetry: () => ref.invalidate(kitchensProvider),
                ),
              ),
            ),
          ),
        ],
      ),
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
            hasQuery
                ? 'No kitchens match your search.'
                : 'No kitchens are cooking near you right now.\nCheck back around lunch or dinner!',
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
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
