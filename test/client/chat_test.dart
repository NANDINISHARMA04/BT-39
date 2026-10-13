// The chat client and its view model: the request it sends, the stream it reads, and every way an answer can end.
import 'dart:async';

import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/services/chat.dart';
import 'package:bt39_care/services/chat_controller.dart';
import 'package:bt39_care/services/pulse_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const route = 'POST /chat';

Map<String, dynamic> meta({bool urgent = false, String? action, Object? label, List<String> suggestions = const []}) =>
    {'type': 'meta', 'urgent': urgent, 'action': action, 'action_label': label, 'suggestions': suggestions, 'intent': 'data'};

Map<String, dynamic> done({List<Map<String, dynamic>> sources = const [], String? cached, String? fallback, String? action}) =>
    {'type': 'done', 'sources': sources, 'cached': cached, 'fallback': fallback, 'tokens': 830, 'cost': 0.00004, 'ms': 1200, 'action': action, 'action_label': null, 'intent': 'data'};

Map<String, dynamic> source(int n, {String kind = 'appointment', String title = 'Dr. Kavya Rao', String? action = 'book', String? ref}) =>
    {'n': n, 'id': 'appt:a$n', 'kind': kind, 'title': title, 'snippet': 'Appointment with Dr. Kavya Rao', 'action': action, 'ref': ref};

