import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'package:customer_app/providers/orders_provider.dart';
import 'package:customer_app/screens/order_tracking_screen.dart';

Order _order(OrderStatus status) => Order(
      id: 'order-abcd4821',
      customerId: 'c1',
      kitchenId: 'k1',
      fulfillment: 'pickup',
      status: status,
      foodTotalPaise: 42000,
      platformFeePaise: 500,
      deliveryFeePaise: 0,
      grandTotalPaise: 42500,
      handoverCode: '4821',
      etaMinutes: 25,
      placedAt: DateTime.now(),
      acceptedAt: DateTime.now(),
      items: const [
        OrderItem(
          id: 'i1',
          menuItemId: 'm1',
          itemName: 'Andhra Veg Thali',
          unitPricePaise: 18000,
          quantity: 1,
        ),
      ],
      payment: const Payment(id: 'p1', amountPaise: 42500, status: 'captured'),
      kitchen: Kitchen(
        id: 'k1',
        kitchenName: "Lakshmi's Kitchen",
        phone: '+919000000000',
        status: 'verified',
        addressLine: 'Gachibowli, Hyderabad',
        // lat/lng left null so the test doesn't hit the live OSM tile server.
        createdAt: DateTime.now(),
      ),
    );

Future<void> _pump(WidgetTester tester, OrderStatus status) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      orderProvider('order-abcd4821')
          .overrideWith((ref) async => _order(status)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const OrderTrackingScreen(orderId: 'order-abcd4821'),
    ),
  ));
  // Resolve the future + a couple frames (don't pumpAndSettle — a 15s poll
  // timer never settles).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(tester.takeException(), isNull);
  handle.dispose();
}

void main() {
  testWidgets('tracking renders for a just-placed (received) order',
      (tester) async {
    await _pump(tester, OrderStatus.received);
  });

  testWidgets('tracking renders for preparing / ready / completed',
      (tester) async {
    await _pump(tester, OrderStatus.preparing);
    await _pump(tester, OrderStatus.ready);
    await _pump(tester, OrderStatus.completed);
  });
}
