import 'dart:async';

import 'package:bt39_care/screens/patient/sos_screen.dart';
import 'package:bt39_care/widgets/common.dart' show IOSRow;
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/recorded_service.dart';

Future<void> settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

/// The Simulate button at the top of Today (an icon; the Me tab has a row with the same icon, further on in the tree).
Finder simulateButton() => find.byIcon(CupertinoIcons.slider_horizontal_3).first;

Future<void> tapScrolled(WidgetTester t, Finder f) async {
  for (final dy in [-250.0, 250.0]) {
    for (var i = 0; i < 30 && f.hitTestable().evaluate().isEmpty; i++) {
      await t.drag(find.byType(Scrollable).hitTestable().first, Offset(0, dy));
      await t.pump(const Duration(milliseconds: 100));
    }
  }
  await t.tap(f.hitTestable().first);
}

/// The switch in the simulator sheet's row called [title] (the Me tab has switches too).
Finder switchOf(String title) => find.descendant(of: find.ancestor(of: find.text(title), matching: find.byType(IOSRow)), matching: find.byType(CupertinoSwitch));

/// Opens the app on a phone (Demo Mode, patient) and returns the recorded service behind it.
Future<RecordedService> startPatient(WidgetTester tester, [RecordedService? service]) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final svc = await openApp(tester, svc: service);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.ensureVisible(find.widgetWithText(CupertinoButton, 'Patient'));
  await tester.pump();
  await tester.tap(find.widgetWithText(CupertinoButton, 'Patient'));
  await settle(tester, 10);
  return svc;
}

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('welcome, then the patient demo with its five tabs', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final svc = await openApp(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Watch the demo with voice'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(CupertinoButton, 'Patient'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Patient'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // Demo Mode starts a visit on the service; the patient app reads its records and the band from there.
    expect(svc.to('POST /demo/start').single.map, {'role': 'patient'});
    expect(svc.to('GET /me/data'), hasLength(1));
    expect(svc.to('GET /wearer/live'), hasLength(1));
    expect(svc.to('GET /me/data').single.headers['Authorization'], 'Bearer pd1.recorded.patient');
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
    final svc = await openApp(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.widgetWithText(CupertinoButton, 'Doctor'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Doctor'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(svc.to('POST /demo/start').single.map, {'role': 'doctor'});
    expect(find.textContaining('Dr. Kavya Rao'), findsWidgets);
    await tester.tap(find.text('Ward').last);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(svc.to('GET /ward/live'), hasLength(1));
    expect(find.text('Ward A'), findsWidgets);
    expect(find.text('Sunita Deshmukh'), findsOneWidget);
  });

  testWidgets('the simulator sends the scenario, pause and fast forward to the service', (tester) async {
    final svc = await startPatient(tester);
    await tester.tap(simulateButton());
    await settle(tester);
    await tester.tap(find.text('Go for a walk'));
    await settle(tester, 15); // the sheet closes and the toast goes
    expect(svc.to('POST /wearer/scenario').single.map, {'id': 'walk'});

    await tester.tap(simulateButton());
    await settle(tester);
    expect(find.text('Running · 12 min left'), findsOneWidget);
    await tester.ensureVisible(switchOf('Pause the band')); // below the list of scenarios
    await settle(tester, 2);
    await tester.tap(switchOf('Pause the band'));
    await settle(tester);
    expect(svc.to('POST /wearer/paused').single.map, {'paused': true});
    await tester.ensureVisible(switchOf('Fast forward'));
    await settle(tester, 2);
    await tester.tap(switchOf('Fast forward'));
    await settle(tester);
    expect(svc.to('POST /wearer/fast').single.map, {'fast': true});
    expect(tester.widget<CupertinoSwitch>(switchOf('Pause the band')).value, isTrue);
    expect(tester.widget<CupertinoSwitch>(switchOf('Fast forward')).value, isTrue);
  });

  testWidgets('a critical alert opens SOS by itself when Auto SOS is on, and sends it after the countdown', (tester) async {
    final svc = await startPatient(tester);
    // The oxygen drop: the service answers the scenario with the level-4 alert it recorded, on the live stream.
    await tester.tap(simulateButton());
    await settle(tester);
    await tester.tap(find.text('Oxygen drop'));
    await settle(tester);
    expect(find.byType(SosScreen), findsOneWidget);
    expect(find.textContaining('SOS starts in'), findsOneWidget);
    expect(find.textContaining('Oxygen critically low'), findsWidgets);
    expect(svc.to('POST /sos'), isEmpty, reason: 'ten seconds to cancel first');

    await settle(tester, 60); // the countdown runs out
    final alert = (RecordedService.obj('patient/wearer_update_hypoxia.json')['alerts'] as List).first as Map;
    expect(svc.to('POST /sos').single.map, {'alert_id': alert['id']});
    expect(find.text('Help is on the way'), findsOneWidget);
    await settle(tester, 30); // the contacts' messages show as delivered, then seen
    await tester.tap(find.text('End SOS'));
    await settle(tester, 15);
    expect(svc.to('POST /sos/1/end'), hasLength(1));
    expect(find.byType(SosScreen), findsNothing);
  });

  testWidgets('opening the app in the middle of a critical alert shows it, and does not start SOS again', (tester) async {
    // The band is already in the oxygen drop: the first line of the stream is the snapshot with the level-4 alert,
    // which has Auto SOS on. A snapshot only brings the app up to date; it is not a new alert event.
    final svc = await startPatient(tester, RecordedService()..oxygenDrop = true);
    await settle(tester, 20);
    expect(find.byType(SosScreen), findsNothing);
    expect(svc.to('POST /sos'), isEmpty);
    await tester.tap(find.text('Alerts').last);
    await settle(tester);
    expect(find.text('Oxygen critically low'), findsOneWidget);
    expect(find.text('Safety floor'), findsOneWidget);
  });

  testWidgets('rescheduling offers the free times from the service and saves the new one', (tester) async {
    final svc = await startPatient(tester);
    await tester.tap(find.text('Care').last);
    await settle(tester);
    expect(find.text('Dr. Kavya Rao'), findsWidgets);
    await tester.tap(find.text('Reschedule').first);
    await settle(tester);
    final asked = svc.to('GET /doctors/d1/slots');
    expect(asked, hasLength(1));
    expect(asked.single.url.queryParameters['days'], '14');
    expect(asked.single.url.queryParameters['except'], 'a1', reason: 'the appointment being moved');
    expect(find.textContaining('free slots'), findsOneWidget);

    // Pick the first free time of the day and save.
    final times = find.textContaining(RegExp(r'^\d{1,2}:\d{2} (AM|PM)$'));
    expect(times, findsWidgets);
    await tester.tap(times.first);
    await settle(tester, 2);
    await tester.tap(find.text('Save'));
    await settle(tester, 15);
    final saved = svc.to('PUT /me/appointments/a1').single.map;
    final offered = [for (final day in (RecordedService.obj('patient/slots_d1.json')['days'] as Map).values) ...(day as List)];
    expect(offered, contains(saved['at']), reason: 'a time the service offered');
    expect(find.byType(CupertinoNavigationBar), findsNothing, reason: 'back on the Care tab');
  });

  testWidgets('the patient answers an alert and the demo doctor reviews it', (tester) async {
    final svc = await startPatient(tester);
    // An alert arrives (the oxygen drop); its SOS countdown is cancelled.
    await tester.tap(simulateButton());
    await settle(tester);
    await tester.tap(find.text('Oxygen drop'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester, 5);
    expect(find.byType(SosScreen), findsNothing);
    expect(svc.to('POST /sos'), isEmpty);

    await tester.tap(find.text('Alerts').last);
    await settle(tester);
    expect(find.text('Oxygen critically low'), findsOneWidget);
    await tapScrolled(tester, find.text('I feel unwell'));
    await settle(tester, 10);
    expect(svc.to('POST /wearer/alerts/3/feedback').single.map, {'kind': 'unwell'});

    // Answered alerts leave "Needs reply"; the demo doctor's buttons are on the card under "All".
    await tester.tap(find.text('All').first);
    await settle(tester);
    expect(find.text('You said you feel unwell'), findsOneWidget);
    await tapScrolled(tester, find.text('Confirm real'));
    await settle(tester, 10);
    expect(svc.to('POST /wearer/alerts/3/label').single.map, {'real': true, 'by': 'Dr. Kavya Rao'});
    expect(find.text('Confirmed real · Dr. Kavya Rao'), findsOneWidget);
    expect(find.text('You said you feel unwell'), findsOneWidget, reason: 'the answer sent back keeps the first one');
    await settle(tester, 20); // the toast goes
  });

  testWidgets('a demo the service has ended sends the person back to the welcome page with a note', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final svc = RecordedService();
    svc.refused['GET /wearer/live'] = (401, 'demo_expired', 'This demo has ended. Start it again from the welcome page.');
    await openApp(tester, svc: svc);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.widgetWithText(CupertinoButton, 'Patient'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Patient'));
    await settle(tester, 10);
    expect(find.text('Watch the demo with voice'), findsOneWidget, reason: 'back on the welcome page');
    expect(find.text('Demo ended'), findsOneWidget);
    expect(find.text('Your demo session ended. Start it again to keep exploring.'), findsOneWidget);
    expect(svc.to('POST /demo/end'), isEmpty, reason: 'there is nothing left to end');
    await settle(tester, 40); // the note goes
  });

  testWidgets('while the service wakes up the welcome page says so, and the demo opens when it answers', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final svc = RecordedService();
    final answer = svc.routes['POST /demo/start']!;
    final gate = Completer<void>();
    svc.routes['POST /demo/start'] = (s) async {
      await gate.future;
      return answer(s);
    };
    await openApp(tester, svc: svc);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.widgetWithText(CupertinoButton, 'Patient'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Patient'));
    await settle(tester, 5);
    expect(find.text('Waking up the server. This can take up to a minute.'), findsOneWidget);
    expect(find.text('Heart Rate'), findsNothing);
    gate.complete();
    await settle(tester, 10);
    expect(find.text('Heart Rate'), findsOneWidget);
    expect(svc.to('POST /demo/start'), hasLength(1));
  });

  testWidgets('the demo ward\'s alerts: acknowledge, resolve with a note, and say whether one was real', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final svc = await openApp(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.widgetWithText(CupertinoButton, 'Doctor'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Doctor'));
    await settle(tester, 10);
    expect(svc.to('GET /labels'), hasLength(1));
    await tester.tap(find.text('Alerts').last);
    await settle(tester);
    // Worst first, newest first among equals: the oxygen alert of bed B05 is on top.
    expect(find.textContaining('B05 · Harpreet Gill'), findsWidgets);

    await tapScrolled(tester, find.widgetWithText(CupertinoButton, 'Acknowledge'));
    await settle(tester);
    expect(svc.to('POST /ward/alerts/demo-3/ack'), hasLength(1));
    expect(find.widgetWithText(CupertinoButton, 'Acknowledged'), findsOneWidget);

    await tapScrolled(tester, find.widgetWithText(CupertinoButton, 'Resolve'));
    await settle(tester);
    await tester.enterText(find.byType(CupertinoTextField), 'Oxygen turned up to 4 L/min');
    await tester.tap(find.descendant(of: find.byType(CupertinoAlertDialog), matching: find.text('Resolve')));
    await settle(tester, 15);
    expect(svc.to('POST /ward/alerts/demo-3/resolve').single.map, {'note': 'Oxygen turned up to 4 L/min'});

    await tapScrolled(tester, find.text('Real').first);
    await settle(tester);
    expect(svc.to('POST /labels').single.map, {'alert_id': 'demo-2', 'real': true});
    await tapScrolled(tester, find.text('False alarm').last);
    await settle(tester);
    expect(svc.to('POST /labels').last.map['real'], isFalse);
    await settle(tester, 20);
  });
}
