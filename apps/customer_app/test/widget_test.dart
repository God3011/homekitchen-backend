// Basic smoke test. The full app requires Firebase init, so we don't boot it
// here; this just verifies the test harness and a trivial widget render.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a trivial widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Homely'))),
    );
    expect(find.text('Homely'), findsOneWidget);
  });
}
