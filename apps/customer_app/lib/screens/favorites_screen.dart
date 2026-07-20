import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/favorites_provider.dart';
import '../widgets/kitchen_card.dart';
import 'kitchen_detail_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(favoritesProvider),
        child: favoritesAsync.when(
          data: (favorites) {
            if (favorites.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.favorite_border,
                      size: 64, color: HomelyColors.inkFaint),
                  SizedBox(height: 16),
                  Center(
                      child: Text(
                          'No favorites yet.\nTap the heart on a kitchen to save it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: HomelyColors.inkSoft))),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: favorites.length,
              itemBuilder: (_, i) {
                final k = favorites[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: KitchenCard(
                    kitchen: k,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => KitchenDetailScreen(kitchenId: k.id),
                    )),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              const Center(child: Text('Could not load favorites.')),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(favoritesProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
