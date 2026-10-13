import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../l10n/l10n.dart';
import '../l10n/msg.dart';
import 'bt39_client.dart';
import 'pulse_api.dart';

class StaffAlert {
  StaffAlert({required this.id, required this.patientId, required this.bed, required this.patientName, required this.kind, required this.severity, required Object? message, required this.startedAt, this.news2, this.ackBy, this.ackAt, this.resolvedAt, this.resolution}) : _message = message;
  final String id, patientId, bed, patientName, kind;
  String severity;
  final Object? _message;
  int? news2;
  final DateTime startedAt;
  String? ackBy, resolution;
  DateTime? ackAt, resolvedAt;
  bool get open => resolvedAt == null;

  /// The alert's text. Alerts from the live ward are plain strings; the demo
  /// ward's come as messages, so they follow the app's language when read.
  String get message => msg(_message);

  static const kindLabel = {
    'news2': 'NEWS2', 'trend_hr': 'Heart rate rising', 'trend_spo2': 'Oxygen falling', 'trend_rr': 'Breathing faster', 'trend_sbp': 'Blood pressure falling',
    'trend_temp': 'Temperature rising', 'shock_index': 'Shock index high', 'acute_spo2': 'Very low oxygen', 'acute_hr': 'Heart rate extreme',
    'acute_sbp': 'Very low blood pressure', 'acute_rr': 'Breathing rate extreme', 'sensor_off': 'Probe off', 'sensor_frozen': 'Sensor frozen', 'bp_overdue': 'BP overdue',
  };
  String get kindName => kindLabel[kind] ?? kind;

  /// An alert from the demo ward stream (`GET /ward/live`).
  factory StaffAlert.fromJson(Map<String, dynamic> j) {
    DateTime? when(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
    return StaffAlert(
      id: '${j['id']}',
      patientId: '${j['patient_id'] ?? ''}',
      bed: '${j['bed'] ?? ''}',
      patientName: '${j['patient_name'] ?? ''}',
      kind: '${j['kind'] ?? ''}',
      severity: '${j['severity'] ?? 'low'}',
      message: j['message'],
      startedAt: when(j['started_at']) ?? DateTime.now(),
      news2: (j['news2'] as num?)?.round(),
      ackBy: j['ack_by'] as String?,
      ackAt: when(j['ack_at']),
      resolvedAt: when(j['resolved_at']),
      resolution: j['resolution'] as String?,
    );
  }
}

/// One line of a ward stream: every bed, and in Demo Mode the alerts too.
class _Frame {
  _Frame(this.beds, [this.alerts]);
  final List<LiveBed> beds;
  final List<StaffAlert>? alerts;
}

/// Feeds the doctor and nurse screens: live beds, ward alerts, actions.
///
/// Demo Mode streams the visitor's own 11-bed ward from the PulseOS service
/// (`GET /ward/live`). Signed-in staff get the real BT39 live stream and alerts
/// from Supabase. Either way the service scores NEWS2 and raises the alerts;
/// the app shows them.
class StaffController extends ChangeNotifier {
  StaffController({required this.demo, required this.token, this.wardId, required this.myName, required this.api});
  final bool demo;
  final Future<String?> Function() token;
  final String? wardId;
  final String myName;
  final PulseApi api;

  List<LiveBed> beds = [];
  List<StaffAlert> alerts = [];
  final Map<String, List<int?>> hrHistory = {};
  final Map<String, bool> labels = {}; // AdaptAlert feedback: alert id -> real?
  String status = 'connecting'; // connecting | live | stale | offline
  String? error;

  late final Bt39Client client = Bt39Client(token);
  Timer? _staleTimer;
  http.Client? _http;
  RealtimeChannel? _channel;
  bool _stopped = false, _disposed = false;
  final Map<String, String> _bedLabels = {};
  final Map<String, String> _patientNames = {};

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void start() {
    _stopped = false;
    _loadLabels();
    if (demo) {
      _loop((c) => api.lines('/ward/live', c).map(_demoFrame));
    } else {
      _loop((c) => client.liveOnce(c).map((b) => _Frame(b)));
      _loadAlerts();
    }
  }

