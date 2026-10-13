import '../l10n/l10n.dart';
import '../l10n/msg.dart';

/// A mirror of the AdaptAlert engine that runs on the PulseOS service.
///
/// The engine itself (seven stages, learning, safety floor, explanations)
/// lives on the server, one per wearer. This file only holds what the server
/// sends, in the shapes the screens already read: the snapshot at connect, then
/// one update per tick (see `docs/pulseos.md`, section 5). It makes no decision.
///
/// Text arrives as messages and is rendered when it is read, so switching the
/// language changes alerts that are already on screen.

const tauMin = .30, tauMax = .75, tauWeekCap = .10;
const vitals = ['hr', 'spo2', 'temp'];
const vitalName = {'hr': 'heart rate', 'spo2': 'oxygen', 'temp': 'temperature'};

/// The history the engine keeps for charts: four hours of one-minute windows.
const maxHistory = 240;

/// The service keeps at most this many alerts and held events per wearer.
const maxKept = 200;

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.round() ?? 0;
Map<String, dynamic> _obj(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

String bucketLabel(String key) {
  final p = key.split('|');
  if (p.first == 'SAFETY') return '${tr('Safety floor')} · ${tr(vitalName[p[1]]!)}';
  final act = {'rest': 'Resting', 'light': 'Light activity or cooling down', 'active': 'Active'}[p[0]]!;
  final what = {'hr': 'heart rate up', 'spo2': 'oxygen down', 'temp': 'temperature up', 'multi': 'several vitals together'}[p[1]]!;
  final band = p[2] == 'multi' ? '' : (p[2] == 'high' ? ' a lot' : ' a little');
  // Hindi keys: every act value, every what+band combination, 'day' and 'night'.
  final whatBand = '$what$band';
  return '${tr(act)} · ${tr(whatBand)} · ${tr(p[3])}';
}

/// One sensor reading from the band.
class Reading {
  const Reading({required this.hr, required this.spo2, required this.temp, required this.motion, required this.contact});
  final int hr, spo2;
  final double temp, motion, contact;
}

/// The person's usual value and spread for one vital in one activity.
class Baseline {
  const Baseline(this.mu, this.sd);
  final double mu, sd;
  factory Baseline.fromJson(Map<String, dynamic> j) => Baseline(_d(j['mu']), _d(j['sd']));
}

/// One reading window (a simulated minute) with what the engine made of it.
class WindowRecord {
  WindowRecord({required this.t, required this.r, required this.sqi, required this.act, required this.ctx, required this.good, required this.mu, required this.sd, required this.z, required this.fixed, this.alert = 0, this.held = false});
  final int t;
  final Reading r;
  final double sqi;
  final String act, ctx;
  final bool good, fixed;
  final Map<String, double> mu, sd, z;

  /// The level of the alert sent in this window (0 for none).
  int alert;
  bool held;

  double value(String v) => switch (v) { 'hr' => r.hr.toDouble(), 'spo2' => r.spo2.toDouble(), _ => r.temp };

  factory WindowRecord.fromJson(Map<String, dynamic> j) {
    Map<String, double> vit(Object? o) => {for (final e in _obj(o).entries) e.key: _d(e.value)};
    return WindowRecord(
      t: _i(j['t']),
      r: Reading(hr: _i(j['hr']), spo2: _i(j['spo2']), temp: _d(j['temp']), motion: _d(j['motion']), contact: _d(j['contact'])),
      sqi: _d(j['sqi']),
      act: '${j['act'] ?? ''}',
      ctx: '${j['ctx'] ?? ''}',
      good: j['good'] == true,
      fixed: j['fixed'] == true,
      mu: vit(j['mu']),
      sd: vit(j['sd']),
      z: vit(j['z']),
      alert: _i(j['alert']),
      held: j['held'] == true,
    );
  }
}

enum StageState { idle, ok, watch, warn, send, hold, crit, bad }

/// One step of the pipeline (A signal quality ... G explanation).
class Stage {
  const Stage(this.state, String text) : _text = text;
  const Stage._(this.state, this._text);
  final StageState state;
  final Object? _text;

  /// The step's text in the app's language, rendered on every read.
  String get text => msg(_text);

  factory Stage.fromJson(Map<String, dynamic> j) => Stage._(StageState.values.asNameMap()['${j['s']}'] ?? StageState.idle, j['x']);
}

enum PatientFeedback { active, loose, unwell, notSure }

enum DoctorLabel { pending, confirmed, rejected }

/// One line of "who was told".
class EscalationStep {
  const EscalationStep(this.t, this.who, Object? what) : _what = what;
  final int t;

  /// English ('You', 'Caregiver', 'Doctor', 'SOS'); screens translate it.
  final String who;
  final Object? _what;

  /// What happened, in the app's language.
  String get what => msg(_what);

  factory EscalationStep.fromJson(Map<String, dynamic> j) => EscalationStep(_i(j['t']), '${j['who'] ?? ''}', j['what']);
}

/// What the alert page shows beyond the alert itself: how sure the personal
/// estimate is, and what feedback would change. All numbers come from the server.
class AlertExplain {
  const AlertExplain({required this.ci, this.singleP, required this.ifFalse, required this.tauFalse, required this.ifReal, required this.tauReal});

  /// The 90% interval of the personal estimate.
  final ({double lo, double hi}) ci;

  /// The model's score if only the main vital had changed (alerts with several vitals only).
  final double? singleP;

  /// The next similar pattern's score and the threshold after a false-alarm label.
  final double ifFalse, tauFalse;

  /// The same after a real label.
  final double ifReal, tauReal;

  /// Whether the next similar pattern would still be sent after a false-alarm label.
  bool get ifFalseSends => ifFalse >= tauFalse;

  factory AlertExplain.fromJson(Map<String, dynamic> j) {
    final ci = _obj(j['ci']);
    return AlertExplain(
      ci: (lo: _d(ci['lo']), hi: ci.containsKey('hi') ? _d(ci['hi']) : 1.0),
      singleP: j['single_p'] == null ? null : _d(j['single_p']),
      ifFalse: _d(j['if_false']),
      tauFalse: _d(j['tau_false']),
      ifReal: _d(j['if_real']),
      tauReal: _d(j['tau_real']),
    );
  }
}

/// An alert the engine sent.
class HealthAlert {
  HealthAlert({
    required this.id,
    required this.t,
    required this.level,
    required Object? title,
    List<Object?> reasons = const [],
    List<Object?> path = const [],
    required this.p,
    required this.pg,
    required this.pu,
    required this.w,
    required this.n,
    required this.tau,
    required this.key,
    required this.safety,
    required this.hr,
    required this.spo2,
    required this.temp,
    this.autoSos = false,
    this.explain,
  })  : _title = title,
        _reasons = reasons,
        _path = path;

  final int id, t, level, hr, spo2;
  final String key;
  final double p, pg, pu, w, n, tau, temp;
  final bool safety;
  Object? _title;
  List<Object?> _reasons, _path;

  /// True for a level-4 alert when the patient's "Auto SOS" preference is on.
  bool autoSos;
  AlertExplain? explain;
  PatientFeedback? patientFeedback;
  DoctorLabel doctor = DoctorLabel.pending;

  /// Who reviewed it (a doctor or nurse), when known.
  String? reviewedBy;
  final List<EscalationStep> escalation = [];
  static const levelName = {1: 'Check-in', 2: 'Warning', 3: 'Urgent', 4: 'Critical'};

  /// The words below are rendered when read, so a language switch shows at once.
  String get title => msg(_title);
  List<String> get reasons => [for (final r in _reasons) msg(r)];
  List<String> get path => [for (final r in _path) msg(r)];

  /// The level's name in the app's language ([levelName] stays English).
  String get levelLabel => tr(levelName[level]!);

  factory HealthAlert.fromJson(Map<String, dynamic> j) {
    final fb = PatientFeedback.values.asNameMap()['${j['feedback']}'];
    final a = HealthAlert(
      id: _i(j['id']), t: _i(j['t']), level: _i(j['level']), title: j['title'],
      reasons: j['reasons'] is List ? List<Object?>.from(j['reasons'] as List) : const [],
      path: j['path'] is List ? List<Object?>.from(j['path'] as List) : const [],
      p: _d(j['p']), pg: _d(j['pg']), pu: _d(j['pu']), w: _d(j['w']), n: _d(j['n']), tau: _d(j['tau']),
      key: '${j['key']}', safety: j['safety'] == true, hr: _i(j['hr']), spo2: _i(j['spo2']), temp: _d(j['temp']),
      autoSos: j['auto_sos'] == true,
      explain: j['explain'] is Map ? AlertExplain.fromJson(_obj(j['explain'])) : null,
    );
    a.patientFeedback = fb;
    a.doctor = DoctorLabel.values.asNameMap()['${j['doctor']}'] ?? DoctorLabel.pending;
    a.reviewedBy = j['reviewed_by'] as String?;
    if (j['escalation'] is List) {
      a.escalation.addAll([for (final e in j['escalation'] as List) EscalationStep.fromJson(_obj(e))]);
    }
    return a;
  }

  /// Takes in the newer copy the server sent of this same alert, so screens
  /// that hold this object see the change. [authoritative] is true for a
  /// snapshot (the server's word is final); otherwise a feedback or label that
  /// is already set is kept, because the server never takes one back and a line
  /// that was already on its way can predate the answer the person just gave.
  void absorb(HealthAlert o, {bool authoritative = false}) {
    _title = o._title;
    _reasons = o._reasons;
    _path = o._path;
    autoSos = o.autoSos;
    explain = o.explain;
    escalation
      ..clear()
      ..addAll(o.escalation);
    if (authoritative) {
      patientFeedback = o.patientFeedback;
      doctor = o.doctor;
      reviewedBy = o.reviewedBy;
    } else {
      patientFeedback = o.patientFeedback ?? patientFeedback;
      if (o.doctor != DoctorLabel.pending || doctor == DoctorLabel.pending) {
        doctor = o.doctor;
        reviewedBy = o.reviewedBy ?? reviewedBy;
      }
    }
  }
}

/// An alert the engine held back because the person's history says it is harmless.
class HeldEvent {
  HeldEvent({required this.t, required this.key, required this.p, required this.tau, required this.pg, required this.pu, required this.n, required this.rec});
  final int t;
  final String key;
  final double p, tau, pg, pu, n;
  final WindowRecord rec;

  factory HeldEvent.fromJson(Map<String, dynamic> j) => HeldEvent(
        t: _i(j['t']), key: '${j['key']}', p: _d(j['p']), tau: _d(j['tau']), pg: _d(j['pg']), pu: _d(j['pu']), n: _d(j['n']),
        rec: WindowRecord.fromJson(_obj(j['rec'])),
      );
}

/// What the engine has learned about one pattern: feedback counts, the score it
/// gives the pattern now, and whether that score would still send an alert.
class Bucket {
  const Bucket({this.r = 0, this.f = 0, this.p = .5, this.send = false});
  final double r, f, p;
  final bool send;
  factory Bucket.fromJson(Map<String, dynamic> j) => Bucket(r: _d(j['r']), f: _d(j['f']), p: j.containsKey('p') ? _d(j['p']) : .5, send: j['send'] == true);
}

/// The engine's state as the server last described it.
class AdaptAlertEngine {
  /// Simulated clock in minutes since midnight.
  int t = 0;

  /// Shown until the first snapshot arrives; the server's own starting values.
  Map<String, Map<String, Baseline>> base = {
    'rest': {'hr': const Baseline(66, 6), 'spo2': const Baseline(97.3, 1), 'temp': const Baseline(36.55, .22)},
    'light': {'hr': const Baseline(86, 8), 'spo2': const Baseline(97.2, .9), 'temp': const Baseline(36.6, .25)},
    'active': {'hr': const Baseline(110, 10), 'spo2': const Baseline(97, 1), 'temp': const Baseline(36.7, .3)},
  };
  double tau = .5, weekStartTau = .5, sqiMin = .5;
  int labels = 0, fixedCount = 0, sentCount = 0;
  Map<String, Bucket> buckets = {};

  /// Newest first.
  final List<HealthAlert> alerts = [];

  /// Newest first.
  final List<HeldEvent> held = [];

  /// Oldest first, at most [maxHistory].
  final List<WindowRecord> history = [];
  Map<String, Stage> pipe = {};

  /// ok | watch | held | alert | band
  String status = 'ok';

  WindowRecord? get last => history.isEmpty ? null : history.last;

  HealthAlert? alertById(int id) {
    for (final a in alerts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// The score the engine gives a learned pattern now, from the server.
  double bucketP(String key) => buckets[key]?.p ?? .5;

  /// Replaces everything with the server's snapshot (the `state` of the first
  /// line on a connection). Alerts that are already known keep their object.
  void applySnapshot(Map state) {
    final s = _obj(state);
    _scalars(s);
    _lists(s);
    _syncAlerts([for (final a in (s['alerts'] as List? ?? const [])) HealthAlert.fromJson(_obj(a))], replace: true);
    held
      ..clear()
      ..addAll([for (final h in (s['held'] as List? ?? const [])) HeldEvent.fromJson(_obj(h))].take(maxKept));
    history
      ..clear()
      ..addAll([for (final r in (s['history'] as List? ?? const [])) WindowRecord.fromJson(_obj(r))]);
    _trimHistory();
  }

  /// Applies one update line: the new window, the figures that changed, alerts
  /// that are new or changed, and held events. Returns the held events this
  /// line added, oldest first.
  List<HeldEvent> applyUpdate(Map line) {
    final u = _obj(line);
    _scalars(u);
    _lists(u);
    if (u['rec'] is Map) {
      history.add(WindowRecord.fromJson(_obj(u['rec'])));
      _trimHistory();
    }
    _syncAlerts([for (final a in (u['alerts'] as List? ?? const [])) HealthAlert.fromJson(_obj(a))], replace: false);
    final added = [for (final h in (u['held_new'] as List? ?? const [])) HeldEvent.fromJson(_obj(h))];
    for (final h in added) {
      held.insert(0, h);
    }
    if (held.length > maxKept) held.removeRange(maxKept, held.length);
    return added;
  }

  void _trimHistory() {
    if (history.length > maxHistory) history.removeRange(0, history.length - maxHistory);
  }

  /// The single figures, each only when the line carries it.
  void _scalars(Map<String, dynamic> s) {
    if (s['t'] != null) t = _i(s['t']);
    if (s['tau'] != null) tau = _d(s['tau']);
    if (s['week_start_tau'] != null) weekStartTau = _d(s['week_start_tau']);
    if (s['sqi_min'] != null) sqiMin = _d(s['sqi_min']);
    if (s['labels'] != null) labels = _i(s['labels']);
    if (s['fixed'] != null) fixedCount = _i(s['fixed']);
    if (s['sent'] != null) sentCount = _i(s['sent']);
    if (s['status'] != null) status = '${s['status']}';
  }

  /// The tables that are replaced whole when present: baselines, learned
  /// patterns and the pipeline.
  void _lists(Map<String, dynamic> s) {
    if (s['base'] is Map) {
      base = {
        for (final c in _obj(s['base']).entries) c.key: {for (final v in _obj(c.value).entries) v.key: Baseline.fromJson(_obj(v.value))},
      };
    }
    if (s['buckets'] is List) {
      buckets = {};
      for (final b in s['buckets'] as List) {
        final j = _obj(b);
        buckets['${j['key']}'] = Bucket.fromJson(j);
      }
    }
    if (s['pipe'] is Map) {
      pipe = {for (final e in _obj(s['pipe']).entries) e.key: Stage.fromJson(_obj(e.value))};
    }
  }

  /// Puts [incoming] alerts into the list, newest first by id. An alert that
  /// is already known is updated in place; with [replace], known alerts the
  /// server no longer lists are dropped.
  void _syncAlerts(List<HealthAlert> incoming, {required bool replace}) {
    if (replace) {
      final known = {for (final a in alerts) a.id: a};
      final next = <HealthAlert>[];
      for (final a in incoming) {
        final old = known[a.id];
        if (old == null) {
          next.add(a);
        } else {
          old.absorb(a, authoritative: true);
          next.add(old);
        }
      }
      alerts
        ..clear()
        ..addAll(next.take(maxKept));
      return;
    }
    for (final a in incoming) {
      final i = alerts.indexWhere((x) => x.id == a.id);
      if (i >= 0) {
        alerts[i].absorb(a);
      } else {
        final at = alerts.indexWhere((x) => x.id < a.id);
        alerts.insert(at < 0 ? alerts.length : at, a);
      }
    }
    if (alerts.length > maxKept) alerts.removeRange(maxKept, alerts.length);
  }
}

String pct(double x) => '${(x * 100).round()}%';

String hhmm(int t) {
  final h = (t ~/ 60) % 24, m = t % 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}
