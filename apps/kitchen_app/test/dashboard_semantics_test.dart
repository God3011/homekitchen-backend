import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

// Mirrors the dashboard's new layout: a "cooking" card + two stat tiles in a
// stretch Row inside a ListView, under AppTheme with semantics on — to catch the
// "!semantics.parentDataDirty" assertion reported on the kitchen home page.
Widget _tile(Widget value, Color accent) => Material(
      color: HomelyColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomelyColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long_rounded, size: 18, color: accent),
              ),
              const SizedBox(height: 12),
              const Text('TODAY', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 3),
              value,
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('dashboard layout builds without semantics assertion',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: HomelyColors.sage,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded),
                  const SizedBox(width: 14),
                  const Expanded(child: Text('Cooking Today')),
                  Switch(value: true, onChanged: (_) {}),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _tile(const Text('8'), HomelyColors.blueDeep)),
                const SizedBox(width: 12),
                Expanded(
                    child: _tile(const Text('₹1,240'), HomelyColors.goldDeep)),
              ],
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