  void stop() {
    _stopped = true;
    _staleTimer?.cancel();
    _http?.close();
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }

  void _pushHistory(LiveBed b) {
    final h = hrHistory.putIfAbsent(b.bed, () => []);
    h.add(b.hr);
    if (h.length > 120) h.removeAt(0);
  }

  // ------------------------------------------------------------------ streams

  _Frame _demoFrame(Map<String, dynamic> j) => _Frame(
        [for (final b in (j['beds'] as List? ?? const [])) LiveBed.fromJson(Map<String, dynamic>.from(b as Map))],
        [for (final a in (j['alerts'] as List? ?? const [])) StaffAlert.fromJson(Map<String, dynamic>.from(a as Map))],
      );

  /// Keeps one ward stream open, reconnecting with a back-off.
  Future<void> _loop(Stream<_Frame> Function(http.Client c) open) async {
    var delay = 1;
    var everLive = false;
    while (!_stopped) {
      _http = api.newClient();
      try {
        await for (final frame in open(_http!)) {
          if (_stopped) return;
          delay = 1;
          everLive = true;
          beds = frame.beds;
          if (frame.alerts != null) alerts = _keepAnswers(frame.alerts!);
          for (final b in frame.beds) {
            _pushHistory(b);
          }
          status = 'live';
          _staleTimer?.cancel();
          _staleTimer = Timer(const Duration(seconds: 5), () {
            status = 'stale';
            _notify();
          });
          _notify();
        }
      } catch (_) {}
      _http?.close();
      if (_stopped) return;
      status = everLive ? 'offline' : 'connecting';
      _notify();
      await Future.delayed(Duration(seconds: delay));
      delay = min(delay * 2, 15);
    }
  }

  /// A frame that was already on its way can predate an acknowledgement or a
  /// resolution the person just made. The service never takes those back, so
  /// keep them until the stream shows them.
  List<StaffAlert> _keepAnswers(List<StaffAlert> fresh) {
    final old = {for (final a in alerts) a.id: a};
    for (final a in fresh) {
      final o = old[a.id];
      if (o == null) continue;
      if (a.ackAt == null && o.ackAt != null) {
        a.ackAt = o.ackAt;
        a.ackBy = o.ackBy;
      }
      if (a.resolvedAt == null && o.resolvedAt != null) {
        a.resolvedAt = o.resolvedAt;
        a.resolution = o.resolution;
      }
    }
    return fresh;
  }

