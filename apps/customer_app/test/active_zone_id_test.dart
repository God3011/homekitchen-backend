import 'package:customer_app/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

// Fix #2: kitchen_list_viewed / kitchen_profile_viewed / search_performed must
// stamp the customer's real active zone id, not a hardcoded ''. All three read
// it from `activeZoneIdProvider`, so this pins that source: the home zone when
// known, and '' (never null) when the profile is absent or has no zone.
Customer _customer({String? homeZoneId}) => Customer(
      id: 'c1',
      phone: '+919999999999',
      homeZoneId: homeZoneId,
      createdAt: DateTime.parse('2026-07-20T07:00:00.000Z'),
    );

Future<String> _resolveZoneId(Customer? profile) async {
  final container = ProviderContainer(overrides: [
    customerProfileProvider.overrideWith((ref) async => profile),
  ]);
  addTearDown(container.dispose);
  // Let the overridden FutureProvider resolve so valueOrNull is populated.
  await container.read(customerProfileProvider.future);
  return container.read(activeZoneIdProvider);
}

void main() {
  test('activeZoneIdProvider returns the customer home zone id', () async {
    expect(await _resolveZoneId(_customer(homeZoneId: 'zone_gachibowli')),
        'zone_gachibowli');
  });

  test('activeZoneIdProvider falls back to empty when zone is null', () async {
    expect(await _resolveZoneId(_customer(homeZoneId: null)), '');
  });

  test('activeZoneIdProvider falls back to empty when there is no profile',
      () async {
    expect(await _resolveZoneId(null), '');
  });
}
