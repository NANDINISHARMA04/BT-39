import 'dart:async';
import 'dart:convert';

import 'package:bt39_care/config.dart';
import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/services/bt39_client.dart' as legacy;
import 'package:bt39_care/services/pulse_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

void main() {
  setUp(() => appLang.value = 'en');
  tearDown(() => appLang.value = 'en');

  group('requests', () {
    test('go to /v1/pulse on the BT39 service with the bearer token', () async {
      final svc = FakeService()..on('GET /me', {'role': 'patient'});
      final r = await svc.api().get('/me');
      expect(r.ok, isTrue);
      expect(r.map['role'], 'patient');
      final req = svc.seen.single;
      expect(req.url.toString(), '${AppConfig.bt39Api}/v1/pulse/me');
      expect(req.headers['Authorization'], 'Bearer test-token');
    });

    test('send the time zone, the language and JSON headers', () async {
      final svc = FakeService()..on('POST /assistant', {'text': 'ok'});
      await svc.api().post('/assistant', {'q': 'hello'});
      var h = svc.seen.single.headers;
      expect(h['X-Tz-Offset'], '${DateTime.now().timeZoneOffset.inMinutes}');
      expect(h['X-Lang'], 'en');
      expect(h['Content-Type'], startsWith('application/json'));
      expect(svc.seen.single.map, {'q': 'hello'});

      appLang.value = 'hi';
      await svc.api().post('/assistant', {'q': 'namaste'});
      h = svc.seen.last.headers;
      expect(h['X-Lang'], 'hi', reason: 'read when the request is made, so a language switch applies at once');
    });

    test('use the verb of the method called', () async {
      final svc = FakeService();
      for (final m in ['GET', 'POST', 'PUT', 'DELETE']) {
        svc.on('$m /x', {'m': m});
      }
      final api = svc.api();
      expect((await api.get('/x')).map['m'], 'GET');
      expect((await api.post('/x', {'a': 1})).map['m'], 'POST');
      expect((await api.put('/x', {'a': 1})).map['m'], 'PUT');
      expect((await api.delete('/x')).map['m'], 'DELETE');
      expect(svc.seen[1].map, {'a': 1});
      expect(svc.seen[0].body, isEmpty, reason: 'no body when none is given');
    });

    test('with no token there is no Authorization header', () async {
      final svc = FakeService()..on('GET /me', {});
      await svc.api(token: () async => null).get('/me');
      expect(svc.seen.single.headers.containsKey('Authorization'), isFalse);
    });

    test('postPublic never sends the token', () async {
      final svc = FakeService()..on('POST /demo/start', {'token': 'pd1.x.y'});
      final r = await svc.api().postPublic('/demo/start', {'role': 'patient'});
      expect(r.map['token'], 'pd1.x.y');
      final h = svc.seen.single.headers;
      expect(h.containsKey('Authorization'), isFalse);
      expect(h['X-Lang'], 'en');
    });

    test('a path without a leading slash and a base with a trailing slash still join', () async {
      final svc = FakeService()..on('GET /me', {});
      final api = PulseApi(token: () async => null, base: 'https://example.test/v1/pulse/', client: svc.client);
      await api.get('me');
      expect(svc.seen.single.url.toString(), 'https://example.test/v1/pulse/me');
    });

    test('a query string in the path is kept', () async {
      final svc = FakeService()..on('GET /doctors/d1/slots', {'days': {}});
      await svc.api().get('/doctors/d1/slots?from=2026-10-14&days=14');
      expect(svc.seen.single.url.queryParameters, {'from': '2026-10-14', 'days': '14'});
    });

    test('read a body written in UTF-8 even when the reply names no charset', () async {
      final svc = FakeService()..on('GET /x', {'text': 'दिल की धड़कन ₹6,05,000'});
      expect((await svc.api().get('/x')).map['text'], 'दिल की धड़कन ₹6,05,000');
    });

    test('a success with no body is still a success', () async {
      final svc = FakeService()..routes['POST /demo/end'] = (_) => http.Response('', 204);
      final r = await svc.api().post('/demo/end');
      expect(r.ok, isTrue);
      expect(r.data, isNull);
      expect(r.map, isEmpty);
    });
  });

  group('errors', () {
    test('the service\'s own sentence is used', () async {
      final svc = FakeService()..routes['POST /signup'] = (_) => errorReply(409, 'email_taken', 'An account with this email already exists.');
      final r = await svc.api().postPublic('/signup', {});
      expect(r.ok, isFalse);
      expect(r.status, 409);
      expect(r.error, 'email_taken');
      expect(r.message, 'An account with this email already exists.');
    });

    test('with no sentence from the service, the generic one is used', () async {
      final svc = FakeService()..routes['GET /x'] = (_) => http.Response('<html>Bad gateway</html>', 502);
      final r = await svc.api().get('/x');
      expect(r.ok, isFalse);
      expect(r.status, 502);
      expect(r.error, 'unavailable');
      expect(r.message, 'The service is not answering. It may be waking up. Try again in a minute.');
    });

    test('the generic sentence follows the language', () async {
      appLang.value = 'hi';
      final svc = FakeService()..routes['GET /x'] = (_) => http.Response('', 503);
      final r = await svc.api().get('/x');
      expect(r.message, tr('The service is not answering. It may be waking up. Try again in a minute.'));
      expect(r.message, isNot(startsWith('The service')));
    });

    test('a network failure is status 0 with the unreachable sentence', () async {
      final api = PulseApi(token: () async => 't', client: () => MockClient((_) async => throw http.ClientException('no route')));
      final r = await api.get('/me');
      expect(r.ok, isFalse);
      expect(r.status, 0);
      expect(r.error, 'unreachable');
      expect(r.message, 'The service could not be reached. It may be waking up. Try again in a minute.');
    });

    test('a token that cannot be read is a failure, not a crash', () async {
      final svc = FakeService()..on('GET /me', {});
      final r = await svc.api(token: () async => throw StateError('no storage')).get('/me');
      expect(r.ok, isFalse);
      expect(r.error, 'unreachable');
    });

    test('401 demo_expired calls onDemoExpired, once per answer', () async {
      var expired = 0;
      final svc = FakeService()..routes['GET /me/data'] = (_) => errorReply(401, 'demo_expired', 'This demo has ended.');
      final api = svc.api(onDemoExpired: () => expired++);
      final r = await api.get('/me/data');
      expect(r.status, 401);
      expect(r.message, 'This demo has ended.');
      expect(expired, 1);
      await api.get('/me/data');
      expect(expired, 2);
    });

    test('other 401s and other errors do not call it', () async {
      var expired = 0;
      final svc = FakeService();
      svc.routes['GET /a'] = (_) => errorReply(401, 'unauthorized', 'Please sign in.');
      svc.routes['GET /b'] = (_) => errorReply(403, 'demo_expired', 'x');
      svc.routes['GET /c'] = (_) => errorReply(500, 'boom', 'x');
      final api = svc.api(onDemoExpired: () => expired++);
      await api.get('/a');
      await api.get('/b');
      await api.get('/c');
      expect(expired, 0);
    });

    test('ApiResult stays importable from bt39_client.dart', () {
      expect(legacy.ApiResult.ok({'a': 1}).map, {'a': 1});
      expect(legacy.ApiResult.fail(500, 'x', 'y').ok, isFalse);
    });
  });

  group('lines', () {
    /// A client whose streamed reply is fed by the test.
    ({http.Client client, StreamController<List<int>> body, List<http.BaseRequest> sent}) streamed({int status = 200}) {
      final body = StreamController<List<int>>();
      final sent = <http.BaseRequest>[];
      final client = MockClient.streaming((req, _) async {
        sent.add(req);
        return http.StreamedResponse(body.stream, status);
      });
      return (client: client, body: body, sent: sent);
    }

    test('give one object per line, whatever the chunk boundaries', () async {
      final s = streamed();
      final api = PulseApi(token: () async => 'tok', client: () => s.client);
      final got = <Map<String, dynamic>>[];
      final done = api.lines('/wearer/live', s.client).forEach(got.add);

      final bytes = utf8.encode('{"type":"snapshot","text":"धड़कन ₹"}\n{"type":"update","n":1}\n\n{"type":"ping"}\n{"type":"update","n":2}');
      // Cut in the middle of a line and in the middle of a multi-byte character.
      final cut1 = bytes.indexOf(0xe0) + 1, cut2 = bytes.length - 9;
      s.body
        ..add(bytes.sublist(0, 12))
        ..add(bytes.sublist(12, cut1))
        ..add(bytes.sublist(cut1, cut2))
        ..add(bytes.sublist(cut2));
      await s.body.close();
      await done;

      expect(got.map((m) => m['type']), ['snapshot', 'update', 'ping', 'update']);
      expect(got.first['text'], 'धड़कन ₹');
      expect(got[1]['n'], 1);
      expect(got.last['n'], 2, reason: 'the last line needs no newline');
    });

    test('several lines in one chunk', () async {
      final s = streamed();
      final got = <Map<String, dynamic>>[];
      final done = PulseApi(token: () async => null).lines('/x', s.client).forEach(got.add);
      s.body.add(utf8.encode('{"a":1}\n{"a":2}\n{"a":3}\n'));
      await s.body.close();
      await done;
      expect(got.map((m) => m['a']), [1, 2, 3]);
    });

    test('lines that are not JSON objects are skipped', () async {
      final s = streamed();
      final got = <Map<String, dynamic>>[];
      final done = PulseApi(token: () async => null).lines('/x', s.client).forEach(got.add);
      s.body.add(utf8.encode('not json\n[1,2]\n"text"\n{"a":1}\n{"broken\n{"a":2}\n'));
      await s.body.close();
      await done;
      expect(got.map((m) => m['a']), [1, 2]);
    });

    test('the request carries the same headers as other calls', () async {
      final s = streamed();
      appLang.value = 'hi';
      final api = PulseApi(token: () async => 'tok', client: () => s.client);
      final done = api.lines('/ward/live', s.client).drain<void>();
      await settle();
      await s.body.close();
      await done;
      final req = s.sent.single;
      expect(req.method, 'GET');
      expect(req.url.toString(), '${AppConfig.bt39Api}/v1/pulse/ward/live');
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(req.headers['X-Lang'], 'hi');
      expect(req.headers['X-Tz-Offset'], '${DateTime.now().timeZoneOffset.inMinutes}');
    });

    test('a refused stream throws with the service\'s sentence', () async {
      final client = MockClient.streaming((req, _) async => http.StreamedResponse(Stream.value(utf8.encode('{"error":"forbidden","message":"Staff only."}')), 403));
      final api = PulseApi(token: () async => 'tok');
      await expectLater(
        api.lines('/ward/live', client).toList(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403).having((e) => e.error, 'error', 'forbidden').having((e) => e.message, 'message', 'Staff only.')),
      );
    });

    test('a refused stream with demo_expired calls onDemoExpired', () async {
      var expired = 0;
      final client = MockClient.streaming((req, _) async => http.StreamedResponse(Stream.value(utf8.encode('{"error":"demo_expired","message":"Over."}')), 401));
      final api = PulseApi(token: () async => 'tok', onDemoExpired: () => expired++);
      await expectLater(api.lines('/wearer/live', client).toList(), throwsA(isA<ApiException>()));
      expect(expired, 1);
    });

    /// Listens to a stream and finishes when it ends, keeping what it said.
    Future<({List<Map<String, dynamic>> got, Object? failure})> collect(Stream<Map<String, dynamic>> lines) {
      final got = <Map<String, dynamic>>[];
      Object? failure;
      final end = Completer<({List<Map<String, dynamic>> got, Object? failure})>();
      lines.listen(got.add, onError: (Object e) => failure = e, onDone: () => end.complete((got: got, failure: failure)));
      return end.future;
    }

    test('a stream that goes quiet times out', () async {
      final s = streamed();
      final done = collect(PulseApi(token: () async => null).lines('/x', s.client, idle: const Duration(milliseconds: 80)));
      s.body.add(utf8.encode('{"a":1}\n'));
      final r = await done;
      expect(r.got.single['a'], 1);
      expect(r.failure, isA<TimeoutException>());
    });

    test('a steady stream does not time out', () async {
      final s = streamed();
      final done = collect(PulseApi(token: () async => null).lines('/x', s.client, idle: const Duration(milliseconds: 600)));
      for (var i = 0; i < 5; i++) {
        s.body.add(utf8.encode('{"a":$i}\n'));
        await settle(40);
      }
      await s.body.close();
      final r = await done;
      expect(r.got.length, 5);
      expect(r.failure, isNull);
    });
  });
}
