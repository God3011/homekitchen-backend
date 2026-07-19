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
            'photoUrl': 'https://r2.test/biryani.jpg', // forces Image.network
            'onMenu': true,
            'platesTotal': 10,
            'platesRemaining': 6, // 4 sold
            'isAvailable': true,
          },
          {
            'menuItemId': 'dish-1',
            'name': 'Test Dosa',
            'pricePaise': 8000,
            'photoUrl': 'https://r2.test/dosa.jpg',
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

  @override
  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async =>
      _daily();

  @override
  Future<List<dynamic>> getList(String path,
          {Map<String, String>? queryParams}) async =>
      [
        {'id': 'dish-1', 'preferences': []},
      ];

  @override
  Future<Map<String, dynamic>> post(String path,
          {Map<String, dynamic>? body}) async =>
      {'id': 'dish-new'};
}

String _todayStr() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

Widget _harness() => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(_FakeApi())],
      // Use the REAL app theme: it sets button minimumSize.width = infinity
      // (full-width buttons), which is what made _SaveBar's Row crash on device.
      // A default theme would hide the regression.
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        // Nest MenuScreen inside a Scaffold like HomeScreen does.
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
    );

void main() {
  // Regression: tapping Quick add stages the dish and shows the sticky save
  // bar. The save bar's Discard/Save buttons must lay out under the real app
  // theme (button minimumSize.width = infinity) inside a nested Scaffold —
  // previously this crashed with "BoxConstraints forces an infinite width".
  testWidgets('Quick add shows the save bar without an infinite-width crash',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text('Quick add'), findsOneWidget);

    await tester.tap(find.text('Quick add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Save bar rendered (both flex buttons laid out fine).
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Unsaved'), findsOneWidget);
  });
}
