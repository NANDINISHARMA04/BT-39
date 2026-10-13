// A PulseOS service that replays what the real one said, so widget tests run without a network.
//
// The replies are in test/fixtures/service/, recorded from a running service by tool/record_service_fixtures.py. A
// RecordedService answers every route the screens call from those files, keeps the live streams open with the
// recorded lines, and applies a write (a note, a visit, a label, a task, a preference...) to its own copy of the
// recorded document and answers with the whole document, as the real service does. Like the real service it
// refuses a call that has no token (401) or the wrong role (403).
//
// The dates in the recordings are moved by whole days so that "today" in a recording is today now. A recorded visit
// that was today is still today, whenever the test runs.
//
// Plug it into the app the way the client tests do: a Session built with the fake http client and an api base.
//
//     final svc = RecordedService();
//     await tester.pumpWidget(BT39App(session: svc.session()));
//
// or `final svc = await openApp(tester);`. Routes that no recording answers are listed in [misses] and fail the test
// when it ends. A test can change an answer with `svc.routes['GET /labels'] = (_) => errorReply(500, ...)`, and add a
// line to a live stream with `svc.send('GET /wearer/live', updateLine(...))`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bt39_care/app.dart';
import 'package:bt39_care/engine/simulator.dart' show scenarioById, scenarios;
import 'package:bt39_care/l10n/hi.dart';
import 'package:bt39_care/services/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../client/helpers.dart';

typedef Json = Map<String, dynamic>;

/// An account that signed up (or that a test added) on the fake sign-in and PulseOS service.
class Account {
  Account({required this.role, required this.name, required this.email, required this.password, this.details = const {}});
  final String role, name, email, password;
  final Map<String, String> details;
}

/// Opens the app on [svc] (a new [RecordedService] when none is given) and returns the service. [withAccounts] lets
/// the app sign in and sign up (a fake Supabase sign-in on the same service).
Future<RecordedService> openApp(WidgetTester t, {RecordedService? svc, bool withAccounts = false}) async {
  final s = svc ?? RecordedService();
  await t.pumpWidget(BT39App(session: s.session(withAccounts: withAccounts)));
  return s;
}

class RecordedService extends FakeService {
  RecordedService() {
    addTearDown(() => expect(misses, isEmpty, reason: 'The app called routes that no recording answers'));
    _install();
  }

  /// Where the recordings are, from the package root (where `flutter test` runs).
  static const dir = 'test/fixtures/service';

  /// The api base the app is given. Nothing is sent there: every request ends in the fake client.
  static const apiBase = 'https://pulse.test/v1/pulse';

  /// The "access token" the fake sign-in service hands out.
  static const jwt = 'header.payload.signature';

  /// Routes that were called and have no answer, as `'METHOD /path'`.
  final misses = <String>[];

  /// Accounts by email. A sign-up adds one, a sign-in checks it.
  final accounts = <String, Account>{};

  /// Stream routes that answer with a refusal instead of the lines: status, code, message.
  final refused = <String, (int, String, String)>{};

  String? _current; // the email of the account that is signed in on the fake sign-in service

  // ---------------------------------------------------------------- reading the recordings

  static final _raw = <String, String>{};
  static String _text(String name) => _raw.putIfAbsent(name, () => File('$dir/$name').readAsStringSync());

  static final _date = RegExp(r'(?<!\d)(20\d\d)-(\d\d)-(\d\d)(?!\d)');

