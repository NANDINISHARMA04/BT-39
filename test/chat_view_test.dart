// The iMessage-style chat on screen: sending, typing dots, the answer typing itself in, "Delivered", sources and
// citations, an urgent answer's button before its words, "Not delivered" and retry, copying, reduced motion, and the
// doctors' and nurses' ways into the chat.
import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/screens/staff/patients_screen.dart';
import 'package:bt39_care/screens/staff/staff_ask_screen.dart';
import 'package:bt39_care/services/chat.dart';
import 'package:bt39_care/services/chat_controller.dart';
import 'package:bt39_care/theme/ios_theme.dart';
import 'package:bt39_care/widgets/chat/bubble.dart';
import 'package:bt39_care/widgets/chat/chat_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'client/helpers.dart';
import 'support/recorded_service.dart';

const route = 'POST /chat';

Future<void> settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

class Harness {
  Harness() : svc = LiveService()..stream(route);
  final LiveService svc;
  late final ChatController chat = ChatController(PulseChat(svc.api()), greeting: 'Hi Jai.');
  final actions = <String>[];
  final sources = <ChatSource>[];
  late SemanticsHandle semantics;

  /// Ends the test: the screen goes, and with it any answer still on its way (its stream has an idle timer).
  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    chat.dispose();
    semantics.dispose();
    await t.pump(const Duration(seconds: 2));
  }

  Future<void> open(WidgetTester t, {bool still = false, List<String> starters = const ['When is my next appointment?']}) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    semantics = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(IOS.light),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), disableAnimations: still),
        child: Scaffold(
          body: ChatView(controller: chat, starters: starters, onAction: actions.add, onSource: sources.add, header: const Text('Topics card')),
        ),
      ),
    ));
    await t.pump();
  }

  Future<void> type(WidgetTester t, String q) async {
    await t.enterText(find.byType(CupertinoTextField), q);
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pump();
  }

  void line(Map<String, dynamic> l) => svc.send(route, l);
}

Map<String, dynamic> meta({bool urgent = false, String? action, Object? label}) => {'type': 'meta', 'urgent': urgent, 'action': action, 'action_label': label, 'suggestions': <String>[], 'intent': 'data'};
Map<String, dynamic> done({List<Map<String, dynamic>> sources = const [], String? fallback}) =>
    {'type': 'done', 'sources': sources, 'cached': null, 'fallback': fallback, 'tokens': 0, 'cost': 0, 'ms': 0, 'action': null, 'action_label': null, 'intent': 'data'};
const appt = {'n': 1, 'id': 'appt:a1', 'kind': 'appointment', 'title': 'Dr. Kavya Rao', 'snippet': '', 'action': 'book', 'ref': null};

