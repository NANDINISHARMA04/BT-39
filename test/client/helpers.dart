// Shared pieces for the client tests: a fake PulseOS service built on
// `MockClient` (no network), and builders for the JSON the service sends.
import 'dart:async';
import 'dart:convert';

import 'package:bt39_care/services/pulse_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A JSON reply. Sent as UTF-8 bytes so ₹ and Hindi survive.
http.Response jsonReply(Object? body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

/// The service's error shape.
http.Response errorReply(int status, String code, String message) => jsonReply({'error': code, 'message': message}, status);

/// One request the fake service received.
class Seen {
  Seen(this.method, this.url, this.headers, this.body);
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;

  /// The route, without the `/v1/pulse` prefix and the query.
  String get path => url.path.replaceFirst('/v1/pulse', '');
  String get route => '$method $path';
  Object? get data => body.isEmpty ? null : jsonDecode(body);
  Map<String, dynamic> get map => Map<String, dynamic>.from(data as Map);
}

typedef Handler = FutureOr<http.Response> Function(Seen req);

/// A fake PulseOS service. Register a [Handler] per `'METHOD /path'`; anything
/// else answers 404. Every request is kept in [seen].
class FakeService {
  final seen = <Seen>[];
  final routes = <String, Handler>{};

  /// A client factory for [PulseApi], [Session] and the stores.
  http.Client client() => MockClient((req) async {
        final s = Seen(req.method, req.url, req.headers, req.body);
        seen.add(s);
        final h = routes[s.route];
        if (h == null) return errorReply(404, 'not_found', 'No such route: ${s.route}');
        return await h(s);
      });

  /// Replies with the same JSON every time.
  void on(String route, Object? body, [int status = 200]) => routes[route] = (_) => jsonReply(body, status);

  /// The requests made to [route], oldest first.
  List<Seen> to(String route) => seen.where((s) => s.route == route).toList();

  PulseApi api({Future<String?> Function()? token, void Function()? onDemoExpired}) =>
      PulseApi(token: token ?? () async => 'test-token', client: client, onDemoExpired: onDemoExpired);
}

/// Lets queued futures and timers of zero length run.
Future<void> settle([int ms = 30]) => Future<void>.delayed(Duration(milliseconds: ms));

/// Waits until [test] is true, or fails after [ms] milliseconds.
Future<void> until(bool Function() test, {int ms = 3000, String reason = 'condition'}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!test()) {
    if (DateTime.now().isAfter(end)) throw StateError('Timed out waiting for $reason');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

// ---------------------------------------------------------------------------
// The wearer stream

/// One reading window as `rec` in the service's lines.
Map<String, dynamic> rec(int t, {int hr = 66, int spo2 = 97, double temp = 36.5, double motion = .05, bool good = true, int alert = 0, bool held = false, bool fixed = false}) => {
      't': t, 'hr': hr, 'spo2': spo2, 'temp': temp, 'motion': motion, 'contact': .95, 'sqi': .95, 'act': 'Resting', 'ctx': 'rest',
      'good': good, 'fixed': fixed, 'mu': {'hr': 66.0, 'spo2': 97.3, 'temp': 36.55}, 'sd': {'hr': 6.0, 'spo2': 1.0, 'temp': .22},
      'z': {'hr': (hr - 66) / 6, 'spo2': (spo2 - 97.3) / 1.0, 'temp': (temp - 36.55) / .22}, 'alert': alert, 'held': held,
    };

/// An alert as the service sends it.
Map<String, dynamic> alertJson(int id, {int t = 100, int level = 2, Object? title, String? feedback, String doctor = 'pending', String? reviewedBy, bool safety = false, bool autoSos = false, Map<String, dynamic>? explain, double tau = .5}) => {
      'id': id, 't': t, 'level': level,
      'title': title ?? {'t': 'Heart rate above your normal'},
      'reasons': [
        {'t': 'Heart rate {hr} bpm, {pc}% above your usual resting {mu} bpm', 'a': {'hr': 89, 'pc': 35, 'mu': 66}},
        'Signal quality good (0.95)',
      ],
      'path': [{'t': 'Moderate heart-rate rise at rest'}],
      'p': .58, 'pg': .58, 'pu': .5, 'w': 0, 'n': 0, 'tau': tau, 'key': 'rest|hr|mod|day', 'safety': safety,
      'hr': 89, 'spo2': 97, 'temp': 36.6, 'feedback': feedback, 'doctor': doctor, 'reviewed_by': reviewedBy,
      'escalation': [
        {'t': t, 'who': 'You', 'what': {'t': 'Phone notification'}},
      ],
      'auto_sos': autoSos,
      'explain': explain ?? {'ci': {'lo': .2, 'hi': .8}, 'single_p': null, 'if_false': .45, 'tau_false': .53, 'if_real': .7, 'tau_real': .45},
    };

Map<String, dynamic> heldJson(int t, {double p = .31}) => {'t': t, 'key': 'rest|hr|mod|day', 'p': p, 'tau': .5, 'pg': .58, 'pu': .1, 'n': 2, 'rec': rec(t, hr: 88, held: true)};

Map<String, dynamic> bucketJson(String key, {double r = 0, double f = 1.5, double p = .41, bool send = false}) => {'key': key, 'r': r, 'f': f, 'p': p, 'send': send};

Map<String, dynamic> pipeJson() => {
      'A': {'s': 'ok', 'x': {'t': 'Quality {q} · good, use it', 'a': {'q': '0.95'}}},
      'B': {'s': 'ok', 'x': 'Resting · motion 0.05 g'},
      'C': {'s': 'ok', 'x': 'z · HR +0.0'},
      'D': {'s': 'ok', 'x': {'t': 'Clear'}},
      'E': {'s': 'ok', 'x': {'t': 'Within your normal range'}},
      'F': {'s': 'idle', 'x': 'No decision needed'},
      'G': {'s': 'idle', 'x': '—'},
    };

Map<String, dynamic> baseJson({double hr = 66.4}) => {
      for (final c in ['rest', 'light', 'active'])
        c: {'hr': {'mu': hr, 'sd': 6.0}, 'spo2': {'mu': 97.3, 'sd': 1.0}, 'temp': {'mu': 36.55, 'sd': .22}},
    };

/// The `state` of a snapshot line.
Map<String, dynamic> stateJson({int t = 512, double tau = .53, List<Map<String, dynamic>>? alerts, List<Map<String, dynamic>>? held, List<Map<String, dynamic>>? history, List<Map<String, dynamic>>? buckets, String status = 'ok', int labels = 2, int fixed = 3, int sent = 1}) => {
      't': t, 'tau': tau, 'week_start_tau': .5, 'sqi_min': .5, 'labels': labels, 'fixed': fixed, 'sent': sent, 'status': status,
      'base': baseJson(), 'buckets': buckets ?? [bucketJson('rest|hr|mod|day')], 'alerts': alerts ?? [], 'held': held ?? [],
      'history': history ?? [for (var i = 0; i < 5; i++) rec(t - 5 + i)], 'pipe': pipeJson(),
    };

Map<String, dynamic> snapshotLine({int version = 7, Map<String, dynamic>? state, String scenario = 'rest', int minutesLeft = 0, bool paused = false, bool fast = false}) => {
      'type': 'snapshot', 'version': version, 'state': state ?? stateJson(),
      'scenario': {'id': scenario, 'minutes_left': minutesLeft}, 'paused': paused, 'fast': fast,
    };

Map<String, dynamic> updateLine({int version = 7, int t = 513, Map<String, dynamic>? rec_, List<Map<String, dynamic>> alerts = const [], List<Map<String, dynamic>> heldNew = const [], List<Map<String, dynamic>> events = const [], String? scenario, int minutesLeft = 0, bool? paused, bool? fast, List<Map<String, dynamic>>? buckets, Map<String, dynamic> extra = const {}}) => {
      'type': 'update', 'version': version, 't': t, 'rec': rec_, 'pipe': pipeJson(), 'status': 'ok', 'tau': .53, 'week_start_tau': .5, 'sqi_min': .5,
      'labels': 2, 'fixed': 3, 'sent': 1, 'base': baseJson(), 'buckets': ?buckets, 'alerts': alerts, 'held_new': heldNew,
      'scenario': ?(scenario == null ? null : {'id': scenario, 'minutes_left': minutesLeft}),
      'paused': ?paused,
      'fast': ?fast,
      'events': events,
      ...extra,
    };

// ---------------------------------------------------------------------------
// Streams

/// A [FakeService] that can also hold streams open (`GET /wearer/live`,
/// `GET /ward/live`). Register the routes with [stream]; each request to one
/// opens a connection the test feeds with [send] and ends with [drop].
class LiveService extends FakeService {
  final _routes = <String>{};
  final _open = <String, List<StreamController<List<int>>>>{};

  /// Routes answered with a refusal instead of a stream: status, code, message.
  final refused = <String, (int, String, String)>{};

  void stream(String route) => _routes.add(route);

  /// The connections opened to [route] so far, oldest first.
  List<StreamController<List<int>>> opened(String route) => _open[route] ?? [];

  /// Writes one line on the newest connection to [route].
  void send(String route, Map<String, dynamic> line) => opened(route).last.add(utf8.encode('${jsonEncode(line)}\n'));

  /// Writes raw text on the newest connection.
  void sendRaw(String route, String text) => opened(route).last.add(utf8.encode(text));

  /// Ends the newest connection to [route], as a dropped network would.
  Future<void> drop(String route) => opened(route).last.close();

  @override
  http.Client client() => MockClient.streaming((req, bodyStream) async {
        final s = Seen(req.method, req.url, req.headers, await bodyStream.bytesToString());
        seen.add(s);
        if (_routes.contains(s.route)) {
          final no = refused[s.route];
          if (no != null) return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode({'error': no.$2, 'message': no.$3}))), no.$1);
          final c = StreamController<List<int>>();
          (_open[s.route] ??= []).add(c);
          return http.StreamedResponse(c.stream, 200);
        }
        final h = routes[s.route];
        final r = h == null ? errorReply(404, 'not_found', 'No such route: ${s.route}') : await h(s);
        return http.StreamedResponse(Stream.value(r.bodyBytes), r.statusCode, headers: r.headers);
      });
}