void main() {
  setUp(() => appLang.value = 'en');

  group('PulseChat', () {
    test('sends the question, the focus and the history, and reads every kind of line', () async {
      final svc = FakeService();
      svc.routes[route] = (s) => ndjsonReply([
            meta(action: 'book', label: {'t': 'Manage appointments'}, suggestions: ['When is my next appointment?']),
            {'type': 'delta', 'text': 'Tomorrow at 11:30 '},
            {'type': 'delta', 'text': '[1].'},
            {'type': 'something new', 'x': 1},
            done(sources: [source(1)], cached: 'near'),
          ]);
      final events = await PulseChat(svc.api()).ask('When?', focus: 'ex-farhan', history: const [ChatTurn(true, 'Hi'), ChatTurn(false, 'Hello')]).toList();
      expect(svc.to(route).single.map, {
        'q': 'When?',
        'focus': 'ex-farhan',
        'history': [
          {'role': 'user', 'text': 'Hi'},
          {'role': 'assistant', 'text': 'Hello'},
        ],
      });
      expect(events.map((e) => e.runtimeType), [ChatMeta, ChatDeltaText, ChatDeltaText, ChatEnd]); // the unknown line is skipped
      final m = events.first as ChatMeta;
      expect((m.action, m.urgent), ('book', false));
      expect(m.suggestions, ['When is my next appointment?']);
      expect(m.actionLabel, {'t': 'Manage appointments'});
      final end = events.last as ChatEnd;
      expect((end.cached, end.fallback, end.tokens, end.cost, end.ms), ('near', null, 830, 0.00004, 1200));
      expect((end.sources.single.n, end.sources.single.kind, end.sources.single.action), (1, 'appointment', 'book'));
    });

    test('a question alone carries no focus and no history', () async {
      final svc = FakeService();
      svc.routes[route] = (s) => ndjsonReply([meta(), done()]);
      await PulseChat(svc.api()).ask('hi').toList();
      expect(svc.to(route).single.map, {'q': 'hi'});
    });

    test('a refusal arrives as an ApiException with the service sentence', () async {
      final svc = FakeService();
      svc.routes[route] = (s) => errorReply(429, 'rate_limited', 'Too many tries. Please wait a few minutes and try again.');
      await expectLater(
        PulseChat(svc.api()).ask('hi').toList(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 429).having((e) => e.message, 'message', 'Too many tries. Please wait a few minutes and try again.')),
      );
    });

    test('prepare sends the focus and never throws', () async {
      final svc = FakeService();
      svc.on('POST /chat/prepare', {'ready': true});
      await PulseChat(svc.api()).prepare(focus: 'B02');
      expect(svc.to('POST /chat/prepare').single.map, {'focus': 'B02'});
      final down = FakeService(); // every route is a 404
      await PulseChat(down.api()).prepare();
    });
  });

  group('ChatController', () {
    late LiveService svc;
    late ChatController c;
    late List<ChatBeat> beats;

    setUp(() {
      svc = LiveService()..stream(route);
      c = ChatController(PulseChat(svc.api()), greeting: 'Hi Jai.');
      beats = [];
      c.beats.listen(beats.add);
    });
    tearDown(() => c.dispose());

    Future<void> answer(String q, List<Map<String, dynamic>> lines) async {
      final sending = c.send(q);
      await until(() => svc.opened(route).isNotEmpty && svc.opened(route).length == svc.to(route).length);
      for (final l in lines) {
        svc.send(route, l);
        await settle();
      }
      await sending;
    }

    test('a question goes from sending to delivered, the answer from typing dots to done', () async {
      final sending = c.send('When is my next appointment?');
      await until(() => svc.opened(route).isNotEmpty);
      final mine = c.messages[1], reply = c.messages[2];
      expect((mine.mine, mine.state, reply.waiting, c.busy), (true, ChatState.sending, true, true));
      svc.send(route, meta(action: 'book'));
      await settle();
      expect((mine.state, reply.waiting, reply.action), (ChatState.delivered, true, 'book'));
      svc.send(route, {'type': 'delta', 'text': 'Tomorrow '});
      await settle();
      expect((reply.state, reply.text), (ChatState.streaming, 'Tomorrow '));
      svc.send(route, {'type': 'delta', 'text': 'at 11:30 [1].'});
      svc.send(route, done(sources: [source(1)]));
      await sending;
      expect((reply.state, reply.shown, reply.sources.single.title, c.busy), (ChatState.done, 'Tomorrow at 11:30 [1].', 'Dr. Kavya Rao', false));
      expect(beats, [ChatBeat.sent, ChatBeat.firstWord, ChatBeat.finished]);
    });

    test('one question at a time, and blank questions are ignored', () async {
      final first = c.send('one');
      await c.send('two');
      await c.send('   ');
      await until(() => svc.opened(route).isNotEmpty);
      expect(svc.to(route), hasLength(1));
      svc.send(route, meta());
      svc.send(route, done());
      await first;
      expect(c.messages.where((m) => m.mine).map((m) => m.text), ['one']);
    });

    test('the earlier turns go with the next question, never the greeting, at most four', () async {
      for (var i = 0; i < 3; i++) {
        await answer('q$i', [meta(), {'type': 'delta', 'text': 'a$i'}, done()]);
      }
      final sending = c.send('q3');
      await until(() => svc.to(route).length == 4);
      expect(svc.to(route).last.map['history'], [
        {'role': 'user', 'text': 'q1'},
        {'role': 'assistant', 'text': 'a1'},
        {'role': 'user', 'text': 'q2'},
        {'role': 'assistant', 'text': 'a2'},
      ]);
      svc.send(route, meta());
      svc.send(route, done());
      await sending;
    });

    test('an urgent answer says so at once, before any word', () async {
      final sending = c.send('I have chest pain');
      await until(() => svc.opened(route).isNotEmpty);
      svc.send(route, meta(urgent: true, action: 'sos', label: {'t': 'Open SOS'}));
      await settle();
      final reply = c.messages.last;
      expect((reply.urgent, reply.action, reply.waiting), (true, 'sos', true));
      expect(beats, [ChatBeat.sent, ChatBeat.urgent]);
      svc.send(route, {'type': 'answer', 'msg': {'t': 'This could be an emergency. Please don\'t wait for an alert.'}});
      svc.send(route, done(fallback: 'budget'));
      await sending;
      expect((reply.shown, reply.fallback), ('This could be an emergency. Please don\'t wait for an alert.', 'budget'));
    });

    test('the free answer follows the app language when it is shown', () async {
      await answer('q', [meta(), {'type': 'answer', 'msg': {'t': 'Open records'}}, done(fallback: 'cap')]);
      final reply = c.messages.last;
      expect(reply.shown, 'Open records');
      appLang.value = 'hi';
      expect(reply.shown, tr('Open records'));
    });

    test('nothing back: the question is not delivered, and tapping it sends it again', () async {
      svc.refused[route] = (0, 'unreachable', 'gone');
      final f = FakeService(); // a network error: every route answers 404 on a plain client
      final broken = ChatController(PulseChat(f.api()));
      await broken.send('hello');
      final mine = broken.messages.single;
      expect((mine.state, mine.problem, broken.busy), (ChatState.failed, 'No such route: POST /chat', false));
      f.routes[route] = (s) => ndjsonReply([meta(), {'type': 'delta', 'text': 'Hi'}, done()]);
      await broken.retry(mine);
      expect(broken.messages.map((m) => (m.mine, m.state)), [(true, ChatState.delivered), (false, ChatState.done)]);
      broken.dispose();
    });

    test('a connection that drops before the first line is "not delivered"', () async {
      final sending = c.send('hello');
      await until(() => svc.opened(route).isNotEmpty);
      await svc.drop(route);
      await sending;
      final mine = c.messages.last;
      expect((mine.mine, mine.state, mine.problem), (true, ChatState.failed, 'Not delivered. Check your connection and tap to try again.'));
      expect(c.messages.where((m) => !m.mine && !m.isGreeting), isEmpty);
      expect(beats.last, ChatBeat.failed);
    });

    test('a connection that drops after the first line leaves the answer cut off', () async {
      final sending = c.send('hello');
      await until(() => svc.opened(route).isNotEmpty);
      svc.send(route, meta());
      await settle();
      await svc.drop(route);
      await sending;
      expect((c.messages[1].state, c.messages.last.state, c.messages.last.problem), (ChatState.delivered, ChatState.failed, 'The answer was cut off. Please ask again.'));
    });

    test('cut off half way: the words stay and a warning follows', () async {
      await answer('q', [meta(), {'type': 'delta', 'text': 'Your next'}, {'type': 'error', 'message': 'The assistant could not finish that answer. Please ask again.'}, done(fallback: 'cut_off')]);
      final reply = c.messages.last;
      expect((reply.state, reply.text, reply.problem), (ChatState.done, 'Your next', 'The assistant could not finish that answer. Please ask again.'));
    });

    test('staff answers take their button from the last line', () async {
      await answer('q', [meta(), {'type': 'delta', 'text': 'x'}, {...done(action: 'staff:patients'), 'action_label': {'t': 'Open patient record'}}]);
      expect(c.messages.last.action, 'staff:patients');
      expect(c.messages.last.actionLabel, {'t': 'Open patient record'});
    });

    test('closing the chat mid-answer stops it quietly', () async {
      unawaited(c.send('q'));
      await until(() => svc.opened(route).isNotEmpty);
      c.dispose();
      svc.send(route, meta());
      await settle();
      c = ChatController(PulseChat(svc.api())); // for tearDown
    });
  });
}
