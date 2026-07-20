import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'package:kitchen_app/providers/kitchen_provider.dart';
import 'package:kitchen_app/screens/menu_screen.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');

  Map<String, dynamic> _daily() => {
        'serviceDate': _todayStr(),
        'readOnly': false,
        'dishes': [
          {
            'menuItemId': 'dish-on',
            'name': 'Biryani',
            'pricePaise': 15000,
            'isVeg': false,
            'onMenu': true,
            'platesTotal': 10,
            'platesRemaining': 6,
            'isAvailable': true,
          },
          {
            'menuItemId': 'dish-1',
            'name': 'Test Dosa',
            'pricePaise': 8000,
            'isVeg': true,
            'onMenu': false,
            'platesTotal': 0,
            'platesRemaining': 0,
            'isAvailable': false,
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> get(String path,
          {Map<String, String>? queryParams}) async =>
      _daily();
}

String _todayStr() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

void main() {
  testWidgets('Menu tab builds without semantics assertion', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(_FakeApi())],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: const MenuScreen(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 1,
            onDestinationSelected: (_) {},
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.restaurant_menu), label: 'Menu'),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
