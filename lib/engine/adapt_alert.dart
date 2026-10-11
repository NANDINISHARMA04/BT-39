import 'dart:math';

/// AdaptAlert: a self-learning, explainable alert engine for one wearer.
///
/// Every reading window (one simulated minute) goes through seven stages:
///   A signal quality, B activity, C personal normal, D safety floor,
///   E anomaly check, F decision (learns from feedback), G explanation.
///
/// The decision blends a fixed global decision tree with what this person's
/// feedback says about the same pattern, and compares it with a personal
/// threshold τ. Safety-floor alerts skip the model and can never be learned away.

const tauMin = .30, tauMax = .75, tauWeekCap = .10;
const vitals = ['hr', 'spo2', 'temp'];
const vitalName = {'hr': 'heart rate', 'spo2': 'oxygen', 'temp': 'temperature'};

class Features {
  Features({required this.act, required this.primary, required this.zHR, required this.zSpO2, required this.zTemp, required this.numAbn, this.sqi = 1, this.dur = 0, this.night = false});
  final String act; // rest | light | active
  final String primary; // hr | spo2 | temp | multi
  final double zHR, zSpO2, zTemp, sqi;
  final int numAbn, dur;
  final bool night;
}

class TreeResult {
  const TreeResult(this.p, this.path);
  final double p;
  final List<String> path;
}

/// The global model: a small, readable decision tree. Every leaf has a reason.
TreeResult globalTree(Features f) {
  if (f.sqi < .6) return const TreeResult(.10, ['Signal quality below 0.6']);
  if (f.act != 'rest' && f.primary == 'hr') return const TreeResult(.18, ['Heart-rate rise while moving or cooling down']);
  if (f.numAbn >= 2) {
    if (f.zSpO2 <= -2) return const TreeResult(.90, ['Two or more vitals abnormal together', 'Oxygen is part of it']);
    return const TreeResult(.82, ['Two or more vitals abnormal together']);
  }
  if (f.primary == 'spo2') {
    if (f.zSpO2 <= -3.5) return const TreeResult(.84, ['Oxygen far below your normal']);
    if (f.night) return const TreeResult(.55, ['Mild oxygen dip during sleep']);
    return const TreeResult(.62, ['Oxygen slightly below your normal']);
  }
  if (f.primary == 'temp') {
    if (f.zTemp >= 3.5) return const TreeResult(.82, ['Temperature well above your normal']);
    return const TreeResult(.56, ['Temperature slightly raised']);
  }
  if (f.zHR >= 5) return const TreeResult(.80, ['Heart rate far above your resting normal']);
  return const TreeResult(.58, ['Moderate heart-rate rise at rest']);
}

/// Groups similar situations, so feedback on one applies to the next.
String bucketKey(Features f) {
  final zp = switch (f.primary) { 'hr' => f.zHR, 'spo2' => -f.zSpO2, 'temp' => f.zTemp, _ => 0.0 };
  final band = f.primary == 'multi' ? 'multi' : (zp >= 5 ? 'high' : 'mod');
  return '${f.act}|${f.primary}|$band|${f.night ? 'night' : 'day'}';
}

String bucketLabel(String key) {
  final p = key.split('|');
  if (p.first == 'SAFETY') return 'Safety floor · ${vitalName[p[1]]}';
  final act = {'rest': 'Resting', 'light': 'Light activity or cooling down', 'active': 'Active'}[p[0]];
  final what = {'hr': 'heart rate up', 'spo2': 'oxygen down', 'temp': 'temperature up', 'multi': 'several vitals together'}[p[1]];
  final band = p[2] == 'multi' ? '' : (p[2] == 'high' ? ' a lot' : ' a little');
  return '$act · $what$band · ${p[3]}';
}

Features featuresFromKey(String key) {
  final p = key.split('|');
  final hi = p[2] == 'high';
  return Features(
    act: p[0],
    primary: p[1],
    numAbn: p[1] == 'multi' ? 2 : 1,
    night: p[3] == 'night',
    zHR: p[1] == 'hr' ? (hi ? 6 : 3.5) : (p[1] == 'multi' ? 4 : 0),
    zSpO2: p[1] == 'spo2' ? (hi ? -4 : -3) : (p[1] == 'multi' ? -2.5 : 0),
    zTemp: p[1] == 'temp' ? (hi ? 4 : 3) : 0,
  );
}

