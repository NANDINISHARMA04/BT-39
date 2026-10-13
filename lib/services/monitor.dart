import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../engine/adapt_alert.dart';
import '../engine/simulator.dart';
import '../l10n/l10n.dart';
import 'pulse_api.dart';

/// Shows the wearer's band and AdaptAlert engine, which run on the PulseOS
/// service.
///
/// `GET /wearer/live` streams a snapshot, then one update per tick. The
/// controller mirrors them in [engine] and fires the banners the screens listen
/// to. Commands (play a scenario, pause, fast forward, answer an alert) show
/// their effect at once and are then sent; the service's `version` number tells
/// stale lines apart so the screen never jumps back.
class MonitorController extends ChangeNotifier {
  MonitorController({required this.api});

  final PulseApi api;
  final AdaptAlertEngine engine = AdaptAlertEngine();

  /// UI listens to these for banners, toasts and auto-SOS. Each is set once per
  /// event on the stream, never for the snapshot.
  final ValueNotifier<HealthAlert?> alertEvents = ValueNotifier(null);
  final ValueNotifier<HeldEvent?> heldEvents = ValueNotifier(null);
  final ValueNotifier<int> badSignal = ValueNotifier(0);

  /// Becomes 'rest' when a scenario ends, as it always has (a scenario ends by
  /// returning to resting). It is a plain [ValueNotifier], so it notifies the
  /// first time a scenario ends in a session and not again: the guided demo
  /// plays many scenarios and shows "Back to resting" only once.
  final ValueNotifier<String?> scenarioEnded = ValueNotifier(null);

  /// True once the first snapshot has arrived.
  bool ready = false;

  /// connecting | live | offline
  String status = 'connecting';

  /// The sentence for the last command that failed, until one succeeds.
  String? error;

  String _scenarioId = 'rest';
  int _minutesLeft = 0;
  bool _paused = false, _fast = false;

  /// Commands that changed scenario, pause or speed and have not been answered.
  int _inflight = 0;

  /// The newest version a command has returned. Lines older than this carry
  /// control fields from before the command, so those fields are ignored.
  int _floor = 0;
  bool _stopped = true, _disposed = false, _looping = false;
  http.Client? _http;
  Completer<void>? _over;

  WindowRecord? get last => engine.last;
  String get scenarioId => _scenarioId;
  int get scenarioMinutesLeft => _minutesLeft;
  bool get paused => _paused;
  bool get fast => _fast;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ------------------------------------------------------------------ stream

  /// Opens the stream and keeps it open, reconnecting with a back-off.
  void start() {
    if (_disposed) return;
    _stopped = false;
    if (_looping) return;
    _looping = true;
    _run().whenComplete(() => _looping = false);
  }

  void stop() {
    _stopped = true;
    _end();
    _http?.close();
  }

  /// Ends the connection that is open now; [_run] then moves on.
  void _end() {
    final over = _over;
    if (over != null && !over.isCompleted) over.complete();
  }

  Future<void> _run() async {
    var delay = 1;
    while (!_stopped) {
      final c = api.newClient();
      _http = c;
      final over = _over = Completer<void>();
      var connected = false;
      final sub = api.lines('/wearer/live', c).listen(
        (line) {
          if (_stopped) return;
          try {
            switch (line['type']) {
              case 'snapshot':
                connected = true;
                delay = 1;
                _snapshot(line);
              case 'update':
                if (connected) _update(line);
            }
          } catch (_) {
            _end(); // a line we cannot read: start again from a snapshot
          }
        },
        // A dropped or refused stream: wait, then start again from a snapshot.
        onError: (_) => _end(),
        onDone: _end,
        cancelOnError: true,
      );
      await over.future;
      unawaited(sub.cancel());
      c.close();
      if (_stopped) break;
      status = ready ? 'offline' : 'connecting';
      _notify();
      await Future<void>.delayed(Duration(seconds: delay));
      delay = min(delay * 2, 15);
    }
  }

  void _snapshot(Map<String, dynamic> line) {
    engine.applySnapshot(line['state'] as Map? ?? const {});
    _control(line, snapshot: true);
    ready = true;
    status = 'live';
    error = null;
    _notify();
  }

  void _update(Map<String, dynamic> line) {
    final newHeld = engine.applyUpdate(line);
    _control(line);
    _notify();
    var held = 0;
    for (final e in (line['events'] as List? ?? const [])) {
      if (e is! Map) continue;
      switch (e['kind']) {
        case 'alert':
          final a = engine.alertById((e['id'] as num).round());
          if (a != null) alertEvents.value = a;
        case 'held':
          final h = held < newHeld.length ? newHeld[held++] : engine.held.firstOrNull;
          if (h != null) heldEvents.value = h;
        case 'bad_signal':
          badSignal.value++;
        case 'scenario_ended':
          scenarioEnded.value = 'rest';
      }
    }
  }

