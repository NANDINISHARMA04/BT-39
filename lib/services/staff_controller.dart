import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../engine/news2.dart';
import 'bt39_client.dart';

class StaffAlert {
  StaffAlert({required this.id, required this.patientId, required this.bed, required this.patientName, required this.kind, required this.severity, required this.message, required this.startedAt, this.news2, this.ackBy, this.ackAt, this.resolvedAt, this.resolution});
  final String id, patientId, bed, patientName, kind;
  String severity, message;
  int? news2;
  final DateTime startedAt;
  String? ackBy, resolution;
  DateTime? ackAt, resolvedAt;
  bool get open => resolvedAt == null;

  static const kindLabel = {
    'news2': 'NEWS2', 'trend_hr': 'Heart rate rising', 'trend_spo2': 'Oxygen falling', 'trend_rr': 'Breathing faster', 'trend_sbp': 'Blood pressure falling',
    'trend_temp': 'Temperature rising', 'shock_index': 'Shock index high', 'acute_spo2': 'Very low oxygen', 'acute_hr': 'Heart rate extreme',
    'acute_sbp': 'Very low blood pressure', 'acute_rr': 'Breathing rate extreme', 'sensor_off': 'Probe off', 'sensor_frozen': 'Sensor frozen', 'bp_overdue': 'BP overdue',
  };
  String get kindName => kindLabel[kind] ?? kind;
}

/// Feeds the doctor and nurse screens: live beds, ward alerts, actions.
///
/// Demo Mode runs a 12-bed ward on the device, scored with NEWS2 every second.
/// Signed-in staff get the real BT39 live stream and alerts from Supabase.
class StaffController extends ChangeNotifier {
  StaffController({required this.demo, required this.token, this.wardId, required this.myName});
  final bool demo;
  final Future<String?> Function() token;
  final String? wardId;
  final String myName;

  List<LiveBed> beds = [];
  List<StaffAlert> alerts = [];
  final Map<String, List<int?>> hrHistory = {};
  final Map<String, bool> labels = {}; // AdaptAlert feedback: alert id -> real?
  String status = 'connecting'; // connecting | live | stale | offline
  String? error;

  late final Bt39Client client = Bt39Client(token);
  Timer? _timer, _staleTimer;
  http.Client? _http;
  RealtimeChannel? _channel;
  bool _stopped = false;
  final Map<String, String> _bedLabels = {};
  final Map<String, String> _patientNames = {};

  void start() {
    _stopped = false;
    if (demo) {
      _demoInit();
      status = 'live';
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _demoTick());
    } else {
      _liveLoop();
      _loadAlerts();
    }
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    _staleTimer?.cancel();
    _http?.close();
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  void _pushHistory(LiveBed b) {
    final h = hrHistory.putIfAbsent(b.bed, () => []);
    h.add(b.hr);
    if (h.length > 120) h.removeAt(0);
  }