class Bucket {
  double r = 0, f = 0;
  Map<String, dynamic> toJson() => {'r': r, 'f': f};
}

/// Personal estimate from this person's labels for one pattern (Beta(1,1) prior),
/// and how much to trust it: w = n / (n + 4).
({double n, double pu, double w}) personal(Bucket? b) {
  final n = b == null ? 0.0 : b.r + b.f;
  return (n: n, pu: b == null ? .5 : (b.r + 1) / (n + 2), w: n / (n + 4));
}

double nudgedTau(double tau, double weekStartTau, double delta) {
  var t = (tau + delta).clamp(tauMin, tauMax).toDouble();
  if (t - weekStartTau > tauWeekCap) t = weekStartTau + tauWeekCap;
  return t;
}

// ---------------------------------------------------------------------------
// Live engine

class Reading {
  const Reading({required this.hr, required this.spo2, required this.temp, required this.motion, required this.contact});
  final int hr, spo2;
  final double temp, motion, contact;
}

class Baseline {
  Baseline(this.mu, double sd) : v = sd * sd;
  double mu, v;
  double get sd => sqrt(v);
}

class WindowRecord {
  WindowRecord({required this.t, required this.r, required this.sqi, required this.act, required this.ctx, required this.good, required this.mu, required this.sd, required this.z, required this.fixed});
  final int t;
  final Reading r;
  final double sqi;
  final String act, ctx;
  final bool good, fixed;
  final Map<String, double> mu, sd, z;
  int alert = 0;
  bool held = false;
  double value(String v) => switch (v) { 'hr' => r.hr.toDouble(), 'spo2' => r.spo2.toDouble(), _ => r.temp };
}

enum StageState { idle, ok, watch, warn, send, hold, crit, bad }

class Stage {
  const Stage(this.state, this.text);
  final StageState state;
  final String text;
}

enum PatientFeedback { active, loose, unwell, notSure }

enum DoctorLabel { pending, confirmed, rejected }

class EscalationStep {
  const EscalationStep(this.t, this.who, this.what);
  final int t;
  final String who, what;
}

class HealthAlert {
  HealthAlert({required this.id, required this.t, required this.level, required this.title, required this.reasons, required this.path, required this.p, required this.pg, required this.pu, required this.w, required this.n, required this.tau, required this.key, required this.safety, required this.hr, required this.spo2, required this.temp});
  final int id, t, level, hr, spo2;
  final String title, key;
  final List<String> reasons, path;
  final double p, pg, pu, w, n, tau, temp;
  final bool safety;
  PatientFeedback? patientFeedback;
  DoctorLabel doctor = DoctorLabel.pending;
  double contribR = 0, contribF = 0;
  final List<EscalationStep> escalation = [];
  static const levelName = {1: 'Check-in', 2: 'Warning', 3: 'Urgent', 4: 'Critical'};
  String get levelLabel => levelName[level]!;
}

class HeldEvent {
  HeldEvent({required this.t, required this.key, required this.p, required this.tau, required this.pg, required this.pu, required this.n, required this.rec});
  final int t;
  final String key;
  final double p, tau, pg, pu, n;
  final WindowRecord rec;
}

class _Episode {
  _Episode(this.start);
  final int start;
  String? lastKey;
  int sentLevel = 0, calm = 0;
  final Set<String> vit = {};
}

typedef AlertCallback = void Function(HealthAlert a);

class AdaptAlertEngine {
  AdaptAlertEngine({this.onAlert, this.onHeld, this.onBadSignal});

  AlertCallback? onAlert;
  void Function(HeldEvent h)? onHeld;
  void Function()? onBadSignal;

