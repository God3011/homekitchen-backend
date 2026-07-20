import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

// Mirrors the order-tracking timeline (IntrinsicHeight + a marker Column with an
// Expanded connector line, beside Expanded content) under AppTheme with
// semantics on — IntrinsicHeight does an intrinsic pass, exactly the kind that
// has produced "!semantics.parentDataDirty" crashes. Guards that pattern.
Widget _step({required bool isLast}) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                    color: HomelyColors.sage, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 13, color: Colors.white),
              ),
              if (!isLast)
                const Expanded(
                    child: SizedBox(width: 2, child: ColoredBox(color: HomelyColors.sage))),
            ],
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 20, top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('Order received'), Text('12:32 PM')],
              ),
            ),
          ),
        ],
      ),
    );

void main() {
  testWidgets('timeline steps build without semantics assertion',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (var i = 0; i < 4; i++) _step(isLast: i == 3),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
