import 'package:bt39_care/app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens every screen once on a phone-sized view. Any layout overflow or
/// exception fails the test (the test font is wider than real fonts, so this
/// is a strict check).
Future<void> settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> tapScrolled(WidgetTester t, Finder f) async {
  for (var i = 0; i < 25 && f.hitTestable().evaluate().isEmpty; i++) {
    await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -250));
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.tap(f.hitTestable().first);
}

Future<void> openAndBack(WidgetTester t, Finder f, {bool dialog = false}) async {
  // Scroll down to find it, then back up if it was above.
  for (final dy in [-250.0, 250.0]) {
    for (var i = 0; i < 30 && f.hitTestable().evaluate().isEmpty; i++) {
      await t.drag(find.byType(Scrollable).hitTestable().first, Offset(0, dy));
      await t.pump(const Duration(milliseconds: 100));
    }
  }
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f.hitTestable().first);
  await settle(t);
  final nav = t.state<NavigatorState>(find.byType(Navigator).last);
  nav.pop();
  await settle(t);
}

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  for (final size in [const Size(1179, 2556), const Size(1080, 1920)]) {
    testWidgets('patient screens render at ${size.width ~/ 3}pt wide', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(const BT39App());
      await settle(t, 3);
      await tapScrolled(t, find.widgetWithText(CupertinoButton, 'Patient'));
      await settle(t, 10);

      await t.tap(find.text('Alerts').last);
      await settle(t);
      await openAndBack(t, find.text('See how AdaptAlert works'));
      await t.tap(find.text('All').first);
      await settle(t);
      await openAndBack(t, find.text('See how AdaptAlert decided'));

      await t.tap(find.text('Insights').last);
      await settle(t);
      // Scroll through the charts, the live pipeline and the study.
      await t.drag(find.text('Health analytics and the AI behind your alerts'), const Offset(0, -1500));
      await settle(t);
      await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -1500));
      await settle(t);

      await openAndBack(t, find.text('Open the Research Lab'));

      await t.tap(find.text('Care').last);
      await settle(t);
      await openAndBack(t, find.text('Search doctors, specialities, hospitals'));

      await t.tap(find.text('Me').last);
      await settle(t);
      await openAndBack(t, find.text('Medical records'));
      await openAndBack(t, find.text('Insurance & claims'));
      await openAndBack(t, find.text('Family'));
      await openAndBack(t, find.text('Medical ID'));
      await openAndBack(t, find.text('Health profile'));

      await t.tap(find.text('Today').last);
      await settle(t);
      await openAndBack(t, find.text('AI Health Assistant'));
      await openAndBack(t, find.text('SOS'));
    });
  }

  testWidgets('laptop layout: sidebar navigation and pages open beside it', (t) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const BT39App());
    await settle(t, 3);
    await tapScrolled(t, find.widgetWithText(CupertinoButton, 'Patient'));
    await settle(t, 10);
    expect(find.text('Simulate a scenario'), findsOneWidget);
    for (final tab in ['Alerts', 'Insights', 'Care', 'Me', 'Today']) {
      await t.tap(find.text(tab).first);
      await settle(t);
    }
    await t.tap(find.text('Care').first);
    await settle(t);
    await openAndBack(t, find.text('Search doctors, specialities, hospitals'));
    expect(find.text('Simulate a scenario'), findsOneWidget);
  });

  testWidgets('system back closes the open page, then returns to Today', (t) async {
    t.view.physicalSize = const Size(1179, 2556);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const BT39App());
    await settle(t, 3);
    await tapScrolled(t, find.widgetWithText(CupertinoButton, 'Patient'));
    await settle(t, 10);
    await t.tap(find.text('Me').last);
    await settle(t);
    await tapScrolled(t, find.text('Medical records'));
    await settle(t);
    expect(find.text('Upload a record'), findsOneWidget);
    // The browser back button / Android back arrive as a route pop request.
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.text('Upload a record'), findsNothing);
    expect(find.text('Medical records'), findsOneWidget);
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.text('Heart Rate'), findsOneWidget, reason: 'second back goes to Today');
  });

  testWidgets('nurse screens render', (t) async {
    t.view.physicalSize = const Size(1080, 1920);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const BT39App());
    await settle(t, 3);
    await tapScrolled(t, find.widgetWithText(CupertinoButton, 'Nurse'));
    await settle(t, 10);
    await openAndBack(t, find.text('Sunita Deshmukh'));
    await t.tap(find.text('Alerts').last);
    await settle(t);
    await t.tap(find.text('AdaptAlert').last);
    await settle(t);
    await t.tap(find.text('Me').last);
    await settle(t);
  });
}