  /// Simulated clock in minutes since midnight.
  int t = 7 * 60;
  final Map<String, Map<String, Baseline>> base = {
    'rest': {'hr': Baseline(66, 6), 'spo2': Baseline(97.3, 1), 'temp': Baseline(36.55, .22)},
    'light': {'hr': Baseline(86, 8), 'spo2': Baseline(97.2, .9), 'temp': Baseline(36.6, .25)},
    'active': {'hr': Baseline(110, 10), 'spo2': Baseline(97, 1), 'temp': Baseline(36.7, .3)},
  };
  // SpO₂ is read in whole percent, so its spread can't be tighter than 1 point.
  static const minSd = {'hr': 6.0, 'spo2': 1.0, 'temp': .2};
  double tau = .5, weekStartTau = .5, sqiMin = .5;
  int labels = 0;
  final Map<String, Bucket> buckets = {};
  final List<HealthAlert> alerts = [];
  final List<HeldEvent> held = [];
  final List<WindowRecord> history = [];
  final Map<String, int> cnt = {'hr': 0, 'spo2': 0, 'temp': 0};
  final Map<String, Stage> pipe = {};
  int lowSpo2 = 0, badRun = 0, lastActive = -99, fixedCount = 0, lastFixed = -99, sentCount = 0, _nextId = 1;
  Reading? _prev;
  _Episode? _ep;

  /// ok | watch | held | alert | band
  String status = 'ok';

  bool isNight(int t) {
    final h = (t ~/ 60) % 24;
    return h < 6 || h >= 22;
  }

  double computeSqi(Reading r, Reading? prev) {
    var q = r.contact;
    if (r.hr < 30 || r.hr > 220 || r.spo2 < 70 || r.spo2 > 100 || r.temp < 30 || r.temp > 43) q -= .4;
    if (prev != null && (r.hr - prev.hr).abs() > 30) q -= .3;
    if (r.motion > .8) q -= .2;
    return q.clamp(0, 1).toDouble();
  }

  void _updateBaseline(String ctx, Reading r) {
    final b = base[ctx]!;
    for (final v in vitals) {
      final x = v == 'hr' ? r.hr.toDouble() : v == 'spo2' ? r.spo2.toDouble() : r.temp;
      final bl = b[v]!;
      final mu = .98 * bl.mu + .02 * x;
      bl.v = max(minSd[v]! * minSd[v]!, .98 * bl.v + .02 * (x - mu) * (x - mu));
      bl.mu = mu;
    }
  }

  static String fmtZ(double z) => '${z >= 0 ? '+' : '−'}${z.abs().toStringAsFixed(1)}';

