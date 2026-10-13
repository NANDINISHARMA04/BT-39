import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/screens/patient/patient_shell.dart';
import 'package:bt39_care/screens/patient/sos_screen.dart';
import 'package:bt39_care/services/assistant.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/recorded_service.dart';

// The chat's answers are tested on the server (bt39-monitor-service/api/tests/pulse/test_pulse_chat.py); these tests are
// the screen, with the rule replies the service recorded played back as chat streams.

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

/// Opens the patient app (Demo Mode on the recorded service) and then the assistant.
Future<RecordedService> openAssistant(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 1920);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final svc = await openApp(t);
  await settle(t, 3);
  await tapScrolled(t, find.widgetWithText(CupertinoButton, 'Patient'));
  await settle(t, 10);
  await tapScrolled(t, find.text('AI Health Assistant'));
  await settle(t);
  return svc;
}

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    appLang.value = 'en';
    missingHindi.clear();
  });
  tearDown(() => appLang.value = 'en');

  testWidgets('help topic opens the right place', (t) async {
    final svc = await openAssistant(t);
    expect(find.text('Ask anything, or where to find something'), findsOneWidget);
    expect(find.text('Find something'), findsOneWidget);
    expect(find.text('Get help'), findsOneWidget);

    await t.tap(find.text('Reports').hitTestable().first);
    await settle(t, 15);
    expect(svc.to('POST /chat').single.map, {'q': 'Where are my reports?'});
    expect(svc.to('POST /chat/prepare'), hasLength(1)); // the chat warms the service up when it opens
    expect(find.textContaining('Me → Medical records'), findsOneWidget);
    await tapScrolled(t, find.text('Open medical records'));
    await settle(t);
    expect(find.text('Upload a record').evaluate().isNotEmpty || find.text('Records').evaluate().isNotEmpty, isTrue);
    t.state<NavigatorState>(find.byType(Navigator).last).pop();
    await settle(t);

    // A tab destination goes back to the shell and switches tab.
    await t.enterText(find.byType(CupertinoTextField), 'How do I change my appointment?');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t, 15);
    await tapScrolled(t, find.text('Open Care'));
    await settle(t);
    expect(patientTab.value, PatientTab.care);
    patientTab.value = PatientTab.today;
    await settle(t);
  });

  testWidgets('every suggestion button gets an answer, and the urgent one opens SOS', (t) async {
    final svc = await openAssistant(t);
    // The row of suggestion buttons under the chat scrolls sideways.
    final strip = find.descendant(of: find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal), matching: find.byType(Scrollable));
    for (final q in HealthAssistant.suggestions) {
      await t.scrollUntilVisible(find.text(q), 150, scrollable: strip); // built, maybe still beyond the edge
      await t.ensureVisible(find.text(q));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text(q).hitTestable().first);
      await settle(t, 30); // the answer is typed out word by word
    }
    expect([for (final s in svc.to('POST /chat')) s.map['q']], HealthAssistant.suggestions);
    // From the second question on, the turns before it go along, so a follow-up knows what it refers to.
    expect(svc.to('POST /chat')[1].map['history'], [
      {'role': 'user', 'text': HealthAssistant.suggestions[0]},
      isA<Map>().having((m) => m['role'], 'role', 'assistant'),
    ]);
    // The last one, "I have chest pain", is urgent: its answer says 112 and offers the SOS screen.
    expect(find.textContaining('112'), findsWidgets);
    await tapScrolled(t, find.text('Open SOS'));
    await settle(t);
    expect(find.byType(SosScreen), findsOneWidget);
  });
}
