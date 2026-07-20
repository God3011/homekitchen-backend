import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

// Mirrors the dish card's price/action row: a compact stepper (content-sized,
// never infinite width) on the left, price on the right, on one line — at a
// narrow grid-cell width, with no overflow.
Widget _stepper() => Container(
      decoration: BoxDecoration(
        color: HomelyColors.gold,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: EdgeInsets.all(5), child: Icon(Icons.remove, size: 15)),
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Text('2', style: TextStyle(fontWeight: FontWeight.w800))),
          Padding(padding: EdgeInsets.all(5), child: Icon(Icons.add, size: 15)),
        ],
      ),
    );

void main() {
  testWidgets('price-right / add-left row fits a narrow cell', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 140, // ~ a 2-col grid cell on a small phone
            child: Row(
              children: [
                _stepper(),
                const Spacer(),
                const Text('₹200',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: HomelyColors.goldDeep)),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