  /// Process one reading window. Returns the stored record.
  WindowRecord process(Reading r) {
    if (t % (7 * 1440) == 0) weekStartTau = tau;
    final sqi = computeSqi(r, _prev);
    _prev = r;
    final act = r.motion < .15 ? 'rest' : r.motion < .45 ? 'light' : 'active';
    if (act != 'rest') lastActive = t;
    var ctx = act;
    if (act == 'rest' && t - lastActive <= 5) ctx = 'light';
    final actLabel = act == 'active' ? 'Active' : act == 'light' ? 'Light activity' : ctx == 'light' ? 'Cooling down' : 'Resting';
    final good = sqi >= sqiMin;
    final b = base[ctx]!;
    final mu = {for (final v in vitals) v: b[v]!.mu};
    final sd = {for (final v in vitals) v: b[v]!.sd};
    final z = {
      'hr': (r.hr - mu['hr']!) / sd['hr']!,
      'spo2': (r.spo2 - mu['spo2']!) / sd['spo2']!,
      'temp': (r.temp - mu['temp']!) / sd['temp']!,
    };
    var fixed = false;
    if ((r.hr > 100 || r.hr < 50 || r.spo2 < 94 || r.temp > 37.8) && t - lastFixed >= 10) {
      fixed = true;
      lastFixed = t;
      fixedCount++;
    }
    final rec = WindowRecord(t: t, r: r, sqi: sqi, act: actLabel, ctx: ctx, good: good, mu: mu, sd: sd, z: z, fixed: fixed);
    history.add(rec);
    if (history.length > 240) history.removeAt(0);
    pipe
      ..clear()
      ..['A'] = Stage(good ? StageState.ok : StageState.bad, 'Quality ${sqi.toStringAsFixed(2)} · ${good ? 'good, use it' : 'unreliable, ignore it'}')
      ..['B'] = Stage(StageState.ok, '$actLabel · motion ${r.motion.toStringAsFixed(2)} g');
    t++;

    if (!good) {
      badRun++;
      cnt.updateAll((_, _) => 0);
      lowSpo2 = 0;
      pipe['C'] = const Stage(StageState.idle, 'Skipped. Bad data never changes your normal');
      pipe['D'] = const Stage(StageState.idle, 'Paused until the signal is reliable');
      pipe['E'] = const Stage(StageState.idle, 'Skipped');
      pipe['F'] = const Stage(StageState.idle, 'No decision on bad data');
      pipe['G'] = const Stage(StageState.idle, '—');
      status = 'band';
      if (badRun == 4) onBadSignal?.call();
      _escalate();
      return rec;
    }
    badRun = 0;
    pipe['C'] = Stage(StageState.ok, 'z · HR ${fmtZ(z['hr']!)} · SpO₂ ${fmtZ(z['spo2']!)} · Temp ${fmtZ(z['temp']!)}');

    lowSpo2 = r.spo2 <= 91 ? lowSpo2 + 1 : 0;
    ({String v, String title, String rule})? safety;
    if (lowSpo2 >= 2) {
      safety = (v: 'spo2', title: 'Oxygen critically low', rule: 'SpO₂ ≤ 91% for 2 min');
    } else if (act == 'rest' && (r.hr >= 131 || r.hr <= 40)) {
      safety = (v: 'hr', title: r.hr >= 131 ? 'Heart rate critically high' : 'Heart rate critically low', rule: 'Resting HR ≥ 131 or ≤ 40 bpm');
    } else if (r.temp >= 39.1 || r.temp <= 35) {
      safety = (v: 'temp', title: r.temp >= 39.1 ? 'Temperature critically high' : 'Temperature critically low', rule: 'Temp ≥ 39.1 or ≤ 35.0 °C');
    }
    pipe['D'] = safety != null ? Stage(StageState.crit, 'Triggered · ${safety.rule}') : const Stage(StageState.ok, 'Clear · SpO₂ > 91%, HR 41–130, Temp 35.1–39.0 °C');

    final hard = {'hr': z['hr']! >= 2.5, 'spo2': z['spo2']! <= -2.5, 'temp': z['temp']! >= 2.5};
    for (final v in vitals) {
      cnt[v] = hard[v]! ? cnt[v]! + 1 : 0;
    }
    final soft = {'hr': z['hr']! >= 1.5, 'spo2': z['spo2']! <= -1.5, 'temp': z['temp']! >= 1.5};
    final numAbn = vitals.where((v) => soft[v]!).length;
    final maxCnt = cnt.values.reduce(max);
    final sustained = vitals.where((v) => cnt[v]! >= 3).toList();
    final candidate = safety != null || sustained.isNotEmpty || (numAbn >= 2 && maxCnt >= 2);

    if (candidate) {
      final names = (sustained.isNotEmpty ? sustained : vitals.where((v) => soft[v]!)).map((v) => vitalName[v]).join(' + ');
      pipe['E'] = Stage(StageState.warn, 'Unusual for you · ${names.isEmpty ? vitalName[safety!.v] : names}');
      _handleCandidate(rec, z, numAbn, safety, ctx);
    } else {
      final w = vitals.where((v) => cnt[v]! > 0).map((v) => vitalName[v]).join(' + ');
      pipe['E'] = maxCnt > 0 ? Stage(StageState.watch, 'Watching $w · $maxCnt of 3 min') : const Stage(StageState.ok, 'Within your normal range');
      pipe['F'] = const Stage(StageState.idle, 'No decision needed');
      pipe['G'] = const Stage(StageState.idle, '—');
      status = maxCnt > 0 ? 'watch' : 'ok';
      if (_ep != null && ++_ep!.calm >= 3) _ep = null;
      if (maxCnt == 0 && numAbn == 0 && _ep == null) _updateBaseline(ctx, r);
    }
    _escalate();
    return rec;
  }