  Future<void> _loadAlerts() async {
    if (!AppConfig.supabaseEnabled || wardId == null) return;
    final sb = Supabase.instance.client;
    try {
      final rows = await sb.from('beds').select('id,label,patients(id,name,discharged_at)').eq('ward_id', wardId!);
      for (final r in rows) {
        _bedLabels[r['id'] as String] = r['label'] as String;
        for (final p in (r['patients'] as List? ?? [])) {
          _patientNames[p['id'] as String] = p['name'] as String;
        }
      }
      final list = await sb.from('alerts').select().eq('ward_id', wardId!).order('started_at', ascending: false).limit(200);
      alerts = list.map(_fromRow).toList();
      error = null;
      _notify();
      _channel ??= sb
          .channel('ward-alerts')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'alerts',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'ward_id', value: wardId!),
            callback: (_) => _loadAlerts(),
          )
          .subscribe();
    } catch (e) {
      error = tr('Alerts could not be loaded from Supabase.');
      _notify();
    }
  }

  StaffAlert _fromRow(Map<String, dynamic> r) => StaffAlert(
        id: r['id'], patientId: r['patient_id'], bed: _bedLabels[r['bed_id']] ?? '—', patientName: _patientNames[r['patient_id']] ?? tr('Patient'),
        kind: r['kind'], severity: r['severity'], message: r['message'] ?? '', news2: r['news2'], startedAt: DateTime.parse(r['started_at']).toLocal(),
        ackBy: r['acknowledged_by'] == null ? null : tr('Staff'), ackAt: r['acknowledged_at'] == null ? null : DateTime.parse(r['acknowledged_at']).toLocal(),
        resolvedAt: r['resolved_at'] == null ? null : DateTime.parse(r['resolved_at']).toLocal(), resolution: r['resolution'],
      );

  // ------------------------------------------------------------------ actions
  Future<String?> ack(StaffAlert a) async {
    if (demo) {
      final was = (a.ackBy, a.ackAt);
      a.ackBy = myName;
      a.ackAt = DateTime.now();
      _notify();
      final r = await api.post('/ward/alerts/${Uri.encodeComponent(a.id)}/ack');
      if (!r.ok && r.error != 'already_acknowledged') {
        a.ackBy = was.$1;
        a.ackAt = was.$2;
        _notify();
        return r.message;
      }
      return null;
    }
    final r = await client.ack(a.id);
    if (r.ok || r.error == 'already_acknowledged') {
      a.ackAt ??= DateTime.now();
      a.ackBy ??= myName;
      _notify();
    }
    return r.ok ? null : r.message;
  }

  Future<String?> resolve(StaffAlert a, String note) async {
    if (a.severity != 'low' && note.trim().length < 3) return tr('Add a short note on what was done (at least 3 characters).');
    if (demo) {
      final was = (a.resolvedAt, a.resolution);
      a.resolvedAt = DateTime.now();
      a.resolution = note.trim().isEmpty ? 'resolved' : note.trim();
      _notify();
      final r = await api.post('/ward/alerts/${Uri.encodeComponent(a.id)}/resolve', {'note': note.trim()});
      if (!r.ok) {
        a.resolvedAt = was.$1;
        a.resolution = was.$2;
        _notify();
        return r.message;
      }
      return null;
    }
    final r = await client.resolve(a.id, note.trim());
    if (r.ok) {
      a.resolvedAt = DateTime.now();
      a.resolution = note.trim();
      _notify();
    }
    return r.ok ? null : r.message;
  }

  /// Saved labels for this ward, read when the controller starts.
  Future<void> _loadLabels() async {
    final r = await api.get('/labels');
    if (!r.ok || _disposed) return;
    final saved = r.map['labels'];
    if (saved is! Map) return;
    for (final e in saved.entries) {
      // A label given while this was loading is newer.
      if (e.value is bool) labels.putIfAbsent('${e.key}', () => e.value as bool);
    }
    _notify();
  }

  /// AdaptAlert feedback from staff: was this alert clinically real? It shows
  /// at once and is saved on the service.
  Future<void> label(StaffAlert a, bool real) async {
    labels[a.id] = real;
    _notify();
    final r = await api.post('/labels', {'alert_id': a.id, 'real': real});
    if (!r.ok) {
      error = r.message;
      _notify();
    }
  }

  /// Share of labelled alerts that staff called real, per alert kind.
  Map<String, ({int real, int total})> get precisionByKind {
    final out = <String, ({int real, int total})>{};
    for (final a in alerts) {
      final l = labels[a.id];
      if (l == null) continue;
      final cur = out[a.kindName] ?? (real: 0, total: 0);
      out[a.kindName] = (real: cur.real + (l ? 1 : 0), total: cur.total + 1);
    }
    return out;
  }

  Future<String?> runScenario(String bed, String scenario) async {
    if (demo) {
      final r = await api.post('/ward/scenario', {'bed': bed, 'scenario': scenario});
      return r.ok ? null : r.message;
    }
    final r = await client.scenario(bed, scenario);
    return r.ok ? null : r.message;
  }

  List<StaffAlert> get sortedAlerts {
    const sev = {'high': 0, 'medium': 1, 'low': 2};
    return [...alerts]..sort((a, b) {
        if (a.open != b.open) return a.open ? -1 : 1;
        final s = sev[a.severity]!.compareTo(sev[b.severity]!);
        return s != 0 ? s : b.startedAt.compareTo(a.startedAt);
      });
  }

  int get openUnacked => alerts.where((a) => a.open && a.ackAt == null && a.kind != 'sensor_off').length;

  /// Demo answer for the doctor's patient chat, written by the service from
  /// the bed's own data. Returns the text, or the reason it could not.
  Future<String> demoAnswer(LiveBed b, String q) async {
    final r = await api.post('/ward/chat', {'bed': b.bed, 'q': q});
    return r.ok ? msg(r.map['text']) : (r.message ?? '');
  }
}
