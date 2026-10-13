import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/services/assistant.dart';
import 'package:bt39_care/services/pulse_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

Map<String, dynamic> answer({Object? text, String? action, Object? label, bool urgent = false, String? topic, List<String> suggestions = const []}) =>
    {'text': text ?? 'Hello.', 'action': action, 'action_label': label, 'urgent': urgent, 'topic': topic, 'suggestions': suggestions};

void main() {
  setUp(() => appLang.value = 'en');
  tearDown(() => appLang.value = 'en');

  test('the question goes to POST /assistant as {q}', () async {
    final svc = FakeService()..on('POST /assistant', answer());
    await HealthAssistant(svc.api()).reply('Where are my reports?');
    final req = svc.to('POST /assistant').single;
    expect(req.map, {'q': 'Where are my reports?'});
    expect(req.headers['Authorization'], 'Bearer test-token');
    expect(req.headers['X-Lang'], 'en');
  });

  test('a help answer with a button and follow-up questions', () async {
    final svc = FakeService()
      ..on(
        'POST /assistant',
        answer(
          text: {
            'c': [
              {'t': 'Your reports and medical records are kept in Me → Medical records.'},
              '\n\n1. ',
              {'t': 'Tap Me at the bottom of the screen.'},
            ],
          },
          action: 'records',
          label: {'t': 'Open medical records'},
          topic: 'records',
          suggestions: ['Where are my medicines?', 'I feel unwell'],
        ),
      );
    final r = await HealthAssistant(svc.api()).reply('where are my reports');
    expect(r.text, 'Your reports and medical records are kept in Me → Medical records.\n\n1. Tap Me at the bottom of the screen.');
    expect(r.action, 'records');
    expect(HealthAssistant.actions, contains(r.action));
    expect(r.actionLabel, 'Open medical records');
    expect(r.urgent, isFalse);
    expect(r.topic, 'records');
    expect(r.suggestions, ['Where are my medicines?', 'I feel unwell']);
  });

  test('an urgent answer', () async {
    final svc = FakeService()..on('POST /assistant', answer(text: {'t': 'This could be an emergency. Please don\'t wait for an alert.'}, action: 'sos', label: {'t': 'Open SOS'}, urgent: true));
    final r = await HealthAssistant(svc.api()).reply('I have chest pain');
    expect(r.urgent, isTrue);
    expect(r.action, 'sos');
    expect(r.topic, isNull);
    expect(r.suggestions, isEmpty);
    expect(r.text, startsWith('This could be an emergency'));
  });

  test('an answer from the person\'s data, with no button', () async {
    final svc = FakeService()..on('POST /assistant', answer(text: 'Heart rate 72 bpm, normal for you.'));
    final r = await HealthAssistant(svc.api()).reply('How is my heart?');
    expect(r.text, 'Heart rate 72 bpm, normal for you.');
    expect(r.action, isNull);
    expect(r.actionLabel, isNull);
    expect(r.urgent, isFalse);
    expect(r.suggestions, isEmpty);
  });

  test('numbers and times inside an answer are formatted on the phone', () async {
    final svc = FakeService()
      ..on(
        'POST /assistant',
        answer(text: {
          't': '₹{left} left of ₹{total}.',
          'a': {
            'left': {'num': 605000, 'f': 'en_IN'},
            'total': {'num': 1000000, 'f': 'en_IN'},
          },
        }),
      );
    expect((await HealthAssistant(svc.api()).reply('insurance')).text, '₹6,05,000 left of ₹10,00,000.');
  });

  test('in Hindi the header says so and the answer is shown in Hindi', () async {
    appLang.value = 'hi';
    final svc = FakeService()..on('POST /assistant', answer(text: {'t': 'Please sign in.'}, action: 'me', label: {'t': 'Open SOS'}));
    final r = await HealthAssistant(svc.api()).reply('मेरी दवा कहाँ है');
    expect(svc.to('POST /assistant').single.headers['X-Lang'], 'hi');
    expect(svc.to('POST /assistant').single.map['q'], 'मेरी दवा कहाँ है');
    expect(r.text, 'कृपया साइन इन करें।');
    expect(r.actionLabel, isNot('Open SOS'));
  });

  test('when the service refuses, the reply says why and has the topic error', () async {
    final svc = FakeService();
    svc.routes['POST /assistant'] = (_) => errorReply(429, 'rate_limited', 'You are asking too fast. Wait a moment.');
    final r = await HealthAssistant(svc.api()).reply('hello');
    expect(r.topic, 'error');
    expect(r.text, 'You are asking too fast. Wait a moment.');
    expect(r.action, isNull);
    expect(r.urgent, isFalse);
  });

  test('when the service cannot be reached, the reply says so', () async {
    final api = PulseApi(token: () async => 't', client: () => MockClient((_) async => throw http.ClientException('offline')));
    final r = await HealthAssistant(api).reply('hello');
    expect(r.topic, 'error');
    expect(r.text, 'The service could not be reached. It may be waking up. Try again in a minute.');
  });

  test('the lists the assistant screen uses', () {
    expect(HealthAssistant.actions, containsAll(['sos', 'records', 'healthProfile', 'insurance', 'family', 'callFamily', 'medicalId', 'book', 'findDoctor', 'alerts', 'alertDetail', 'insights', 'howItWorks', 'research', 'me', 'language', 'accessibility', 'simulator']));
    expect(HealthAssistant.suggestions.length, 7);
    expect(HealthAssistant.suggestions.first, 'How am I doing today?');
    expect(HealthAssistant.helpSuggestions.length, 6);
    expect(HealthAssistant.helpSuggestions, contains('I feel unwell'));
  });

  test('a reply built by hand has the defaults the screens expect', () {
    final r = AssistantReply('Hi');
    expect(r.text, 'Hi');
    expect(r.urgent, isFalse);
    expect(r.suggestions, isEmpty);
    expect(r.topic, isNull);
  });
}