  void _handleCandidate(WindowRecord rec, Map<String, double> z, int numAbn, ({String v, String title, String rule})? safety, String ctx) {
    final ep = _ep ??= _Episode(rec.t);
    ep.calm = 0;
    final involvedNow = vitals.where((v) => cnt[v]! >= 1).toList()..sort((a, b) => z[b]!.abs().compareTo(z[a]!.abs()));
    final lead = involvedNow.isEmpty ? 'hr' : involvedNow.first;
    final f = Features(act: ctx, primary: numAbn >= 2 ? 'multi' : lead, zHR: z['hr']!, zSpO2: z['spo2']!, zTemp: z['temp']!, numAbn: numAbn, sqi: rec.sqi, dur: cnt.values.reduce(max), night: isNight(rec.t));
    final key = safety != null ? 'SAFETY|${safety.v}' : bucketKey(f);
    if (key == ep.lastKey) {
      final sent = ep.sentLevel > 0;
      pipe['F'] = Stage(sent ? StageState.send : StageState.hold, 'Same pattern since ${hhmm(ep.start)} · decision stands');
      pipe['G'] = Stage(sent ? StageState.send : StageState.hold, sent ? 'Alert already sent' : 'Held back, still watching');
      status = sent ? 'alert' : 'held';
      if (sent) {
        rec.alert = ep.sentLevel;
      } else {
        rec.held = true;
      }
      return;
    }
    ep.lastKey = key;

    late bool send;
    late int level;
    late double p, pg, pu, w, n;
    late List<String> path;
    if (safety != null) {
      send = true;
      level = 4;
      p = pg = 1;
      pu = 0;
      w = 0;
      n = 0;
      path = ['Safety floor: ${safety.rule}'];
      pipe['F'] = const Stage(StageState.crit, 'Safety floor · sent without asking the model');
    } else {
      final g = globalTree(f);
      final q = personal(buckets[key]);
      pg = g.p;
      pu = q.pu;
      w = q.w;
      n = q.n;
      path = g.path;
      p = (1 - w) * pg + w * pu;
      send = p >= tau;
      level = p >= .8 ? 3 : (numAbn >= 2 ? 2 : 1);
      pipe['F'] = Stage(send ? StageState.send : StageState.hold, 'P(real) ${pct(p)} ${send ? '≥' : '<'} τ ${pct(tau)} · ${send ? 'send' : 'hold back'}');
    }

    final involved = safety != null ? [safety.v] : vitals.where((v) => v == 'spo2' ? z[v]! <= -1.5 : z[v]! >= 1.5).toList();
    final newVital = ep.sentLevel > 0 && involved.any((v) => !ep.vit.contains(v));
    if (send && (level > ep.sentLevel || newVital)) {
      final a = HealthAlert(
        id: _nextId++, t: rec.t, level: level, title: _title(f, safety?.title), reasons: _reasons(rec, f, safety?.rule), path: path,
        p: p, pg: pg, pu: pu, w: w, n: n, tau: tau, key: key, safety: safety != null, hr: rec.r.hr, spo2: rec.r.spo2, temp: rec.r.temp,
      );
      a.escalation.add(EscalationStep(rec.t, 'You', 'Phone notification'));
      if (level >= 2) a.escalation.add(EscalationStep(rec.t, 'Caregiver', 'Family caregiver notified'));
      a.escalation.add(EscalationStep(rec.t, 'Doctor', level >= 3 ? 'Flagged urgent for your doctor' : 'Added to doctor review'));
      if (level >= 4) a.escalation.add(EscalationStep(rec.t, 'SOS', 'Emergency contacts alerted'));
      alerts.insert(0, a);
      sentCount++;
      ep.sentLevel = max(ep.sentLevel, level);
      ep.vit.addAll(involved);
      rec.alert = level;
      pipe['G'] = Stage(StageState.send, a.reasons.first);
      status = 'alert';
      onAlert?.call(a);
    } else if (!send && ep.sentLevel == 0) {
      final h = HeldEvent(t: rec.t, key: key, p: p, tau: tau, pg: pg, pu: pu, n: n, rec: rec);
      held.insert(0, h);
      rec.held = true;
      final k = n.round();
      pipe['G'] = Stage(StageState.hold, 'Held back · matches $k past false alarm${k == 1 ? '' : 's'}');
      status = 'held';
      onHeld?.call(h);
    } else {
      pipe['G'] = const Stage(StageState.send, 'Alert already sent for this episode');
      status = 'alert';
      rec.alert = ep.sentLevel;
    }
  }

