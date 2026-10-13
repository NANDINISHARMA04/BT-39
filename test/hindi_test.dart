import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/services/assistant.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/recorded_service.dart';

/// Opens the app in Hindi on a small phone, with the replies the service recorded. The service sends its words as
/// English messages (alert titles and reasons, assistant answers, nurse tasks, ward alerts, bed chat) and the app
/// turns them into Hindi with `tr`, so a message with no Hindi in the table shows up here. Any text without a Hindi
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

/// Scrolls the open page down by [n] screens, so that everything on it is built once.
Future<void> scrollDown(WidgetTester t, [int n = 4]) async {
  for (var i = 0; i < n; i++) {
    await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -900));
    await settle(t, 2);
  }
}

/// Asks the assistant a question the way its buttons do: the Hindi text of the English question.
Future<void> ask(WidgetTester t, String en) async {
  await t.enterText(find.byType(CupertinoTextField), tr(en));
  await t.testTextInput.receiveAction(TextInputAction.send);
  await settle(t, 25); // the answer is typed out word by word
}

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    appLang.value = 'hi';
    missingHindi.clear();
  });
  tearDown(() => appLang.value = 'en');

  Future<RecordedService> start(WidgetTester t, String role, {Size size = const Size(1080, 1920), double ratio = 3}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = ratio;
    addTearDown(t.view.reset);
    final svc = await openApp(t);
    await settle(t, 3);
    expect(find.text('हिन्दी'), findsOneWidget);
    await tapScrolled(t, find.widgetWithText(CupertinoButton, tr(role)));
    await settle(t, 10);
    return svc;
  }

  void expectAllHindi() => expect(missingHindi, isEmpty, reason: 'No Hindi for:\n${missingHindi.join('\n')}');

  testWidgets('welcome and sign-up forms in Hindi', (t) async {
    t.view.physicalSize = const Size(1080, 1920);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final svc = await openApp(t);
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
    // The Research Lab runs its study on the service and shows the results, with no account.
    await tapScrolled(t, find.text(tr('Research Lab')));
    await settle(t);
    await scrollDown(t, 8);
    expect(svc.to('POST /study'), hasLength(1));
    expect(svc.to('POST /study').single.headers.containsKey('Authorization'), isFalse);
    t.state<NavigatorState>(find.byType(Navigator).last).pop();
    await settle(t);
    expectAllHindi();
  });

  testWidgets('patient app in Hindi', (t) async {
    final svc = await start(t, 'Patient');
    await tab(t, 'Alerts');
    await openAndBack(t, find.text(tr('See how AdaptAlert works')));
    await t.tap(find.text(tr('All')).first);
    await settle(t);
    await openAndBack(t, find.text(tr('See how AdaptAlert decided')));
    await tab(t, 'Insights');
    await scrollDown(t);
    await openAndBack(t, find.text(tr('Open the Research Lab')));
    await tab(t, 'Care');
    await openAndBack(t, find.text(tr('Search doctors, specialities, hospitals')));
    await tab(t, 'Me');
    for (final page in ['Medical records', 'Insurance & claims', 'Family', 'Medical ID', 'Health profile']) {
      await openAndBack(t, find.text(tr(page)));
    }
    await tab(t, 'Today');
    await openAndBack(t, find.text('SOS'));

    // The assistant, asked every question its buttons send. The service answers with English messages; the replies it
    // recorded with X-Lang: hi are shown in Hindi.
    await tapScrolled(t, find.text(tr('AI Health Assistant')));
    await settle(t);
    final questions = <String>{
      ...HealthAssistant.suggestions,
      ...HealthAssistant.helpSuggestions,
      'Where are my family contacts?',
      'Where is my insurance?',
      'Call my family',
      'How do I make the text bigger?',
      'What can you help with?',
    };
    for (final q in questions) {
      await ask(t, q);
    }
    final asked = svc.to('POST /chat');
    expect({for (final a in asked) a.headers['X-Lang']}, {'hi'});
    expect(asked.length, questions.length, reason: 'every question was sent');
    t.state<NavigatorState>(find.byType(Navigator).last).pop();
    await settle(t);
    expectAllHindi();
  });

  testWidgets('doctor app in Hindi', (t) async {
    final svc = await start(t, 'Doctor');
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
    // A bed: its values, a demo scenario, and a question about it in the chat (answered from the bed's own data).
    await tapScrolled(t, find.text('Sunita Deshmukh'));
    await settle(t);
    await tapScrolled(t, find.text(tr('Sepsis')));
    await settle(t, 10);
    await tapScrolled(t, find.text(tr('Is this sepsis?')));
    await settle(t, 20); // the chat opens, sends the question and the answer types itself in
    expect(svc.to('POST /ward/scenario').single.map, {'bed': 'B02', 'scenario': 'sepsis'});
    expect(svc.to('POST /chat').single.map, {'q': tr('Is this sepsis?'), 'focus': 'B02'});
    expect(svc.to('POST /chat').single.headers['X-Lang'], 'hi');
    expect(find.textContaining('Here is what the records say about Bed B02'), findsOneWidget);
    expect(find.text(tr('Open alerts')), findsWidgets);
    t.state<NavigatorState>(find.byType(Navigator).last).pop(); // the chat
    await settle(t);
    t.state<NavigatorState>(find.byType(Navigator).last).pop(); // the bed
    await settle(t);
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

  // The sections a phone keeps behind other pages (AdaptAlert review, Ward rules, Me) are all in the laptop sidebar.
  for (final (role, sections) in [
    ('Doctor', ['Patients', 'Schedule', 'Ward', 'Alerts', 'AdaptAlert review', 'Ward rules', 'Me']),
    ('Nurse', ['Ward', 'Patients', 'Alerts', 'Home band', 'Ward rules', 'Me']),
  ]) {
    testWidgets('${role.toLowerCase()} sections on a laptop in Hindi', (t) async {
      await start(t, role, size: const Size(1440, 900), ratio: 1);
      for (final s in sections) {
        await t.tap(find.text(tr(s)).first);
        await settle(t, 4);
        await scrollDown(t, 2);
      }
      expectAllHindi();
    });
  }
}
