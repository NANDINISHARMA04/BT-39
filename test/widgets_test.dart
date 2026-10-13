import 'package:bt39_care/theme/ios_theme.dart';
import 'package:bt39_care/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared list parts, on their own: what they draw is checked by size, not by eye.
void main() {
  Future<void> pump(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: buildTheme(IOS.light), home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child))));
  }

  testWidgets('a grouped list draws its separators across the card', (t) async {
    await pump(t, const GroupedList(children: [IOSRow(title: 'Age', value: '24'), IOSRow(title: 'Blood group', value: 'B+'), IOSRow(title: 'City')]));
    final lines = find.byType(Hairline);
    expect(lines, findsNWidgets(2));
    final card = t.getRect(find.byType(GroupedList));
    for (final i in [0, 1]) {
      final r = t.getRect(lines.at(i));
      expect(r.height, closeTo(.5, .01), reason: 'one device pixel');
      expect(r.right, card.right, reason: 'reaches the edge of the card');
      expect(r.width, greaterThan(card.width - 20), reason: 'starts a little in from the left, not at nothing');
    }
  });

  testWidgets('a row value sits at the right edge, and a long one is cut short', (t) async {
    await pump(t, const GroupedList(children: [IOSRow(title: 'Blood group', value: 'B+'), IOSRow(title: 'Hospital', value: 'A very long hospital name that cannot possibly fit on the row')]));
    final card = t.getRect(find.byType(GroupedList));
    expect(t.getTopRight(find.text('B+')).dx, closeTo(card.right - 14, 1));
    expect(t.getRect(find.textContaining('A very long')).right, lessThanOrEqualTo(card.right - 14 + 1));
    expect(t.takeException(), isNull, reason: 'no overflow');
  });
}
