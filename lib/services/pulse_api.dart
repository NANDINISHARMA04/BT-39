import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../l10n/l10n.dart';

/// The outcome of one call: the decoded JSON on success, or the service's
/// error code and a sentence to show.
class ApiResult {
  ApiResult.ok([this.data]) : ok = true, status = 200, error = null, message = null;
  ApiResult.fail(this.status, this.error, this.message) : ok = false, data = null;
  final bool ok;
  final int status;
  final String? error, message;
  final Object? data;

  /// The reply as a JSON object, or an empty one when it was not an object.
  Map<String, dynamic> get map => data is Map ? Map<String, dynamic>.from(data as Map) : const {};
}

/// Thrown by calls that return data instead of an [ApiResult] (the study) and
/// by [PulseApi.lines] when the service refuses the stream.
class ApiException implements Exception {
  ApiException(this.status, this.error, this.message);
  final int status;
  final String? error, message;
  @override
  String toString() => 'ApiException($status, $error): $message';
}

/// The one door to the PulseOS routes (`/v1/pulse/*` on the BT39 service).
///
/// Every request carries the bearer token (an account's Supabase token or a
/// Demo Mode token), the phone's time zone and the app language. The service
/// can be asleep on a free host, so a call waits up to 75 seconds.
class PulseApi {
  PulseApi({required this.token, String? base, http.Client Function()? client, this.onDemoExpired})
      : base = _trim(base ?? '${AppConfig.bt39Api}/v1/pulse'),
        _client = client;

  /// The bearer token, or null when nobody is signed in.
  final Future<String?> Function() token;

  /// Everything before a route, e.g. `https://host/v1/pulse`.
  final String base;
  final http.Client Function()? _client;

  /// Called when the service says the Demo Mode visit is over (401 `demo_expired`).
  final void Function()? onDemoExpired;

  static const timeout = Duration(seconds: 75);

  /// A stream that stays silent this long is treated as dead. The service sends
  /// a line every second, or a ping every 15 seconds while the band is paused.
  static const idleTimeout = Duration(seconds: 45);

  static String _trim(String s) => s.endsWith('/') ? s.substring(0, s.length - 1) : s;

  /// A fresh HTTP client, for callers that keep a stream open ([lines]).
  http.Client newClient() => (_client ?? http.Client.new)();

  Future<ApiResult> get(String path, [Object? body]) => _call('GET', path, body);
  Future<ApiResult> post(String path, [Object? body]) => _call('POST', path, body);
  Future<ApiResult> put(String path, [Object? body]) => _call('PUT', path, body);
  Future<ApiResult> delete(String path, [Object? body]) => _call('DELETE', path, body);

  /// A call that never sends the token: sign-up and starting Demo Mode.
  Future<ApiResult> postPublic(String path, Object? body) => _call('POST', path, body, auth: false);

  Future<http.Request> _request(String method, String path, Object? body, {bool auth = true}) async {
    final req = http.Request(method, Uri.parse('$base${path.startsWith('/') ? '' : '/'}$path'));
    req.headers['Accept'] = 'application/json';
    req.headers['Content-Type'] = 'application/json';
    req.headers['X-Tz-Offset'] = '${DateTime.now().timeZoneOffset.inMinutes}';
    req.headers['X-Lang'] = appLang.value;
    if (auth) {
      final t = await token();
      if (t != null && t.isNotEmpty) req.headers['Authorization'] = 'Bearer $t';
    }
    if (body != null) req.body = jsonEncode(body);
    return req;
  }

  /// The failure for a non-2xx reply: the service's own sentence when it sent
  /// one, otherwise a generic one.
  ApiResult _failure(int status, String body) {
    Object? j;
    try {
      j = jsonDecode(body);
    } catch (_) {}
    final m = j is Map ? j : const {};
    final code = m['error'];
    final text = m['message'];
    final r = ApiResult.fail(
      status,
      code is String ? code : 'unavailable',
      // The service writes its sentences in English; the ones a person can see have a Hindi line in the app's table.
      text is String && text.isNotEmpty ? trData(text) : tr('The service is not answering. It may be waking up. Try again in a minute.'),
    );
    if (status == 401 && r.error == 'demo_expired') onDemoExpired?.call();
    return r;
  }

  Future<ApiResult> _call(String method, String path, Object? body, {bool auth = true}) async {
    final c = newClient();
    try {
      final req = await _request(method, path, body, auth: auth);
      final res = await (() async => http.Response.fromStream(await c.send(req)))().timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        Object? j;
        try {
          j = jsonDecode(utf8.decode(res.bodyBytes));
        } catch (_) {}
        return ApiResult.ok(j);
      }
      return _failure(res.statusCode, utf8.decode(res.bodyBytes, allowMalformed: true));
    } catch (_) {
      return ApiResult.fail(0, 'unreachable', tr('The service could not be reached. It may be waking up. Try again in a minute.'));
    } finally {
      c.close();
    }
  }

  /// One connection to a newline-delimited JSON stream (`/wearer/live`,
  /// `/ward/live`). Lines that are not JSON objects are skipped. Throws an
  /// [ApiException] when the service does not answer 200, and a
  /// [TimeoutException] when nothing arrives for [idle]. The caller closes [c]
  /// to stop and reconnects with a back-off.
  Stream<Map<String, dynamic>> lines(String path, http.Client c, {Duration idle = idleTimeout}) async* {
    final req = await _request('GET', path, null);
    final res = await c.send(req).timeout(timeout);
    if (res.statusCode != 200) {
      final r = _failure(res.statusCode, await res.stream.bytesToString());
      throw ApiException(r.status, r.error, r.message);
    }
    final out = res.stream.transform(utf8.decoder).transform(const LineSplitter()).where((l) => l.trim().isNotEmpty).map<Map<String, dynamic>?>((l) {
      try {
        final j = jsonDecode(l);
        return j is Map ? Map<String, dynamic>.from(j) : null;
      } catch (_) {
        return null;
      }
    }).where((m) => m != null).cast<Map<String, dynamic>>().timeout(idle, onTimeout: (sink) {
      sink.addError(TimeoutException('The stream went quiet', idle));
      sink.close();
    });
    yield* out;
  }
}
