import 'package:bt39_care/app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('welcome, then the patient demo with its five tabs', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BT39App());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Watch the 90-second demo'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(CupertinoButton, 'Patient'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Patient'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    for (final t in ['Today', 'Alerts', 'Insights', 'Care', 'Me']) {
      expect(find.text(t), findsWidgets);
    }
    expect(find.text('Heart Rate'), findsOneWidget);

    // Tapping a vital card opens Insights with that vital's chart.
    await tester.tap(find.text('Oxygen').first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.textContaining('hours · %'), findsOneWidget);
    await tester.tap(find.text('Today').last);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    await tester.tap(find.text('Care').last);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Dr. Kavya Rao'), findsWidgets);
  });

  testWidgets('doctor demo shows the ward', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const BT39App());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.widgetWithText(CupertinoButton, 'Doctor'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Doctor'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Ward A'), findsWidgets);
    expect(find.text('Sunita Deshmukh'), findsOneWidget);
  });
}
