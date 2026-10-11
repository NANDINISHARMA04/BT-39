import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// One bed in a live frame of `GET /v1/live`. Patient fields are null for an empty bed.
class LiveBed {
  LiveBed({required this.bed, this.patientId, this.name, this.age, this.sex, this.hr, this.spo2, this.rr, this.sbp, this.dbp, this.temp, this.news2, this.band, this.onOxygen, this.consciousness, this.staleS, this.nibpAgeS, this.openAlerts = const []});
  final String bed;
  final String? patientId, name, sex, band, consciousness;
  final int? age, hr, spo2, rr, sbp, dbp, news2, staleS, nibpAgeS;
  final double? temp;
  final bool? onOxygen;
  final List<LiveAlert> openAlerts;

  bool get empty => patientId == null;
  bool get stale => (staleS ?? 0) > 5 || (hr == null && spo2 == null && !empty);

  factory LiveBed.fromJson(Map<String, dynamic> j) => LiveBed(
        bed: j['bed'], patientId: j['patient_id'], name: j['name'], age: j['age'], sex: j['sex'],
        hr: (j['hr'] as num?)?.round(), spo2: (j['spo2'] as num?)?.round(), rr: (j['rr'] as num?)?.round(),
        sbp: (j['sbp'] as num?)?.round(), dbp: (j['dbp'] as num?)?.round(), temp: (j['temp'] as num?)?.toDouble(),
        news2: j['news2'], band: j['band'], onOxygen: j['on_oxygen'], consciousness: j['consciousness'],
        staleS: (j['stale_s'] as num?)?.round(), nibpAgeS: (j['nibp_age_s'] as num?)?.round(),
        openAlerts: ((j['open_alerts'] as List?) ?? []).map((a) => LiveAlert.fromJson(Map<String, dynamic>.from(a))).toList(),
      );
}

class LiveAlert {
  LiveAlert(this.id, this.kind, this.severity, this.acknowledged);
  final String id, kind, severity;
  final bool acknowledged;
  factory LiveAlert.fromJson(Map<String, dynamic> j) => LiveAlert(j['id'], j['kind'], j['severity'], j['acknowledged'] ?? false);
}

class ApiResult {
  ApiResult.ok([this.data]) : ok = true, status = 200, error = null, message = null;
  ApiResult.fail(this.status, this.error, this.message) : ok = false, data = null;
  final bool ok;
  final int status;
  final String? error, message;
  final Object? data;
}

sealed class ChatEvent {}

class ChatDelta extends ChatEvent {
  ChatDelta(this.text);
  final String text;
}

class ChatError extends ChatEvent {
  ChatError(this.message);
  final String message;
}

class ChatDone extends ChatEvent {
  ChatDone(this.sources);
  final List<String> sources;
}

/// Talks to the BT39 monitor service. Tokens go in the Authorization header,
/// never in a URL (BT39 README, section 5).
class Bt39Client {
  Bt39Client(this.token, {String? base}) : base = base ?? AppConfig.bt39Api;
  final Future<String?> Function() token;
  final String base;

  Future<bool> health() async {
    try {
      final r = await http.get(Uri.parse('$base/health')).timeout(const Duration(seconds: 70));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<ApiResult> call(String method, String path, [Object? body]) async {
    final t = await token();
    if (t == null) return ApiResult.fail(401, 'unauthorized', 'Please sign in.');
    try {
      final req = http.Request(method, Uri.parse('$base$path'))..headers['Authorization'] = 'Bearer $t';
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      final res = await http.Response.fromStream(await req.send());
      Object? j;
      try {
        j = jsonDecode(res.body);
      } catch (_) {}
      if (res.statusCode >= 200 && res.statusCode < 300) return ApiResult.ok(j);
      final m = j is Map ? j : const {};
      return ApiResult.fail(res.statusCode, m['error'] as String? ?? 'unavailable', m['message'] as String? ?? 'The service is not answering. It may be waking up. Try again in a minute.');
    } catch (_) {
      return ApiResult.fail(0, 'unreachable', 'The service could not be reached. It may be waking up. Try again in a minute.');
    }
  }

  Future<ApiResult> ack(String alertId) => call('POST', '/v1/alerts/$alertId/ack');
  Future<ApiResult> resolve(String alertId, String note) => call('POST', '/v1/alerts/$alertId/resolve', {'note': note});
  Future<ApiResult> scenario(String bed, String scenario) => call('POST', '/v1/sim/scenario', {'bed': bed, 'scenario': scenario, 'speed': 1});

  /// Reads NDJSON lines from a streamed response.
  static Stream<Map<String, dynamic>> _ndjson(http.StreamedResponse res) => res.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .where((l) => l.trim().isNotEmpty)
      .map((l) => Map<String, dynamic>.from(jsonDecode(l) as Map));

  /// One connection to the live stream. The caller reconnects with backoff.
  Stream<List<LiveBed>> liveOnce(http.Client client) async* {
    final t = await token();
    if (t == null) throw StateError('no session');
    final req = http.Request('GET', Uri.parse('$base/v1/live'))..headers['Authorization'] = 'Bearer $t';
    final res = await client.send(req);
    if (res.statusCode != 200) throw StateError('live ${res.statusCode}');
    await for (final frame in _ndjson(res)) {
      yield ((frame['beds'] as List?) ?? []).map((b) => LiveBed.fromJson(Map<String, dynamic>.from(b))).toList();
    }
  }

  /// Doctor-only RAG chat about one ward patient.
  Stream<ChatEvent> chat(String patientId, String question) async* {
    final t = await token();
    if (t == null) {
      yield ChatError('Please sign in.');
      return;
    }
    final client = http.Client();
    try {
      final req = http.Request('POST', Uri.parse('$base/v1/chat'))
        ..headers['Authorization'] = 'Bearer $t'
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'patient_id': patientId, 'question': question});
      final res = await client.send(req);
      if (res.statusCode != 200) {
        final body = await res.stream.bytesToString();
        String? m;
        try {
          m = (jsonDecode(body) as Map)['message'] as String?;
        } catch (_) {}
        yield ChatError(m ?? 'The question failed (${res.statusCode}).');
        return;
      }
      await for (final ev in _ndjson(res)) {
        if (ev.containsKey('delta')) {
          yield ChatDelta(ev['delta'] as String);
        } else if (ev.containsKey('error')) {
          yield ChatError(ev['error'] as String);
        } else if (ev['done'] == true) {
          yield ChatDone(((ev['sources'] as List?) ?? []).map((s) => (s as Map)['title'].toString()).toList());
        }
      }
    } catch (_) {
      yield ChatError('The service could not be reached. Try again in a minute.');
    } finally {
      client.close();
    }
  }
}