  String _title(Features f, String? safetyTitle) {
    if (safetyTitle != null) return safetyTitle;
    if (f.primary == 'multi') {
      final vs = [if (f.zHR >= 1.5) 'heart rate', if (f.zSpO2 <= -1.5) 'oxygen', if (f.zTemp >= 1.5) 'temperature'];
      if (vs.length > 1) return '${vs[0][0].toUpperCase()}${vs[0].substring(1)} and ${vs[1]} changing together';
      return 'Several vitals changing';
    }
    return const {'hr': 'Heart rate above your normal', 'spo2': 'Oxygen below your normal', 'temp': 'Temperature above your normal'}[f.primary]!;
  }

  List<String> _reasons(WindowRecord rec, Features f, String? safetyRule) {
    final out = <String>[];
    final ctxw = rec.ctx == 'rest' ? 'resting' : rec.ctx == 'light' ? 'light-activity' : 'active';
    if (safetyRule != null) out.add('Safety limit reached: $safetyRule. Learning can never switch this alert off.');
    if (f.zHR >= 1.5) {
      final pc = ((rec.r.hr / rec.mu['hr']! - 1) * 100).round();
      out.add('Heart rate ${rec.r.hr} bpm, $pc% above your usual $ctxw ${rec.mu['hr']!.round()} bpm${cnt['hr']! > 0 ? ' for ${cnt['hr']} min' : ''}${rec.ctx == 'rest' ? ', while you were still' : ''}.');
    }
    if (f.zSpO2 <= -1.5 || safetyRule?.contains('SpO') == true) out.add('Oxygen ${rec.r.spo2}%. Your usual is ${rec.mu['spo2']!.round()}%.');
    if (f.zTemp >= 1.5) out.add('Temperature ${rec.r.temp.toStringAsFixed(1)} °C. Your usual is ${rec.mu['temp']!.toStringAsFixed(1)} °C.');
    out.add('Signal quality good (${rec.sqi.toStringAsFixed(2)}), so this isn\'t a loose sensor.');
    return out;
  }

  void _escalate() {
    for (final a in alerts) {
      if (a.level == 1 && a.patientFeedback == null && !a.escalation.any((e) => e.who == 'Caregiver') && t - a.t >= 10) {
        a.escalation.add(EscalationStep(t, 'Caregiver', 'No reply in 10 min, caregiver notified'));
      }
    }
  }

  void _setContrib(HealthAlert a, double r, double f) {
    if (a.safety) return;
    final b = buckets.putIfAbsent(a.key, Bucket.new);
    b.r += r - a.contribR;
    b.f += f - a.contribF;
    a.contribR = r;
    a.contribF = f;
  }

  void _nudge(double d) => tau = nudgedTau(tau, weekStartTau, d);

  /// The wearer says what was happening. Never makes the engine less sensitive
  /// when they feel unwell or are unsure.
  void patientFeedback(HealthAlert a, PatientFeedback kind) {
    if (a.patientFeedback != null) return;
    a.patientFeedback = kind;
    labels++;
    if (a.doctor != DoctorLabel.pending) return;
    switch (kind) {
      case PatientFeedback.active:
        _setContrib(a, 0, .5);
        _nudge(.01);
      case PatientFeedback.loose:
        _setContrib(a, 0, .5);
        _nudge(.01);
        sqiMin = min(.65, sqiMin + .02);
      case PatientFeedback.unwell:
        _setContrib(a, .5, 0);
        _nudge(-.02);
        a.escalation.add(EscalationStep(t, 'Doctor', 'Priority: patient feels unwell'));
      case PatientFeedback.notSure:
        break;
    }
  }

  /// The doctor's label overrides the wearer's.
  void doctorLabel(HealthAlert a, bool real) {
    if (a.doctor != DoctorLabel.pending) return;
    a.doctor = real ? DoctorLabel.confirmed : DoctorLabel.rejected;
    labels++;
    _setContrib(a, real ? 1 : 0, real ? 0 : 1);
    if (!a.safety) _nudge(real ? -.05 : .03);
  }

  /// Current blended probability for a learned pattern.
  double bucketP(String key) {
    final q = personal(buckets[key]);
    return (1 - q.w) * globalTree(featuresFromKey(key)).p + q.w * q.pu;
  }

  WindowRecord? get last => history.isEmpty ? null : history.last;
}

String pct(double x) => '${(x * 100).round()}%';

String hhmm(int t) {
  final h = (t ~/ 60) % 24, m = t % 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}
