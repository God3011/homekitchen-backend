import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

// Regression: the backend's OrderItemPreference has a composite PK
// (orderItemId, preference) and no `id`. Parsing an order that carries item
// preferences must not throw "type 'Null' is not a subtype of type 'String'".
void main() {
  test('Order.fromJson parses item preferences that have no id', () {
    final json = <String, dynamic>{
      'id': 'o1',
      'customerId': 'c1',
      'kitchenId': 'k1',
      'fulfillment': 'pickup',
      'status': 'received',
      'foodTotalPaise': 18000,
      'platformFeePaise': 500,
      'deliveryFeePaise': 0,
      'grandTotalPaise': 18500,
      'placedAt': '2026-07-20T07:00:00.000Z',
      'items': [
        {
          'id': 'i1',
          'menuItemId': 'm1',
          'itemName': 'Chicken Rice',
          'unitPricePaise': 18000,
          'quantity': 1,
          'preferences': [
            // Exactly what the backend sends — no 'id'.
            {'orderItemId': 'i1', 'preference': 'less_spicy'},
          ],
        },
      ],
    };

    final order = Order.fromJson(json);
    final pref = order.items.single.preferences.single;
    expect(pref.preference, 'less_spicy');
    expect(pref.id, isNull);
  });
}
