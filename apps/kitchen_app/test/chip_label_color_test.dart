import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

// Selected filter chips (e.g. Orders "All"/"New") must show a light label on the
// dark selected background; unselected chips keep the dark label.
Color _labelColor(WidgetTester tester, String text) {
  final rp = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: find.widgetWithText(FilterChip, text),
      matching: find.byType(RichText),
    ),
  );
  return rp.text.style!.color!;
}

void main() {
  testWidgets('chip label color follows selection', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Row(
          children: [
            FilterChip(
                label: const Text('All'), selected: true, onSelected: (_) {}),
            FilterChip(
                label: const Text('New'), selected: false, onSelected: (_) {}),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(_labelColor(tester, 'All'), HomelyColors.cream);
    expect(_labelColor(tester, 'New'), HomelyColors.ink);
  });
}
