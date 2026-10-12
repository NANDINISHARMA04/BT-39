import 'package:bt39_care/app.dart';
import 'package:bt39_care/l10n/l10n.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens the app in Hindi on a small phone. Any text without a Hindi
/// translation, or any layout overflow from longer Hindi text, fails.
Future<void> settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> tapScrolled(WidgetTester t, Finder f) async {
  for (final dy in [-250.0, 250.0]) {
    for (var i = 0; i < 30 && f.hitTestable().evaluate().isEmpty; i++) {
      await t.drag(find.byType(Scrollable).hitTestable().first, Offset(0, dy));
      await t.pump(const Duration(milliseconds: 100));
    }
  }
  await t.tap(f.hitTestable().first);
}

Future<void> openAndBack(WidgetTester t, Finder f) async {
  await tapScrolled(t, f);
  await settle(t);
  t.state<NavigatorState>(find.byType(Navigator).last).pop();
  await settle(t);
}

Future<void> tab(WidgetTester t, String en) async {
  await t.tap(find.text(tr(en)).last);
  await settle(t);
}

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    appLang.value = 'hi';
    missingHindi.clear();
  });
  tearDown(() => appLang.value = 'en');

  Future<void> start(WidgetTester t, String role) async {
    t.view.physicalSize = const Size(1080, 1920);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const BT39App());
    await settle(t, 3);
    expect(find.text('हिन्दी'), findsOneWidget);
    await tapScrolled(t, find.widgetWithText(CupertinoButton, tr(role)));
    await settle(t, 10);
  }

  void expectAllHindi() => expect(missingHindi, isEmpty, reason: 'No Hindi for:\n${missingHindi.join('\n')}');

  testWidgets('welcome and sign-up forms in Hindi', (t) async {
    t.view.physicalSize = const Size(1080, 1920);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const BT39App());
    await settle(t, 3);
    for (var i = 0; i < 3; i++) {
      await t.scrollUntilVisible(find.text(tr('Sign up')).at(i), 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.text(tr('Sign up')).at(i));
      await settle(t, 2);
      await t.tap(find.text(tr('Sign up')).at(i));
      await settle(t);
      await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -1500));
      await settle(t);
      t.state<NavigatorState>(find.byType(Navigator).last).pop();
      await settle(t);
    }
    expectAllHindi();
  });

  testWidgets('patient app in Hindi', (t) async {
    await start(t, 'Patient');
    await tab(t, 'Alerts');
    await openAndBack(t, find.text(tr('See how AdaptAlert works')));
    await t.tap(find.text(tr('All')).first);
    await settle(t);
    await openAndBack(t, find.text(tr('See how AdaptAlert decided')));
    await tab(t, 'Insights');
    for (var i = 0; i < 4; i++) {
      await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -900));
      await settle(t, 2);
    }
    await tab(t, 'Care');
    await openAndBack(t, find.text(tr('Search doctors, specialities, hospitals')));
    await tab(t, 'Me');
    for (final page in ['Medical records', 'Insurance & claims', 'Family', 'Medical ID', 'Health profile']) {
      await openAndBack(t, find.text(tr(page)));
    }
    await tab(t, 'Today');
    await openAndBack(t, find.text(tr('AI Health Assistant')));
    await openAndBack(t, find.text('SOS'));
    expectAllHindi();
  });

  testWidgets('doctor app in Hindi', (t) async {
    await start(t, 'Doctor');
    for (var i = 0; i < 3; i++) {
      await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -700));
      await settle(t, 2);
    }
    await tab(t, 'Patients');
    await tapScrolled(t, find.text('Jai'));
    await settle(t);
    for (final seg in ['Alerts', 'Records', 'Notes', 'Overview']) {
      await t.tap(find.text(tr(seg)).last);
      await settle(t);
    }
    t.state<NavigatorState>(find.byType(Navigator).last).pop();
    await settle(t);
    await openAndBack(t, find.text('Farhan Ali'));
    await tab(t, 'Schedule');
    await tab(t, 'Ward');
    await openAndBack(t, find.text('Sunita Deshmukh'));
    await tab(t, 'Alerts');
    await tab(t, 'Today');
    await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, 2000));
    await settle(t);
    await t.tap(find.text('DR'));
    await settle(t);
    await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -900));
    await settle(t, 15);
    expectAllHindi();
  });

  testWidgets('nurse app in Hindi', (t) async {
    await start(t, 'Nurse');
    for (var i = 0; i < 3; i++) {
      await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -700));
      await settle(t, 2);
    }
    await tab(t, 'Home band');
    await tab(t, 'Ward');
    await tab(t, 'Patients');
    await tab(t, 'Alerts');
    expectAllHindi();
  });
}
