import 'package:bt39_care/screens/patient/accessibility_screen.dart';
import 'package:bt39_care/screens/patient/assistant_screen.dart';
import 'package:bt39_care/screens/patient/easy_home_screen.dart';
import 'package:bt39_care/screens/patient/me_screen.dart';
import 'package:bt39_care/screens/patient/sos_screen.dart';
import 'package:bt39_care/screens/patient/today_screen.dart';
import 'package:bt39_care/services/accessibility.dart';
import 'package:bt39_care/services/monitor.dart';
import 'package:bt39_care/services/patient_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/recorded_service.dart';

/// Accessibility options: they are saved, and at Extra large text every
/// patient tab and the easy home fit a small phone (any overflow fails).
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

/// Scrolls the visible page to the bottom and back to the top.
Future<void> scrollThrough(WidgetTester t) async {
  for (final dy in [-400.0, 400.0]) {
    for (var i = 0; i < 12; i++) {
      await t.drag(find.byType(Scrollable).hitTestable().first, Offset(0, dy));
      await t.pump(const Duration(milliseconds: 100));
    }
  }
  await settle(t, 2);
}

/// Scrolls down until [f] is built.
Future<void> expectSeen(WidgetTester t, Finder f) async {
  for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
    await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -200));
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(f, findsOneWidget);
}

Future<void> popPage(WidgetTester t) async {
  t.state<NavigatorState>(find.byType(Navigator).last).pop();
  await settle(t);
}

