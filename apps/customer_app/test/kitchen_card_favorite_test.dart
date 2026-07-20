import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'package:customer_app/providers/favorites_provider.dart';
import 'package:customer_app/widgets/kitchen_card.dart';

Widget _app(Set<String> favs) => ProviderScope(
      overrides: [favoriteIdsProvider.overrideWith((ref) async => favs)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: KitchenCard(
            kitchen: const DiscoveryKitchen(
                id: 'k1', kitchenName: 'Test Kitchen', serviceable: true),
            onTap: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('heart is outlined when the kitchen is not a favourite',
      (tester) async {
    await tester.pumpWidget(_app(const {}));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('heart is filled (red) when the kitchen is a favourite',
      (tester) async {
    await tester.pumpWidget(_app(const {'k1'}));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });
}