  // ------------------------------------------------------------------ live mode
  Future<void> _liveLoop() async {
    var delay = 1;
    var everLive = false;
    while (!_stopped) {
      _http = http.Client();
      try {
        await for (final frame in client.liveOnce(_http!)) {
          if (_stopped) return;
          delay = 1;
          everLive = true;
          beds = frame;
          for (final b in frame) {
            _pushHistory(b);
          }
          status = 'live';
          _staleTimer?.cancel();
          _staleTimer = Timer(const Duration(seconds: 5), () {
            status = 'stale';
            notifyListeners();
          });
          notifyListeners();
        }
      } catch (_) {}
      _http?.close();
      if (_stopped) return;
      status = everLive ? 'offline' : 'connecting';
      notifyListeners();
      await Future.delayed(Duration(seconds: delay));
      delay = min(delay * 2, 15);
    }
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
      notifyListeners();
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
      error = 'Alerts could not be loaded from Supabase.';
      notifyListeners();
    }
  }

  StaffAlert _fromRow(Map<String, dynamic> r) => StaffAlert(
        id: r['id'], patientId: r['patient_id'], bed: _bedLabels[r['bed_id']] ?? '—', patientName: _patientNames[r['patient_id']] ?? 'Patient',
        kind: r['kind'], severity: r['severity'], message: r['message'] ?? '', news2: r['news2'], startedAt: DateTime.parse(r['started_at']).toLocal(),
        ackBy: r['acknowledged_by'] == null ? null : 'Staff', ackAt: r['acknowledged_at'] == null ? null : DateTime.parse(r['acknowledged_at']).toLocal(),
        resolvedAt: r['resolved_at'] == null ? null : DateTime.parse(r['resolved_at']).toLocal(), resolution: r['resolution'],
      );

  // ------------------------------------------------------------------ actions
  Future<String?> ack(StaffAlert a) async {
    if (demo) {
      a.ackBy = myName;
      a.ackAt = DateTime.now();
      notifyListeners();
      return null;
    }
    final r = await client.ack(a.id);
    if (r.ok || r.error == 'already_acknowledged') {
      a.ackAt ??= DateTime.now();
      a.ackBy ??= myName;
      notifyListeners();
    }
    return r.ok ? null : r.message;
  }

  Future<String?> resolve(StaffAlert a, String note) async {
    if (a.severity != 'low' && note.trim().length < 3) return 'Add a short note on what was done (at least 3 characters).';
    if (demo) {
      a.resolvedAt = DateTime.now();
      a.resolution = note.trim().isEmpty ? 'resolved' : note.trim();
      _quiet[a.id] = 0;
      notifyListeners();
      return null;
    }
    final r = await client.resolve(a.id, note.trim());
    if (r.ok) {
      a.resolvedAt = DateTime.now();
      a.resolution = note.trim();
      notifyListeners();
    }
    return r.ok ? null : r.message;
  }

  /// AdaptAlert feedback from staff: was this alert clinically real?
  void label(StaffAlert a, bool real) {
    labels[a.id] = real;
    notifyListeners();
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
      _scen[bed] = scenario;
      notifyListeners();
      return null;
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

  // ------------------------------------------------------------------ demo ward
  final _rnd = Random(39);
  final Map<String, Map<String, double>> _v = {};
  final Map<String, Map<String, double>> _base = {};
  final Map<String, String> _scen = {};
  final Map<String, int> _low = {}, _off = {};
  final Map<String, int> _quiet = {};
  final Map<String, ({String name, int age, String sex, bool o2})> _pt = {};
  int _alertSeq = 1;

  void _demoInit() {
    const people = [
      ('B01', 'Ramesh Iyer', 67, 'M', true), ('B02', 'Sunita Deshmukh', 54, 'F', false), ('B03', 'Imran Shaikh', 45, 'M', false),
      ('B04', 'Lakshmi Menon', 72, 'F', false), ('B05', 'Harpreet Gill', 61, 'M', true), ('B06', 'Asha Kulkarni', 38, 'F', false),
      ('B08', 'Gopal Das', 80, 'M', false), ('B09', 'Neelam Joshi', 59, 'F', false), ('B10', 'Vivek Rathore', 33, 'M', false),
      ('B11', 'Fatima Begum', 66, 'F', true), ('B12', 'Dinesh Patil', 49, 'M', false),
    ];
    for (final (bed, name, age, sex, o2) in people) {
      _pt[bed] = (name: name, age: age, sex: sex, o2: o2);
      final b = {'hr': 70 + _rnd.nextDouble() * 16, 'spo2': o2 ? 95.0 : 97 + _rnd.nextDouble() * 2, 'rr': 14 + _rnd.nextDouble() * 4, 'sbp': 118 + _rnd.nextDouble() * 18, 'dbp': 72 + _rnd.nextDouble() * 8, 'temp': 36.6 + _rnd.nextDouble() * .5};
      _base[bed] = b;
      _v[bed] = {...b};
      _scen[bed] = 'stable';
    }
    _scen['B02'] = 'sepsis';
    _scen['B05'] = 'hypoxia';
    for (var i = 0; i < 40; i++) {
      _demoTick(silent: true);
    }
  }

  static const _targets = {
    'sepsis': {'hr': 128.0, 'rr': 26.0, 'temp': 38.8, 'sbp': 92.0, 'spo2': 93.0},
    'hypoxia': {'spo2': 86.0, 'rr': 24.0, 'hr': 108.0},
    'tachy': {'hr': 152.0},
  };

  double _g() => (_rnd.nextDouble() + _rnd.nextDouble() + _rnd.nextDouble() - 1.5);

  void _demoTick({bool silent = false}) {
    final out = <LiveBed>[];
    for (var i = 1; i <= 12; i++) {
      final bed = 'B${i.toString().padLeft(2, '0')}';
      final p = _pt[bed];
      if (p == null) {
        out.add(LiveBed(bed: bed));
        continue;
      }
      final v = _v[bed]!, base = _base[bed]!, sc = _scen[bed]!;
      final target = {...base, ...?_targets[sc]};
      for (final k in v.keys) {
        v[k] = v[k]! + (target[k]! - v[k]!) * .08 + _g() * (k == 'temp' ? .03 : k == 'spo2' ? .3 : 1);
      }
      final off = sc == 'probe_off';
      final hr = off ? null : v['hr']!.round(), spo2 = off ? null : v['spo2']!.clamp(70, 100).round();
      final s = news2(rr: v['rr']!.round(), spo2: spo2, sbp: v['sbp']!.round(), hr: hr, temp: double.parse(v['temp']!.toStringAsFixed(1)), onOxygen: p.o2);
      _low[bed] = (spo2 != null && spo2 < 88) ? (_low[bed] ?? 0) + 1 : 0;
      _off[bed] = off ? (_off[bed] ?? 0) + 1 : 0;
      _rules(bed, p.name, s, hr: hr, spo2: spo2, rr: v['rr']!.round(), temp: v['temp']!);
      final b = LiveBed(
        bed: bed, patientId: 'demo-$bed', name: p.name, age: p.age, sex: p.sex, hr: hr, spo2: spo2, rr: v['rr']!.round(), sbp: v['sbp']!.round(), dbp: v['dbp']!.round(),
        temp: double.parse(v['temp']!.toStringAsFixed(1)), news2: s.total, band: s.band, onOxygen: p.o2, consciousness: 'A', staleS: off ? _off[bed] : 0, nibpAgeS: 300 + i * 40,
        openAlerts: alerts.where((a) => a.bed == bed && a.open).map((a) => LiveAlert(a.id, a.kind, a.severity, a.ackAt != null)).toList(),
      );
      out.add(b);
      _pushHistory(b);
    }
    beds = out;
    if (!silent) notifyListeners();
  }

  void _open(String bed, String name, String kind, String severity, String msg, int? score) {
    const rank = {'low': 0, 'medium': 1, 'high': 2};
    final existing = alerts.where((a) => a.bed == bed && a.kind == kind && a.open).firstOrNull;
    if (existing != null) {
      if (rank[severity]! > rank[existing.severity]!) existing.severity = severity;
      existing.message = msg;
      existing.news2 = score;
      _quiet[existing.id] = 0;
      return;
    }
    final a = StaffAlert(id: 'demo-${_alertSeq++}', patientId: 'demo-$bed', bed: bed, patientName: name, kind: kind, severity: severity, message: msg, news2: score, startedAt: DateTime.now());
    alerts.insert(0, a);
    _quiet[a.id] = 0;
  }

  void _rules(String bed, String name, News2Score s, {int? hr, int? spo2, required int rr, required double temp}) {
    final vals = 'HR ${hr ?? '—'}, RR $rr, SpO₂ ${spo2 ?? '—'}%, Temp ${temp.toStringAsFixed(1)} °C';
    if (s.band != 'low') {
      _open(bed, name, 'news2', switch (s.band) { 'high' => 'high', 'medium' => 'medium', _ => 'low' }, 'NEWS2 ${s.total} (${bandLabel[s.band]}): $vals', s.total);
    }
    if ((_low[bed] ?? 0) >= 5) _open(bed, name, 'acute_spo2', 'high', 'SpO₂ ${spo2 ?? '—'}% for 30 s on air', s.total);
    if (hr != null && hr > 150) _open(bed, name, 'acute_hr', 'high', 'Heart rate $hr for 30 s', s.total);
    if ((_off[bed] ?? 0) >= 5) _open(bed, name, 'sensor_off', 'low', 'No heart rate or SpO₂ for 30 s. Check the probe.', null);
    // Auto-resolve: quiet for 20 s (shortened from 10 min for the demo).
    for (final a in alerts.where((a) => a.bed == bed && a.open)) {
      final firing = switch (a.kind) {
        'news2' => s.band != 'low',
        'acute_spo2' => (_low[bed] ?? 0) > 0,
        'acute_hr' => hr != null && hr > 150,
        'sensor_off' => (_off[bed] ?? 0) > 0,
        _ => false,
      };
      _quiet[a.id] = firing ? 0 : (_quiet[a.id] ?? 0) + 1;
      if ((_quiet[a.id] ?? 0) >= 20) {
        a.resolvedAt = DateTime.now();
        a.resolution = 'auto';
      }
    }
  }

  /// Demo answer for the doctor's patient chat, from the bed's own data.
  String demoAnswer(LiveBed b, String q) {
    final open = alerts.where((a) => a.bed == b.bed && a.open).toList();
    final hist = (hrHistory[b.bed] ?? []).whereType<int>().toList();
    final trend = hist.length > 10 ? hist.last - hist[hist.length - 10] : 0;
    final buf = StringBuffer('${b.name} (${b.age}${b.sex}, bed ${b.bed}) has NEWS2 ${b.news2 ?? '—'} (${bandLabel[b.band] ?? '—'}). ');
    buf.write('Now: HR ${b.hr ?? '—'}, SpO₂ ${b.spo2 ?? '—'}%, RR ${b.rr ?? '—'}, BP ${b.sbp ?? '—'}/${b.dbp ?? '—'} (cuff ${((b.nibpAgeS ?? 0) / 60).round()} min old), Temp ${b.temp?.toStringAsFixed(1) ?? '—'} °C${b.onOxygen == true ? ', on oxygen' : ''}. ');
    if (trend.abs() >= 5) buf.write('Heart rate has ${trend > 0 ? 'risen' : 'fallen'} by ${trend.abs()} over the last few minutes. ');
    buf.write(open.isEmpty ? 'There are no open alerts. ' : 'Open alerts: ${open.map((a) => '${a.kindName} (${severityLabel[a.severity]})').join(', ')}. ');
    if (q.toLowerCase().contains('sepsis') || (b.temp ?? 0) >= 38.1 && (b.hr ?? 0) > 110) buf.write('The pattern of fever, fast heart rate and fast breathing fits the sepsis screening criteria; consider the sepsis pathway. ');
    buf.write('\n\nDemo Mode answer, built on the device from this bed\'s data. Signed-in doctors get the BT39 assistant, which also reads uploaded notes and reports.');
    return buf.toString();
  }
}