/// Opens the patient app (Demo Mode on the recorded service) on a 360pt-wide phone.
Future<(AccessibilitySettings, RecordedService)> startPatient(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 1920);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final svc = await openApp(t);
  await settle(t, 3);
  await tapScrolled(t, find.widgetWithText(CupertinoButton, 'Patient'));
  await settle(t, 10);
  return (Provider.of<AccessibilitySettings>(t.element(find.byType(TodayScreen).first), listen: false), svc);
}

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  test('settings are saved on the device and loaded again', () async {
    final a = AccessibilitySettings();
    await a.ready;
    expect(a.textSize, AccessibilitySettings.normal);
    expect(a.easyHome, isFalse);
    await a.setTextSize(AccessibilitySettings.extraLarge);
    await a.setBoldText(true);
    await a.setEasyHome(true);
    await a.setFlashAlerts(true);
    await a.setSpeakAlerts(true);
    await a.setReduceMotion(true);

    final b = AccessibilitySettings();
    await b.ready;
    expect(b.textSize, AccessibilitySettings.extraLarge);
    expect([b.boldText, b.easyHome, b.flashAlerts, b.speakAlerts, b.reduceMotion], everyElement(isTrue));

    final mq = b.apply(const MediaQueryData());
    expect(mq.textScaler.scale(10), closeTo(14, .001));
    expect(mq.boldText, isTrue);
    expect(mq.disableAnimations, isTrue);
  });

  testWidgets('patient tabs fit a small phone at Extra large text', (t) async {
    final (a, _) = await startPatient(t);
    await a.setTextSize(AccessibilitySettings.extraLarge);
    await a.setBoldText(true);
    await settle(t);
    expect(MediaQuery.textScalerOf(t.element(find.byType(TodayScreen).first)).scale(10), closeTo(14, .01));

    await scrollThrough(t);
    for (final tab in ['Alerts', 'Insights', 'Care', 'Me']) {
      await t.tap(find.text(tab).last);
      await settle(t);
      await scrollThrough(t);
    }
    // The settings page itself, from Me.
    await tapScrolled(t, find.text('Accessibility'));
    await settle(t);
    expect(find.byType(AccessibilityScreen), findsOneWidget);
    await expectSeen(t, find.text('Flash the screen for alerts'));
    await expectSeen(t, find.text('Easy home'));
    await scrollThrough(t);
    await popPage(t);

    await t.tap(find.text('Today').last);
    await settle(t);
    // The Help button opens the assistant.
    await t.tap(find.text('Help').hitTestable());
    await settle(t);
    expect(find.byType(AssistantScreen), findsOneWidget);
    await popPage(t);
  });

  testWidgets('easy home replaces Today, fits at Extra large text and its buttons open their pages', (t) async {
    final (a, _) = await startPatient(t);
    await a.setTextSize(AccessibilitySettings.extraLarge);
    await a.setEasyHome(true);
    await settle(t);
    expect(find.byType(EasyHomeScreen), findsOneWidget);
    Finder easy(String text) => find.descendant(of: find.byType(EasyHomeScreen), matching: find.text(text));
    expect(easy('Heart'), findsOneWidget);
    expect(easy('Oxygen'), findsOneWidget);
    expect(easy("You're OK").evaluate().length + easy('Alert: tap to see').evaluate().length + easy('Check your band').evaluate().length, 1);
    await expectSeen(t, easy('Temperature'));
    await expectSeen(t, easy('Call family'));
    await scrollThrough(t);

    await tapScrolled(t, find.text('Ask for help'));
    await settle(t);
    expect(find.byType(AssistantScreen), findsOneWidget);
    await popPage(t);

    await tapScrolled(t, find.text('My medicines'));
    await settle(t);
    expect(find.byType(ProfileEditor), findsOneWidget);
    await popPage(t);

    await tapScrolled(t, find.text('Emergency help'));
    await settle(t);
    expect(find.byType(SosScreen), findsOneWidget);
    await popPage(t);

    await tapScrolled(t, find.text('Show full home'));
    await settle(t);
    expect(a.easyHome, isFalse);
    expect(find.byType(EasyHomeScreen), findsNothing);
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('pages opened from the patient tabs fit at Extra large text', (t) async {
    final (a, _) = await startPatient(t);
    await a.setTextSize(AccessibilitySettings.extraLarge);
    await settle(t);
    Future<void> openAndBack(Finder f) async {
      await tapScrolled(t, f);
      await settle(t);
      await scrollThrough(t);
      await popPage(t);
    }

    await t.tap(find.text('Alerts').last);
    await settle(t);
    await openAndBack(find.text('See how AdaptAlert works'));
    await t.tap(find.text('All').first);
    await settle(t);
    await openAndBack(find.text('See how AdaptAlert decided'));

    await t.tap(find.text('Insights').last);
    await settle(t);
    await openAndBack(find.text('Open the Research Lab'));

    await t.tap(find.text('Care').last);
    await settle(t);
    await openAndBack(find.text('Search doctors, specialities, hospitals'));

    await t.tap(find.text('Me').last);
    await settle(t);
    for (final p in ['Medical records', 'Insurance & claims', 'Family', 'Medical ID', 'Health profile']) {
      await openAndBack(find.text(p));
    }

    await t.tap(find.text('Today').last);
    await settle(t);
    await openAndBack(find.text('AI Health Assistant'));
    await openAndBack(find.text('SOS'));
  });

  testWidgets('flash alerts: the alert banner stays until it is tapped', (t) async {
    final (a, svc) = await startPatient(t);
    await a.setFlashAlerts(true);
    await a.setSpeakAlerts(true);
    final ctx = t.element(find.byType(TodayScreen).first);
    Provider.of<PatientStore>(ctx, listen: false).updatePrefs((x) => x.autoSos = false);
    final m = Provider.of<MonitorController>(ctx, listen: false);
    await settle(t);
    expect(find.text('Tap to see the alert').hitTestable(), findsNothing, reason: 'no alert yet: the banner is off screen');
    // An alert event arrives on the live stream: the line the service recorded when the oxygen scenario hit the
    // safety floor (level 4). Auto SOS is off, so only the banner shows.
    svc.send('GET /wearer/live', svc.alertUpdate());
    await settle(t);
    expect(m.alertEvents.value?.level, 4);
    expect(find.byType(SosScreen), findsNothing);
    expect(find.text('Tap to see the alert'), findsOneWidget);
    await settle(t, 50); // 10 seconds: a normal banner would be gone.
    expect(find.text('Tap to see the alert').hitTestable(), findsOneWidget);
    await t.tap(find.text('Tap to see the alert'));
    await settle(t);
    expect(find.text('Tap to see the alert').hitTestable(), findsNothing);
  });
}