/// A widget with this semantics label (the widget tree, so merged semantics nodes do not hide it).
Finder byLabel(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

/// The bubble that holds [text].
Finder bubbleOf(String text) => find.ancestor(of: find.textContaining(text), matching: find.byType(Bubble));

String allText(WidgetTester t) => [
      for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? w.textSpan?.toPlainText() ?? '',
    ].join('\n');

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    appLang.value = 'en';
  });

  testWidgets('a question rises in, the dots type, the answer types itself in, then its sources arrive', (t) async {
    final h = Harness();
    await h.open(t);
    expect(find.text('Topics card'), findsOneWidget);
    expect(byLabel('Send'), findsNothing); // nothing to send yet
    await t.enterText(find.byType(CupertinoTextField), 'When is my next appointment?');
    await t.pump(const Duration(milliseconds: 300));
    expect(byLabel('Send'), findsOneWidget); // the send button grows in once there is text
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pump();
    expect(find.text('When is my next appointment?'), findsWidgets);
    expect(find.byType(TypingBubble), findsOneWidget);
    expect(find.text('Delivered'), findsNothing);

    h.line(meta(action: 'book', label: {'t': 'Open Care'}));
    await settle(t, 2);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.byType(TypingBubble), findsOneWidget); // still thinking
    h.line({'type': 'delta', 'text': 'Your next appointment is tomorrow at 11:30 AM with Dr. Kavya Rao '});
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(TypingBubble), findsNothing);
    final early = allText(t);
    expect(early.contains('with Dr. Kavya Rao'), isFalse, reason: 'the words type themselves in, not all at once');
    h.line({'type': 'delta', 'text': '[1].'});
    h.line(done(sources: [appt]));
    await settle(t, 10);
    expect(allText(t), contains('Your next appointment is tomorrow at 11:30 AM with Dr. Kavya Rao'));
    expect(allText(t).contains('[1]'), isFalse, reason: 'citations are badges, not brackets');
    expect(byLabel('Source 1: Dr. Kavya Rao'), findsOneWidget);
    await t.tap(byLabel('Source 1: Dr. Kavya Rao'));
    await t.tap(find.text('1').first); // the badge in the text
    expect(h.sources.map((s) => s.id), ['appt:a1', 'appt:a1']);
    await t.tap(find.text('Open Care'));
    expect(h.actions, ['book']);
    await h.close(t);
  });

  testWidgets('an urgent answer shows its red button before any word', (t) async {
    final h = Harness();
    await h.open(t);
    await h.type(t, 'I have chest pain');
    h.line(meta(urgent: true, action: 'sos', label: {'t': 'Open SOS'}));
    await settle(t, 2);
    expect(find.byType(TypingBubble), findsOneWidget);
    final button = t.widget<CupertinoButton>(find.ancestor(of: find.text('Open SOS'), matching: find.byType(CupertinoButton)));
    expect(button.color, IOS.light.red);
    await t.tap(find.text('Open SOS'));
    expect(h.actions, ['sos']);
    h.line({'type': 'answer', 'msg': {'t': 'This could be an emergency. Please don\'t wait for an alert.'}});
    h.line(done(fallback: 'budget'));
    await settle(t, 10);
    expect(allText(t), contains('This could be an emergency.'));
    expect(find.text('Quick answer'), findsOneWidget); // the free answer says so
    await h.close(t);
  });

  testWidgets('not delivered: a red mark, and a tap sends it again', (t) async {
    final h = Harness();
    h.svc.refused[route] = (503, 'unavailable', 'The service is not answering.');
    await h.open(t);
    await h.type(t, 'Hello?');
    await settle(t, 3);
    expect(find.byIcon(CupertinoIcons.exclamationmark_circle_fill), findsOneWidget);
    expect(find.text('The service is not answering.'), findsOneWidget);
    expect(find.text('Tap to try again'), findsOneWidget);
    h.svc.refused.clear();
    await t.tap(find.byIcon(CupertinoIcons.exclamationmark_circle_fill));
    await settle(t, 2);
    expect(h.svc.to(route).map((s) => s.map['q']), ['Hello?', 'Hello?']);
    expect(find.byIcon(CupertinoIcons.exclamationmark_circle_fill), findsNothing);
    expect(find.byType(TypingBubble), findsOneWidget);
    await h.close(t);
  });

  testWidgets('one question at a time: the starters wait while an answer is coming', (t) async {
    final h = Harness();
    await h.open(t);
    await t.tap(find.text('When is my next appointment?'));
    await t.pump();
    await t.tap(find.text('When is my next appointment?').last);
    await t.pump();
    expect(h.svc.to(route), hasLength(1));
    h.line(meta());
    h.line({'type': 'delta', 'text': 'Tomorrow.'});
    h.line(done());
    await settle(t, 6);
    await t.tap(find.text('When is my next appointment?').last);
    await t.pump();
    expect(h.svc.to(route), hasLength(2));
    await h.close(t);
  });

  testWidgets('with reduced motion the answer shows at once and the dots stay still', (t) async {
    final h = Harness();
    await h.open(t, still: true);
    await h.type(t, 'What medicines do I take?');
    expect(find.byType(TypingBubble), findsOneWidget);
    h.line(meta());
    h.line({'type': 'delta', 'text': 'Aspirin 75 mg and Metoprolol 25 mg.'});
    await t.pump();
    await t.pump();
    expect(allText(t), contains('Aspirin 75 mg and Metoprolol 25 mg.'));
    await h.close(t);
  });

  testWidgets('a long press copies the answer without its citations', (t) async {
    final h = Harness();
    final copied = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await h.open(t);
    await h.type(t, 'q');
    h.line(meta());
    h.line({'type': 'delta', 'text': 'Aspirin 75 mg [1].'});
    h.line(done(sources: [appt]));
    await settle(t, 6);
    await t.longPress(bubbleOf('Aspirin'));
    await settle(t, 2);
    expect(copied, ['Aspirin 75 mg.']);
    expect(find.text('Copied'), findsOneWidget);
    await settle(t, 15);
    await h.close(t);
  });

  testWidgets('tapping a bubble shows its time', (t) async {
    final h = Harness();
    await h.open(t);
    await h.type(t, 'Hi there');
    await settle(t, 3); // let it land first
    final time = RegExp(r'^\d{1,2}:\d\d[\s\u202f][AP]M$'); // intl puts a narrow space before AM/PM
    final before = find.textContaining(time).evaluate().length;
    await t.tap(bubbleOf('Hi there'));
    await settle(t, 2);
    expect(find.textContaining(time).evaluate().length, before + 1);
    await h.close(t);
  });

  group('doctors and nurses', () {
    Future<RecordedService> start(WidgetTester t, String role) async {
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final svc = await openApp(t);
      await settle(t, 3);
      final button = find.widgetWithText(CupertinoButton, role);
      for (var i = 0; i < 30 && button.hitTestable().evaluate().isEmpty; i++) {
        await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -250));
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.tap(button.hitTestable().first);
      await settle(t, 10);
      return svc;
    }

    testWidgets('the Ask button on Today opens the chat about everyone they can see', (t) async {
      final svc = await start(t, 'Doctor');
      await t.tap(byLabel('Ask').hitTestable().first);
      await settle(t);
      expect(find.byType(StaffAskScreen), findsOneWidget);
      expect(svc.to('POST /chat/prepare').last.map, <String, dynamic>{});
      await t.tap(find.text('Who needs attention right now?'));
      await settle(t, 12);
      expect(svc.to(route).single.map, {'q': 'Who needs attention right now?'});
      expect(allText(t), contains('Here is what the records say about'));
      await t.tap(find.text('Open patient record').hitTestable().first);
      await settle(t);
      expect(find.byType(PatientDetailScreen), findsNothing); // the button opens the Patients section, not one record
    });

    testWidgets('a patient record asks about that patient only, and a source opens their record', (t) async {
      final svc = await start(t, 'Nurse');
      await t.tap(find.text(tr('Patients')).last);
      await settle(t);
      await t.tap(find.text('Farhan Ali').hitTestable().first);
      await settle(t);
      await t.tap(find.text('Ask').hitTestable().first);
      await settle(t);
      expect(find.text('Answers from this patient\'s records only'), findsOneWidget);
      expect(svc.to('POST /chat/prepare').last.map, {'focus': 'ex-farhan'});
      await t.tap(find.text('Summarise this patient'));
      await settle(t, 12);
      expect(svc.to(route).single.map, {'q': 'Summarise this patient', 'focus': 'ex-farhan'});
      await t.tap(byLabel('Source 1: Farhan Ali'));
      await settle(t);
      expect(find.byType(PatientDetailScreen), findsWidgets);
    });
  });
}
