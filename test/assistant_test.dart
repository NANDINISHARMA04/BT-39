import 'package:bt39_care/app.dart';
import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/screens/patient/patient_shell.dart';
import 'package:bt39_care/services/assistant.dart';
import 'package:bt39_care/services/monitor.dart';
import 'package:bt39_care/services/patient_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  late HealthAssistant ai;

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    appLang.value = 'en';
    missingHindi.clear();
    // Built the same way the assistant screen does, from the app's monitor
    // and the patient's store (here the example data).
    ai = HealthAssistant(MonitorController(), PatientStore.example('Aarav Sharma', 'aarav@example.com'));
  });
  tearDown(() => appLang.value = 'en');

  void expectTopic(String question, String topic, String action) {
    final r = ai.reply(question);
    expect(r.topic, topic, reason: question);
    expect(r.action, action, reason: question);
    expect(r.actionLabel, isNotNull, reason: question);
  }

  group('where is / how do I (English)', () {
    final cases = {
      'Where are my reports?': ('records', 'records'),
      'How do I upload a report?': ('records', 'records'),
      'Where are my medicines?': ('healthProfile', 'healthProfile'),
      'How do I add a condition?': ('healthProfile', 'healthProfile'),
      'Where is my insurance claim?': ('insurance', 'insurance'),
      'Where are my family contacts?': ('family', 'family'),
      'How do I change my caregiver?': ('family', 'family'),
      'Call my family': ('callFamily', 'callFamily'),
      'Where is my Medical ID?': ('medicalId', 'medicalId'),
      'Where is the SOS button?': ('sos', 'sos'),
      'How do I call 112?': ('sos', 'sos'),
      'How do I book an appointment?': ('appointment', 'book'),
      'How can I reschedule my appointment?': ('appointment', 'book'),
      'Where do I find a doctor?': ('findDoctor', 'findDoctor'),
      'I want to talk to a doctor': ('talkDoctor', 'findDoctor'),
      'How do I reply to an alert?': ('alerts', 'alerts'),
      'Where are the held back alerts?': ('held', 'alerts'),
      'Show me my trends': ('trends', 'insights'),
      'How does AdaptAlert work?': ('howItWorks', 'howItWorks'),
      'Open the Research Lab': ('research', 'research'),
      'How do I change the language?': ('language', 'language'),
      'How do I turn on dark mode?': ('appearance', 'me'),
      'Turn off notifications': ('notifications', 'me'),
      'How do I make the text bigger?': ('accessibility', 'accessibility'),
      'How do I simulate a scenario?': ('simulator', 'simulator'),
      'How do I sign out?': ('signOut', 'me'),
      'What do the alert colours mean?': ('levels', 'alerts'),
      'What does Critical mean?': ('levels', 'alerts'),
      'What is a normal heart rate?': ('ranges', 'insights'),
      'What is SpO2?': ('spo2', 'insights'),
      'How does the wrist band work?': ('band', 'insights'),
      'Check your band': ('band', 'insights'),
      'I feel unwell': ('unwell', 'findDoctor'),
    };
    cases.forEach((q, want) => test(q, () => expectTopic(q, want.$1, want.$2)));

    test('answers are short numbered steps', () {
      final r = ai.reply('Where are my reports?');
      expect(r.text, contains('Me → Medical records'));
      expect(r.text, contains('1. '));
      expect(r.text, contains('+'));
    });

    test('SOS help is urgent', () => expect(ai.reply('Where is the SOS button?').urgent, isTrue));
  });

  group('Hindi and Hinglish', () {
    final cases = {
      'report kahan hai': ('records', 'records'),
      'dawai kaise dekhu': ('healthProfile', 'healthProfile'),
      'bhasha kaise badlu': ('language', 'language'),
      'doctor se baat karni hai': ('talkDoctor', 'findDoctor'),
      'appointment kaise book kare': ('appointment', 'book'),
      'beema kahan milega': ('insurance', 'insurance'),
      'मेरी रिपोर्ट कहाँ है?': ('records', 'records'),
      'दवाई कहाँ देखूँ?': ('healthProfile', 'healthProfile'),
      'भाषा कैसे बदलें?': ('language', 'language'),
      'SOS कहाँ है?': ('sos', 'sos'),
      'डॉक्टर से बात करनी है': ('talkDoctor', 'findDoctor'),
      'परिवार को फ़ोन करो': ('callFamily', 'callFamily'),
      'मेरी तबीयत ठीक नहीं है': ('unwell', 'findDoctor'),
      'अक्षर बड़े कैसे करें?': ('accessibility', 'accessibility'),
      'SpO2 क्या है?': ('spo2', 'insights'),
    };
    cases.forEach((q, want) => test(q, () => expectTopic(q, want.$1, want.$2)));

    test('the help-topic questions route the same in Hindi', () {
      appLang.value = 'hi';
      final cases = {
        'Where are my reports?': 'records',
        'Where are my medicines?': 'healthProfile',
        'How do I book an appointment?': 'appointment',
        'Where are my family contacts?': 'family',
        'Where is my insurance?': 'insurance',
        'Call my family': 'callFamily',
        'I feel unwell': 'unwell',
        'How do I change the language?': 'language',
        'How do I make the text bigger?': 'accessibility',
        'What can you help with?': 'menu',
        'Where is the SOS button?': 'sos',
      };
      cases.forEach((q, topic) {
        final r = ai.reply(tr(q));
        expect(r.topic, topic, reason: '${tr(q)} ($q)');
        expect(r.text, isNot(contains('Tap ')), reason: 'reply should be in Hindi: ${r.text}');
      });
      expect(missingHindi, isEmpty, reason: missingHindi.join('\n'));
    });
  });

  group('not understood', () {
    test('offers things to tap instead of a dead end', () {
      final r = ai.reply('banana pancake recipe');
      expect(r.topic, 'unknown');
      expect(r.text, contains("Sorry, I didn't understand that."));
      expect(r.suggestions, isNotEmpty);
      // Each suggestion leads somewhere useful.
      for (final s in r.suggestions) {
        expect(ai.reply(s).topic, isNot('unknown'), reason: s);
      }
    });

    test('"help" lists what it can do', () {
      final r = ai.reply('What can you help with?');
      expect(r.topic, 'menu');
      expect(r.suggestions, isNotEmpty);
    });
  });

  group('health answers still work', () {
    test('how am I doing', () {
      final r = ai.reply('How am I doing today?');
      expect(r.topic, isNull);
      expect(r.text, anyOf(contains('Today:'), contains('band clearly')));
    });

    test('last alert explains and links to the decision', () {
      final r = ai.reply('Why did I get my last alert?');
      expect(r.topic, isNull);
      expect(r.text, contains('See how AdaptAlert decided'));
      expect(r.action, anyOf('alertDetail', isNull));
    });

    test('what it learned', () => expect(ai.reply('What has AdaptAlert learned about me?').action, 'insights'));
    test('next appointment', () => expect(ai.reply('When is my next appointment?').action, 'book'));
    test('medicines list', () => expect(ai.reply('What medicines do I take?').text, contains('Your medicines:')));
    test('insurance status', () => expect(ai.reply('Is my insurance claim approved?').action, 'insurance'));
    test('records list', () => expect(ai.reply('Show my latest lab results').action, 'records'));
    test('heart rate', () {
      final r = ai.reply('What is my heart rate?');
      expect(r.text, anyOf(contains('Heart rate'), contains('band clearly')));
    });

    test('emergency symptoms go to SOS', () {
      for (final q in ['I have chest pain', 'I can\'t breathe', 'मेरे सीने में दर्द है', 'emergency', 'SOS']) {
        final r = ai.reply(q);
        expect(r.action, 'sos', reason: q);
        expect(r.urgent, isTrue, reason: q);
        expect(r.text, contains('112'), reason: q);
      }
    });

    test('suggested questions in Hindi get the same answers', () {
      appLang.value = 'hi';
      expect(ai.reply(tr('What has AdaptAlert learned about me?')).action, 'insights');
      expect(ai.reply(tr('When is my next appointment?')).action, 'book');
      expect(ai.reply(tr('Is my insurance claim approved?')).action, 'insurance');
      expect(ai.reply(tr('I have chest pain')).action, 'sos');
      expect(ai.reply(tr('How am I doing today?')).topic, isNull);
      expect(ai.reply(tr('What medicines do I take?')).topic, isNull);
    });

    test('every action is one the screen knows', () {
      final qs = [
        ...HealthAssistant.suggestions,
        ...HealthAssistant.helpSuggestions,
        'Where is my Medical ID?', 'How does AdaptAlert work?', 'Open the Research Lab', 'How do I sign out?',
        'How do I simulate a scenario?', 'How do I make the text bigger?', 'Where do I find a doctor?',
      ];
      for (final q in qs) {
        final a = ai.reply(q).action;
        if (a != null) expect(HealthAssistant.actions, contains(a), reason: q);
      }
    });
  });

  testWidgets('help topic opens the right place', (t) async {
    t.view.physicalSize = const Size(1080, 1920);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const BT39App());
    await settle(t, 3);
    await tapScrolled(t, find.widgetWithText(CupertinoButton, 'Patient'));
    await settle(t, 10);
    await tapScrolled(t, find.text('AI Health Assistant'));
    await settle(t);
    expect(find.text('Ask anything, or where to find something'), findsOneWidget);
    expect(find.text('Find something'), findsOneWidget);
    expect(find.text('Get help'), findsOneWidget);

    await t.tap(find.text('Reports').hitTestable().first);
    await settle(t, 15);
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
}