  /// How many days later than the recording today is (worked out once, so a test that runs past midnight stays whole).
  static final int _shift = () {
    final on = (jsonDecode(_text('meta.json')) as Map)['recorded_on'] as String;
    final p = on.split('-').map(int.parse).toList();
    final n = DateTime.now();
    return DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(p[0], p[1], p[2])).inDays;
  }();

  /// The text of a recording with every date moved forward by [_shift] days.
  static String _moved(String name) {
    final days = _shift;
    if (days == 0) return _text(name);
    return _text(name).replaceAllMapped(_date, (m) {
      final d = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!) + days);
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });
  }

  /// A new copy of a recorded JSON file, safe to change.
  static Object? json(String name) => jsonDecode(_moved(name));
  static Json obj(String name) => Json.from(json(name) as Map);

  /// The lines of a recorded NDJSON file.
  static List<Json> lines(String name) => [
        for (final l in const LineSplitter().convert(_moved(name)))
          if (l.trim().isNotEmpty) Json.from(jsonDecode(l) as Map),
      ];

  // ---------------------------------------------------------------- who is calling

  /// `patient`, `doctor` or `nurse` for the token on [s]; null when there is none or it is not one we handed out.
  String? roleOf(Seen s) {
    final h = s.headers['Authorization'] ?? '';
    if (!h.startsWith('Bearer ')) return null;
    final t = h.substring(7);
    if (t.startsWith('pd1.recorded.')) return t.substring('pd1.recorded.'.length);
    if (t == jwt) return accounts[_current]?.role;
    return null;
  }

  bool _isDemo(Seen s) => (s.headers['Authorization'] ?? '').startsWith('Bearer pd1.');

  /// The caller's name, for the notes and tasks they make.
  String _nameOf(Seen s) => _isDemo(s) ? (obj('${roleOf(s)}/me.json')['name'] as String) : (accounts[_current]?.name ?? '');

  Handler _as(Set<String> roles, String sorry, FutureOr<http.Response> Function(Seen s) f) => (s) {
        final r = roleOf(s);
        if (r == null) return errorReply(401, 'unauthorized', 'Please sign in.');
        if (!roles.contains(r)) return errorReply(403, 'forbidden', sorry);
        return f(s);
      };

  Handler _patient(FutureOr<http.Response> Function(Seen s) f) => _as({'patient'}, 'Only patients can do this.', f);
  Handler _staff(FutureOr<http.Response> Function(Seen s) f) => _as({'doctor', 'nurse'}, 'Only doctors and nurses can do this.', f);
  Handler _anyone(FutureOr<http.Response> Function(Seen s) f) => _as({'patient', 'doctor', 'nurse'}, '', f);

  // ---------------------------------------------------------------- the app, the sign-in service

  /// A Supabase client on this fake, for sign-in and sign-up. Token refresh is off, because its timer would still be
  /// running when a widget test ends. It is not disposed: with nothing running there is nothing to stop, and in a
  /// widget test `dispose()` never finishes (its futures belong to the test's fake clock, which has stopped).
  late final SupabaseClient supabase = SupabaseClient('https://proj.supabase.co', 'sb_publishable_test',
      httpClient: client(), authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit, autoRefreshToken: false));

  /// A [Session] for the app that talks to this service. Accounts (sign-in, sign-up) need [withAccounts].
  Session session({bool withAccounts = false}) => Session(httpClient: client, apiBase: apiBase, supabase: withAccounts ? supabase : null);

  /// Adds an account that exists on the service, as if it had signed up earlier.
  void addAccount(String role, String name, String email, String password, {Map<String, String> details = const {}}) =>
      accounts[email.toLowerCase()] = Account(role: role, name: name, email: email.toLowerCase(), password: password, details: details);

  // ---------------------------------------------------------------- live streams

  final _open = <String, List<StreamController<List<int>>>>{};
  static const _streams = {'GET /wearer/live', 'GET /ward/live', 'GET /v1/live'};

  /// The connections open on [route] now.
  List<StreamController<List<int>>> opened(String route) => [...?_open[route]].where((c) => !c.isClosed).toList();

  /// Writes one line on every connection open on [route], as the service does for each tick.
  void send(String route, Map<String, dynamic> line) {
    for (final c in opened(route)) {
      c.add(utf8.encode('${jsonEncode(line)}\n'));
    }
  }

  @override
  http.Client client() => _Client(this);

  Future<http.StreamedResponse> _answer(_Client from, http.BaseRequest req) async {
    final s = Seen(req.method, req.url, req.headers, await req.finalize().bytesToString());
    seen.add(s);
    if (_streams.contains(s.route)) {
      final no = refused[s.route];
      if (no != null) return _plain(errorReply(no.$1, no.$2, no.$3));
      final bad = _streamGuard(s);
      if (bad != null) return _plain(bad);
      late final StreamController<List<int>> c;
      c = StreamController<List<int>>(onCancel: () => _forget(c));
      from.mine.add(c);
      (_open[s.route] ??= []).add(c);
      for (final l in _lines(s)) {
        c.add(utf8.encode('${jsonEncode(l)}\n'));
      }
      return http.StreamedResponse(c.stream, 200, headers: {'content-type': 'application/x-ndjson'});
    }
    final h = routes[s.route] ?? _byPattern(s);
    if (h == null) {
      misses.add(s.route);
      return _plain(errorReply(404, 'not_found', 'No such route: ${s.route}'));
    }
    try {
      return _plain(await h(s));
    } catch (e) {
      misses.add('${s.route} failed: $e'); // a recording this fake does not understand: the test fails when it ends
      return _plain(errorReply(500, 'server_error', 'The fake service failed: $e'));
    }
  }

  static http.StreamedResponse _plain(http.Response r) => http.StreamedResponse(Stream.value(r.bodyBytes), r.statusCode, headers: r.headers);

  void _forget(StreamController<List<int>> c) {
    for (final l in _open.values) {
      l.remove(c);
    }
  }

  http.Response? _streamGuard(Seen s) {
    final r = roleOf(s);
    if (r == null) return errorReply(401, 'unauthorized', 'Please sign in.');
    final staff = r != 'patient';
    return switch (s.route) {
      'GET /ward/live' => staff && _isDemo(s) ? null : errorReply(403, 'forbidden', 'The demo ward is only for Demo Mode.'),
      'GET /v1/live' => staff && !_isDemo(s) ? null : errorReply(403, 'forbidden', 'Your account is not set up for a ward. Ask your admin.'),
      _ => null,
    };
  }

  // ---------------------------------------------------------------- the band

  int _version = 0;
  String _scenario = 'rest';
  bool _paused = false, _fast = false;

  /// True once the oxygen scenario has been played (or when a test sets it): a new connection then starts from the
  /// snapshot recorded with the level-4 alert in it.
  bool oxygenDrop = false;

  /// Takes the service's current scenario, pause and speed into a recorded line.
  Json _live(Json line) => line
    ..['version'] = _version
    ..['scenario'] = {'id': _scenario, 'minutes_left': scenarioById(_scenario).minutes}
    ..['paused'] = _paused
    ..['fast'] = _fast;

  /// The lines a new connection receives: the snapshot and the updates that were recorded after it. A doctor or nurse
  /// watches the home patient and gets the snapshot only. After the oxygen drop the snapshot is the one recorded with
  /// the level-4 alert in it.
  List<Json> _lines(Seen s) {
    final role = roleOf(s)!;
    return switch (s.route) {
      'GET /wearer/live' when role == 'patient' => oxygenDrop ? [_autoSos(_live(obj('patient/wearer_live_hypoxia.json')))] : lines('patient/wearer_live.ndjson').map(_live).toList(),
      'GET /wearer/live' => [_live(lines('$role/wearer_live.ndjson').first)],
      _ => lines('$role/ward_live.ndjson'),
    };
  }

  /// The service marks a level-4 alert for Auto SOS only when the patient's setting is on. The recording was made with
  /// it on, so this follows the setting the app has saved since.
  Json _autoSos(Json line) {
    final on = (doc['prefs'] as Map)['autoSos'] == true;
    final alerts = line['alerts'] ?? (line['state'] as Map)['alerts'];
    for (final a in (alerts as List).cast<Json>()) {
      a['auto_sos'] = on && a['level'] == 4;
    }
    return line;
  }

  /// The update line the real service sent when the oxygen scenario hit the safety floor: a level-4 alert and its event.
  /// Send it with [send] to make an alert arrive on the live stream.
  Json alertUpdate() => _autoSos(_live(obj('patient/wearer_update_hypoxia.json')));

  /// What the service sends to everyone after a command: no new reading, just the controls.
  Json _control() => _live({'type': 'update', 'rec': null, 'alerts': <Json>[], 'held_new': <Json>[], 'events': <Json>[]});

  // ---------------------------------------------------------------- the patient's records

  late final Json doc = obj('patient/me_data.json');
  int _sos = 0;

  http.Response _write(void Function(Json d) change) {
    change(doc);
    return jsonReply(doc);
  }

  List<dynamic> _list(String name) => doc[name] as List<dynamic>;

  // ---------------------------------------------------------------- the care team

  final _care = <String, Json>{};
  final _asked = <String, List<String>>{};
  final _labels = <String, Map<String, bool>>{};
  int _seq = 0;

  Json _careOf(String role) => _care.putIfAbsent(role, () => obj('$role/care_state.json'));

  /// The whole care state, with the beds the caller last asked about (`?beds=`) in `beds`, as the service does.
  http.Response _careState(Seen s) {
    final role = roleOf(s)!;
    final b = s.url.queryParameters['beds'];
    if (b != null) _asked[role] = [for (final x in b.split(',')) if (x.trim().isNotEmpty) x.trim()];
    final c = _careOf(role);
    if (_asked[role] != null) c['beds'] = _asked[role];
    return jsonReply(c);
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  Json _noteFor(Seen s, String patientId, String kind, String text) =>
      {'id': 'n${++_seq}', 'patientId': patientId, 'at': _now(), 'kind': kind, 'text': text, 'by': _nameOf(s)};

  http.Response _care_(Seen s, void Function(Json c) change) {
    change(_careOf(roleOf(s)!));
    return _careState(s);
  }

  /// The calendar day of [utc] on the caller's clock (X-Tz-Offset, minutes east of UTC; India without it).
  static String _day(DateTime utc, Seen s) {
    final d = utc.toUtc().add(Duration(minutes: int.tryParse(s.headers['X-Tz-Offset'] ?? '') ?? 330));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------- the routes

  late final _assistant = {'en': obj('patient/assistant_en.json'), 'hi': obj('patient/assistant_hi.json')};

  /// A Hindi question the app sent, back to the English text it was recorded under.
  late final _english = {for (final q in _assistant['en']!.keys) hiStrings[q] ?? q: q};

  final _patterns = <(String, RegExp, Handler)>[];

  Handler? _byPattern(Seen s) {
    for (final (method, path, h) in _patterns) {
      if (method == s.method && path.hasMatch(s.path)) return h;
    }
    return null;
  }

  void _pattern(String route, Handler h) {
    final parts = route.split(' ');
    _patterns.add((parts[0], RegExp('^${parts[1]}\$'), h));
  }

  static String _last(String path, [int from = 0]) => Uri.decodeComponent(path.split('/').where((p) => p.isNotEmpty).toList()[from]);

  void _install() {
    // -- no token needed
    routes['POST /demo/start'] = (s) {
      final role = s.map['role'];
      if (role is! String || !const ['patient', 'doctor', 'nurse'].contains(role)) return errorReply(422, 'invalid', 'Choose patient, doctor or nurse.');
      return jsonReply(json('$role/demo_start.json'));
    };
    routes['POST /demo/end'] = (_) => jsonReply(json('demo_end.json'));
    routes['POST /study'] = (s) => jsonReply(json(s.map['noise'] == null && s.map['markdown'] != true ? 'study_seed7.json' : 'study_lab.json'));
    routes['POST /signup'] = (s) {
      final b = s.map;
      final email = '${b['email']}'.trim().toLowerCase();
      if (accounts.containsKey(email)) return errorReply(409, 'email_taken', 'An account with this email already exists. Log in instead.');
      var name = '${b['name']}'.trim();
      if (b['role'] == 'doctor' && !name.toLowerCase().startsWith('dr')) name = 'Dr. $name';
      addAccount('${b['role']}', name, email, '${b['password']}', details: {for (final e in ((b['details'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'});
      return jsonReply({'ok': true});
    };

    // -- the sign-in service (Supabase Auth)
    routes['POST /auth/v1/token'] = (s) {
      final a = accounts['${s.map['email']}'.trim().toLowerCase()];
      if (a == null || a.password != s.map['password']) {
        return jsonReply({'code': 400, 'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'}, 400);
      }
      _current = a.email;
      return jsonReply({
        'access_token': jwt,
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh',
        'user': {'id': 'u-${a.email}', 'aud': 'authenticated', 'email': a.email, 'created_at': '2026-10-01T00:00:00Z', 'app_metadata': <String, dynamic>{}, 'user_metadata': <String, dynamic>{}},
      });
    };
    routes['POST /auth/v1/logout'] = (_) {
      _current = null;
      return http.Response('', 204);
    };
    routes['POST /auth/v1/recover'] = (_) => jsonReply({});

    // -- who am I
    routes['GET /me'] = _anyone((s) {
      if (_isDemo(s)) return jsonReply(json('${roleOf(s)}/me.json'));
      final a = accounts[_current]!;
      return jsonReply({'role': a.role, 'name': a.name, 'email': a.email, 'details': a.details, 'ward_id': null, 'demo': false});
    });
    routes['GET /doctors'] = _anyone((s) => jsonReply(json('patient/doctors.json')));
    _pattern('GET /doctors/[^/]+/slots', _anyone((s) {
      final id = _last(s.path, 1);
      final doctors = (json('patient/doctors.json') as Map)['doctors'] as List;
      if (!doctors.any((d) => (d as Map)['id'] == id)) return errorReply(404, 'not_found', 'That doctor was not found.');
      // The service names the days on the caller's clock, so the recorded times are grouped again for this caller.
      final days = <String, List<dynamic>>{};
      for (final day in ((json('patient/slots_d1.json') as Map)['days'] as Map).values) {
        for (final at in day as List) {
          days.putIfAbsent(_day(DateTime.parse('$at'), s), () => []).add(at);
        }
      }
      return jsonReply({'days': days});
    }));

    // -- the band
    routes['POST /wearer/scenario'] = _anyone((s) {
      final id = s.map['id'];
      if (id is! String || !scenarios.any((x) => x.id == id)) return errorReply(422, 'invalid', 'Unknown scenario.');
      _scenario = id;
      _version++;
      if (id == 'hypoxia') {
        oxygenDrop = true;
        send('GET /wearer/live', alertUpdate());
      } else {
        send('GET /wearer/live', _control());
      }
      return jsonReply({'version': _version, 'scenario': {'id': _scenario, 'minutes_left': scenarioById(_scenario).minutes}});
    });
    routes['POST /wearer/paused'] = _anyone((s) {
      _paused = s.map['paused'] == true;
      _version++;
      send('GET /wearer/live', _control());
      return jsonReply({'version': _version, 'paused': _paused});
    });
    routes['POST /wearer/fast'] = _anyone((s) {
      _fast = s.map['fast'] == true;
      _version++;
      send('GET /wearer/live', _control());
      return jsonReply({'version': _version, 'fast': _fast});
    });
    // Feedback and labels change one alert of the newest snapshot the service would send now.
    Json? alertOf(Seen s) {
      final id = int.parse(_last(s.path, 2));
      final snapshot = oxygenDrop ? obj('patient/wearer_live_hypoxia.json') : lines('patient/wearer_live.ndjson').first;
      return ((snapshot['state'] as Map)['alerts'] as List).cast<Json>().where((a) => a['id'] == id).firstOrNull;
    }

    final noAlert = errorReply(404, 'not_found', 'That alert was not found.');
    _pattern('POST /wearer/alerts/\\d+/feedback', _anyone((s) {
      final a = alertOf(s);
      if (a == null) return noAlert;
      a['feedback'] ??= s.map['kind'];
      return jsonReply({'alert': a});
    }));
    _pattern('POST /wearer/alerts/\\d+/label', _anyone((s) {
      final a = alertOf(s);
      if (a == null) return noAlert;
      if (a['doctor'] == 'pending') {
        a['doctor'] = s.map['real'] == true ? 'confirmed' : 'rejected';
        a['reviewed_by'] = s.map['by'];
      }
      return jsonReply({'alert': a});
    }));

    // -- the patient's records
    routes['GET /me/data'] = _patient((s) => jsonReply(doc));
    routes['PUT /me/profile'] = _patient((s) => _write((d) => d['profile'] = s.map));
    routes['PUT /me/prefs'] = _patient((s) => _write((d) => d['prefs'] = s.map));
    _pattern('PUT /me/(family|appointments|records|policies|claims)/[^/]+', _patient((s) => _write((d) {
          final list = _list(_last(s.path, 1));
          final i = list.indexWhere((x) => (x as Map)['id'] == s.map['id']);
          i < 0 ? list.add(s.map) : list[i] = s.map;
        })));
    _pattern('DELETE /me/(family|appointments|records|policies|claims)/[^/]+', _patient((s) => _write((d) => _list(_last(s.path, 1)).removeWhere((x) => (x as Map)['id'] == _last(s.path, 2)))));
    _pattern('POST /me/appointments/[^/]+/cancel', _patient((s) => _write((d) {
          for (final x in _list('appointments').cast<Json>()) {
            if (x['id'] == _last(s.path, 2)) x['status'] = 'cancelled';
          }
        })));
    _pattern('POST /me/claims/[^/]+/advance', _patient((s) => _write((d) {
          const next = {'submitted': 'underReview', 'underReview': 'approved', 'approved': 'paid'};
          for (final c in _list('claims').cast<Json>()) {
            if (c['id'] != _last(s.path, 2)) continue;
            final steps = (c['timeline'] as List).cast<Json>();
            final to = next[steps.last['status']];
            if (to != null) steps.add({'status': to, 'at': _now(), 'note': to == 'underReview' ? 'Documents received' : ''});
          }
        })));

    // -- assistant, SOS
    routes['POST /assistant'] = _patient((s) {
      final lang = s.headers['X-Lang'] == 'hi' ? 'hi' : 'en';
      final q = '${s.map['q']}'.trim();
      final reply = _assistant[lang]![lang == 'hi' ? (_english[q] ?? q) : q];
      if (reply == null) {
        misses.add('POST /assistant ($lang): $q');
        return errorReply(404, 'not_recorded', 'No recorded reply for: $q');
      }
      return jsonReply(reply);
    });
    routes['POST /sos'] = _patient((s) => jsonReply({...obj('patient/sos.json'), 'id': ++_sos}));
    _pattern('POST /sos/\\d+/end', _patient((s) => jsonReply(json('patient/sos_end.json'))));

    // -- the care team
    routes['GET /care/state'] = _staff(_careState);
    routes['POST /care/notes'] = _staff((s) => _care_(s, (c) => (c['notes'] as List).insert(0, _noteFor(s, '${s.map['patient_id']}', '${s.map['kind']}', '${s.map['text']}'))));
    routes['POST /care/prescribe'] = _staff((s) {
      final m = Map<String, dynamic>.from(s.map['medication'] as Map);
      final text = '${m['name']} ${m['dose']}, ${m['schedule']}${'${s.map['days']}'.isEmpty ? '' : ' for ${s.map['days']} days'}';
      return _care_(s, (c) => (c['notes'] as List).insert(0, _noteFor(s, '${s.map['patient_id']}', 'prescription', text)));
    });
    routes['POST /care/visits'] = _staff((s) => _care_(s, (c) {
          final at = DateTime.parse('${s.map['at']}').toUtc();
          final who = (c['patients'] as List).cast<Json>().firstWhere((p) => p['id'] == s.map['patient_id']);
          final visit = {'id': 'v${++_seq}', 'patientId': who['id'], 'patientName': who['name'], 'at': at.toIso8601String(), 'reason': s.map['reason'], 'video': s.map['video'] == true, 'status': 'upcoming', 'bookedByPatient': false};
          ((c['visits'] as Map).putIfAbsent(_day(at, s), () => <dynamic>[]) as List).add(visit);
          ((c['slots'] as Map)[_day(at, s)] as List?)?.removeWhere((x) => DateTime.parse('$x').isAtSameMomentAs(at));
        }));
    _pattern('POST /care/visits/[^/]+/status', _staff((s) => _care_(s, (c) {
          for (final day in (c['visits'] as Map).values) {
            for (final v in (day as List).cast<Json>()) {
              if (v['id'] != _last(s.path, 2)) continue;
              v['status'] = s.map['status'];
              final note = '${s.map['note'] ?? ''}'.trim();
              if (note.isNotEmpty) (c['notes'] as List).insert(0, _noteFor(s, '${v['patientId']}', 'consult', note));
            }
          }
        })));
    _pattern('POST /care/tasks/[^/]+/toggle', _staff((s) => _care_(s, (c) {
          final done = c['done'] as Map;
          final id = _last(s.path, 2);
          done.containsKey(id) ? done.remove(id) : done[id] = '${_nameOf(s)} · ${DateFormat('h:mm a').format(DateTime.now())}';
        })));
    routes['POST /care/handovers'] = _staff((s) => _care_(s, (c) => (c['handovers'] as List).insert(0, {'at': _now(), 'by': _nameOf(s), 'text': s.map['text']})));

    // -- the demo ward, and alert labels
    http.Response ok(Seen s) => jsonReply({'ok': true});
    Handler demoWard(FutureOr<http.Response> Function(Seen s) f) => _as({'doctor', 'nurse'}, 'The demo ward is only for Demo Mode.', (s) => _isDemo(s) ? f(s) : errorReply(403, 'forbidden', 'The demo ward is only for Demo Mode.'));
    _pattern('POST /ward/alerts/[^/]+/ack', demoWard(ok));
    _pattern('POST /ward/alerts/[^/]+/resolve', demoWard(ok));
    routes['POST /ward/scenario'] = demoWard(ok);
    routes['POST /ward/chat'] = demoWard((s) => jsonReply(json('${roleOf(s)}/ward_chat.json')));
    Map<String, bool> labels(Seen s) => _labels.putIfAbsent(roleOf(s)!, () => Map<String, bool>.from((obj('${roleOf(s)}/labels.json')['labels'] as Map)));
    routes['GET /labels'] = _staff((s) => jsonReply({'labels': labels(s)}));
    routes['POST /labels'] = _staff((s) {
      labels(s)['${s.map['alert_id']}'] = s.map['real'] == true;
      return jsonReply({'labels': labels(s)});
    });
  }
}

/// A client of the fake. Closing it ends the streams it opened, as closing a real client does.
class _Client extends http.BaseClient {
  _Client(this.svc);
  final RecordedService svc;
  final mine = <StreamController<List<int>>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => svc._answer(this, request);

  @override
  void close() {
    for (final c in mine) {
      if (!c.isClosed) c.close();
    }
    mine.clear();
  }
}