  /// Takes scenario, pause and speed from a line, unless a command is waiting
  /// for its answer or the line is older than the answer to the last command.
  /// A snapshot starts over (the service may have restarted).
  void _control(Map<String, dynamic> line, {bool snapshot = false}) {
    if (_inflight > 0) return;
    final v = (line['version'] as num?)?.round();
    if (snapshot) {
      if (v != null) _floor = v;
    } else if (v != null && v < _floor) {
      return;
    }
    _takeControl(line);
  }

  void _takeControl(Map<String, dynamic> m) {
    final sc = m['scenario'];
    if (sc is Map) {
      _scenarioId = '${sc['id'] ?? _scenarioId}';
      _minutesLeft = (sc['minutes_left'] as num?)?.round() ?? 0;
    }
    if (m['paused'] is bool) _paused = m['paused'] as bool;
    if (m['fast'] is bool) _fast = m['fast'] as bool;
  }

  // ---------------------------------------------------------------- commands

  /// Sends a command that changes scenario, pause or speed. The caller has
  /// already shown the result; [undo] puts the old state back if it fails.
  Future<void> _command(Future<ApiResult> Function() send, void Function() undo) async {
    _inflight++;
    _notify();
    ApiResult r;
    try {
      r = await send();
    } catch (_) {
      r = ApiResult.fail(0, 'unreachable', tr('The service could not be reached. It may be waking up. Try again in a minute.'));
    }
    _inflight--;
    if (r.ok) {
      error = null;
      final m = r.map;
      final v = (m['version'] as num?)?.round();
      if (v == null || v >= _floor) {
        if (v != null) _floor = v;
        // The answer to the last command in flight is the newest state.
        if (_inflight == 0) _takeControl(m);
      }
    } else {
      undo();
      error = r.message;
    }
    _notify();
  }

  Future<void> runScenario(String id) {
    final was = (_scenarioId, _minutesLeft);
    _scenarioId = id;
    _minutesLeft = scenarios.where((s) => s.id == id).firstOrNull?.minutes ?? 0;
    return _command(() => api.post('/wearer/scenario', {'id': id}), () {
      _scenarioId = was.$1;
      _minutesLeft = was.$2;
    });
  }

  Future<void> setPaused(bool v) {
    final was = _paused;
    _paused = v;
    return _command(() => api.post('/wearer/paused', {'paused': v}), () => _paused = was);
  }

  Future<void> setFast(bool v) {
    final was = _fast;
    _fast = v;
    return _command(() => api.post('/wearer/fast', {'fast': v}), () => _fast = was);
  }

  /// The wearer says what was happening. The answer shows at once.
  Future<void> feedback(HealthAlert a, PatientFeedback f) async {
    if (a.patientFeedback != null) return;
    a.patientFeedback = f;
    _notify();
    await _alertCommand(a, '/wearer/alerts/${a.id}/feedback', {'kind': f.name}, () {
      if (a.patientFeedback == f) a.patientFeedback = null;
    });
  }

  /// The doctor's label overrides the wearer's. It shows at once.
  Future<void> doctorLabel(HealthAlert a, bool real, {String? by}) async {
    if (a.doctor != DoctorLabel.pending) return;
    final was = a.reviewedBy;
    a.doctor = real ? DoctorLabel.confirmed : DoctorLabel.rejected;
    a.reviewedBy = by;
    _notify();
    await _alertCommand(a, '/wearer/alerts/${a.id}/label', {'real': real, 'by': by}, () {
      a.doctor = DoctorLabel.pending;
      a.reviewedBy = was;
    });
  }

  Future<void> _alertCommand(HealthAlert a, String path, Map<String, dynamic> body, void Function() undo) async {
    ApiResult r;
    try {
      r = await api.post(path, body);
    } catch (_) {
      r = ApiResult.fail(0, 'unreachable', tr('The service could not be reached. It may be waking up. Try again in a minute.'));
    }
    if (r.ok && r.map['alert'] is Map) {
      error = null;
      engine.applyUpdate({'alerts': [r.map['alert']]});
    } else if (!r.ok) {
      undo();
      error = r.message;
    }
    _notify();
  }

  int get needsReply => engine.alerts.where((a) => a.patientFeedback == null).length;

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
