import 'dart:math';

import 'adapt_alert.dart';

/// Simulated studies of alert systems on the same virtual patients.
///
/// Systems compared on identical event streams:
///   A  Fixed thresholds: HR > 100, SpO₂ < 94, Temp > 37.8, no quality check
///   B  Personal normal + signal-quality check, no learning (τ fixed at 0.5)
///   C  AdaptAlert: B plus feedback learning and the safety floor
///   D  Unguarded learning (ablation): no safety floor, τ free between 0.05 and
///      0.95 with no weekly limit, so feedback alone decides
///   E  AdaptAlert with a federated prior: new patients start from pattern
///      statistics pooled from earlier patients (counts only, no raw vitals)
///
/// The event mix and rates are modelling assumptions, listed in docs/RESEARCH.md.
class StudyConfig {
  const StudyConfig({
    this.patients = 40,
    this.days = 30,
    this.seed = 7,
    this.labelRate = .9,
    this.labelNoise = 0,
    this.dismissRate = 0,
    this.k = 4,
    this.rejectStep = .03,
    this.confirmStep = .05,
    this.realEventRate = .12,
  });

  final int patients, days, seed;

  /// Share of sent alerts that a clinician labels.
  final double labelRate;

  /// Chance that a label is wrong (real called false, or false called real).
  final double labelNoise;

  /// Chance that a real alert is dismissed as a false alarm: alarm fatigue,
  /// the failure that makes learning from feedback dangerous.
  final double dismissRate;

  /// Personal weight constant: w = n / (n + k).
  final double k;
  final double rejectStep, confirmStep;

  /// Real deteriorations per patient per day.
  final double realEventRate;

  StudyConfig copyWith({int? patients, int? days, int? seed, double? labelRate, double? labelNoise, double? dismissRate, double? k, double? realEventRate}) => StudyConfig(
        patients: patients ?? this.patients,
        days: days ?? this.days,
        seed: seed ?? this.seed,
        labelRate: labelRate ?? this.labelRate,
        labelNoise: labelNoise ?? this.labelNoise,
        dismissRate: dismissRate ?? this.dismissRate,
        k: k ?? this.k,
        rejectStep: rejectStep,
        confirmStep: confirmStep,
        realEventRate: realEventRate ?? this.realEventRate,
      );
}

const systemNames = {
  'A': 'Fixed threshold',
  'B': 'Personal normal',
  'C': 'AdaptAlert',
  'D': 'Unguarded learning (ablation)',
  'E': 'AdaptAlert + federated prior',
};

class Interval {
  const Interval(this.lo, this.hi);
  final double lo, hi;
}

class SystemMetrics {
  SystemMetrics({required this.falsePerDay, required this.falsePerDayWeek1, required this.falsePerDayLastWeek, required this.sensitivity, required this.criticalCaught, required this.ppv, required this.alertsPerDay, required this.falseLastWeekCI, required this.sensitivityCI});
  final double falsePerDay, falsePerDayWeek1, falsePerDayLastWeek, sensitivity, ppv, alertsPerDay;

  /// Share of critical (safety-floor level) events that were alerted.
  final double criticalCaught;
  final Interval falseLastWeekCI, sensitivityCI;

  // Names kept for the screens and tests written against the first study.
  double get falsePerDayWeek5 => falsePerDayLastWeek;
}

class ExperimentResult {
  ExperimentResult(this.config, this.realEvents, this.safetyEvents, this.series, this.metrics);
  final StudyConfig config;
  final int realEvents, safetyEvents;

  /// False alarms per patient for each day, per system.
  final Map<String, List<double>> series;
  final Map<String, SystemMetrics> metrics;

  int get days => config.days;
  int get patients => config.patients;

  /// Percent fewer false alarms than the fixed-threshold monitor in the last week.
  double reduction(String s) => metrics['A']!.falsePerDayLastWeek == 0 ? 0 : 1 - metrics[s]!.falsePerDayLastWeek / metrics['A']!.falsePerDayLastWeek;
}

typedef StudyResult = ExperimentResult;
typedef StudyMetrics = SystemMetrics;

/// The first study's call, kept for existing screens and tests.
ExperimentResult runStudy({int seed = 7, int patients = 40, int days = 30}) => runExperiment(StudyConfig(seed: seed, patients: patients, days: days));

class _Ev {
  _Ev({this.fixed = false, this.real = false, this.safety = false, this.f, this.safetyAsFeature});
  final bool fixed, real, safety;
  final Features? f;

  /// How the safety event looks to a model that has no safety floor (system D).
  final Features? safetyAsFeature;
}

class _Learner {
  _Learner(this.cfg, this.safetyFloor, {Map<String, Bucket>? prior, this.guarded = true}) : prior = prior ?? {};
  final StudyConfig cfg;
  final bool safetyFloor, guarded;
  final Map<String, Bucket> prior;
  final Map<String, Bucket> own = {};
  double tau = .5, wk = .5;

  Bucket? _bucket(String key) {
    final p = prior[key], o = own[key];
    if (p == null) return o;
    return Bucket()
      ..r = p.r + (o?.r ?? 0)
      ..f = p.f + (o?.f ?? 0);
  }

  /// Decides, then learns from a (possibly wrong) clinician label.
  bool decide(_Ev e, Random r) {
    Features? f = e.f;
    if (e.safety) {
      if (safetyFloor) return true;
      f = e.safetyAsFeature;
    }
    if (f == null) return false;
    final key = bucketKey(f);
    final q = personal(_bucket(key), k: cfg.k);
    final p = (1 - q.w) * globalTree(f).p + q.w * q.pu;
    final sent = p >= tau;
    if (sent && r.nextDouble() < cfg.labelRate) {
      var saysReal = r.nextDouble() < cfg.labelNoise ? !e.real : e.real;
      if (e.real && r.nextDouble() < cfg.dismissRate) saysReal = false;
      final b = own.putIfAbsent(key, Bucket.new);
      if (saysReal) {
        b.r++;
        _move(-cfg.confirmStep);
      } else {
        b.f++;
        _move(cfg.rejectStep);
      }
    }
    return sent;
  }
}

extension on _Learner {
  void _move(double d) => tau = guarded ? nudgedTau(tau, wk, d) : (tau + d).clamp(.05, .95).toDouble();
}

ExperimentResult runExperiment(StudyConfig cfg) {
  final r = Random(cfg.seed);
  final days = cfg.days, n = cfg.patients;
  int pois(double l) {
    final lim = exp(-l);
    var k = 0;
    var p = 1.0;
    do {
      k++;
      p *= r.nextDouble();
    } while (p > lim);
    return k - 1;
  }

  const systems = ['A', 'B', 'C', 'D', 'E'];
  final fa = {for (final s in systems) s: List<double>.filled(days, 0)};
  final faLastWeekByPatient = {for (final s in systems) s: List<double>.filled(n, 0)};
  final caughtByPatient = {for (final s in systems) s: List<int>.filled(n, 0)};
  final realByPatient = List<int>.filled(n, 0);
  final alerted = {for (final s in systems) s: 0};
  final criticalHit = {for (final s in systems) s: 0};
  var real = 0, safetyEvents = 0;
  final pool = <String, Bucket>{}; // federated: label counts pooled across finished patients

  for (var i = 0; i < n; i++) {
    final c = _Learner(cfg, true), d = _Learner(cfg, false, guarded: false);
    final prior = <String, Bucket>{};
    pool.forEach((key, b) {
      final total = b.r + b.f;
      final n0 = min(3.0, total); // shrink the pooled evidence to at most 3 labels
      prior[key] = Bucket()
        ..r = n0 * (b.r + 1) / (total + 2)
        ..f = n0 * (b.f + 1) / (total + 2);
    });
    final e = _Learner(cfg, true, prior: prior);

    for (var day = 0; day < days; day++) {
      if (day % 7 == 0) {
        for (final l in [c, d, e]) {
          l.wk = l.tau;
        }
      }
      final ev = <_Ev>[];
      for (var k = pois(2); k > 0; k--) {
        ev.add(_Ev(fixed: true)); // exercise
      }
      for (var k = pois(1.5); k > 0; k--) {
        ev.add(_Ev(fixed: r.nextDouble() < .7)); // loose sensor
      }
      for (var k = pois(1.2); k > 0; k--) {
        ev.add(_Ev(fixed: r.nextDouble() < .3, f: Features(act: 'rest', primary: 'hr', zHR: 2.6 + r.nextDouble() * 2.2, zSpO2: -.3, zTemp: .1, numAbn: 1, night: r.nextDouble() < .15))); // coffee, stress
      }
      if (r.nextDouble() < .5) {
        ev.add(_Ev(fixed: r.nextDouble() < .6, f: Features(act: 'rest', primary: 'spo2', zHR: .2, zSpO2: -(2.6 + r.nextDouble() * .8), zTemp: 0, numAbn: 1, night: true))); // sleep dip
      }
      if (r.nextDouble() < cfg.realEventRate) {
        final ty = r.nextDouble();
        if (ty < .3) {
          ev.add(_Ev(real: true, fixed: true, f: Features(act: 'rest', primary: 'multi', zHR: 5 + r.nextDouble() * 3, zSpO2: -(2.5 + r.nextDouble()), zTemp: .3, numAbn: 2, night: r.nextDouble() < .3)));
        } else if (ty < .55) {
          ev.add(_Ev(real: true, fixed: true, f: Features(act: 'rest', primary: 'multi', zHR: 2 + r.nextDouble() * 2, zSpO2: -.5, zTemp: 4 + r.nextDouble() * 3, numAbn: 2, night: r.nextDouble() < .3)));
        } else if (ty < .75) {
          safetyEvents++;
          ev.add(_Ev(real: true, fixed: true, safety: true, safetyAsFeature: Features(act: 'rest', primary: 'spo2', zHR: 1, zSpO2: -(6 + r.nextDouble() * 2), zTemp: 0, numAbn: 1, night: r.nextDouble() < .3)));
        } else {
          ev.add(_Ev(real: true, fixed: r.nextDouble() < .6, f: Features(act: 'rest', primary: 'spo2', zHR: .8, zSpO2: -(2.8 + r.nextDouble() * .6), zTemp: 0, numAbn: 1)));
        }
      }
      for (final x in ev) {
        if (x.real) {
          real++;
          realByPatient[i]++;
        }
        void hit(String s, bool sent) {
          if (!sent) return;
          alerted[s] = alerted[s]! + 1;
          if (x.real) {
            caughtByPatient[s]![i]++;
            if (x.safety) criticalHit[s] = criticalHit[s]! + 1;
          } else {
            fa[s]![day] += 1;
            if (day >= days - 7) faLastWeekByPatient[s]![i] += 1 / 7;
          }
        }

        hit('A', x.fixed);
        hit('B', x.safety || (x.f != null && globalTree(x.f!).p >= .5));
        hit('C', c.decide(x, r));
        hit('D', d.decide(x, r));
        hit('E', e.decide(x, r));
      }
    }
    // Federated step: share only this patient's own label counts.
    e.own.forEach((key, b) {
      final p = pool.putIfAbsent(key, Bucket.new);
      p.r += b.r;
      p.f += b.f;
    });
  }

  // Bootstrap over patients for 95% intervals.
  final boot = Random(cfg.seed + 99);
  Interval ci(List<double> Function(List<int> idx) stat) {
    final vals = <double>[];
    for (var b = 0; b < 400; b++) {
      final idx = List.generate(n, (_) => boot.nextInt(n));
      vals.addAll(stat(idx));
    }
    vals.sort();
    return Interval(vals[(vals.length * .025).floor()], vals[min(vals.length - 1, (vals.length * .975).floor())]);
  }

  double avg(List<double> xs) => xs.fold(0.0, (a, b) => a + b) / (n * xs.length);
  final metrics = <String, SystemMetrics>{};
  for (final s in systems) {
    final caught = caughtByPatient[s]!.fold(0, (a, b) => a + b);
    metrics[s] = SystemMetrics(
      falsePerDay: avg(fa[s]!),
      falsePerDayWeek1: avg(fa[s]!.sublist(0, min(7, days))),
      falsePerDayLastWeek: avg(fa[s]!.sublist(max(0, days - 7))),
      sensitivity: real == 0 ? 1 : caught / real,
      criticalCaught: safetyEvents == 0 ? 1 : criticalHit[s]! / safetyEvents,
      ppv: alerted[s] == 0 ? 0 : caught / alerted[s]!,
      alertsPerDay: alerted[s]! / (n * days),
      falseLastWeekCI: ci((idx) => [idx.fold(0.0, (a, i) => a + faLastWeekByPatient[s]![i]) / n]),
      sensitivityCI: ci((idx) {
        final rr = idx.fold(0, (a, i) => a + realByPatient[i]), cc = idx.fold(0, (a, i) => a + caughtByPatient[s]![i]);
        return [rr == 0 ? 1.0 : cc / rr];
      }),
    );
  }
  return ExperimentResult(cfg, real, safetyEvents, {for (final s in systems) s: fa[s]!.map((v) => v / n).toList()}, metrics);
}

/// What happens as feedback gets worse: at each level, a share of real alerts
/// is dismissed as a false alarm (alarm fatigue). Averaged over [seeds] runs.
class NoisePoint {
  NoisePoint(this.noise, this.sensC, this.sensD, this.critC, this.critD, this.falseC);
  final double noise, sensC, sensD, critC, critD, falseC;
}

List<NoisePoint> noiseSweep(StudyConfig cfg, {List<double> levels = const [0, .1, .2, .3, .5], int seeds = 5}) => [
      for (final lv in levels)
        () {
          var sc = 0.0, sd = 0.0, cc = 0.0, cd = 0.0, fc = 0.0;
          for (var k = 0; k < seeds; k++) {
            final r = runExperiment(cfg.copyWith(dismissRate: lv, seed: cfg.seed + k * 1000));
            sc += r.metrics['C']!.sensitivity;
            sd += r.metrics['D']!.sensitivity;
            cc += r.metrics['C']!.criticalCaught;
            cd += r.metrics['D']!.criticalCaught;
            fc += r.metrics['C']!.falsePerDayLastWeek;
          }
          return NoisePoint(lv, sc / seeds, sd / seeds, cc / seeds, cd / seeds, fc / seeds);
        }(),
    ];

/// The results as Markdown tables, ready to paste into a paper draft.
String resultsMarkdown(ExperimentResult r, {List<NoisePoint>? noise}) {
  final c = r.config;
  String f2(double x) => x.toStringAsFixed(2);
  String p(double x) => '${(x * 100).toStringAsFixed(1)}%';
  final b = StringBuffer()
    ..writeln('Simulated study: ${c.patients} patients × ${c.days} days, seed ${c.seed}, label rate ${p(c.labelRate)}, label noise ${p(c.labelNoise)}, real alerts dismissed ${p(c.dismissRate)}, k = ${c.k}.')
    ..writeln('${r.realEvents} real events (${r.safetyEvents} reached the safety floor).')
    ..writeln()
    ..writeln('| System | False alarms/patient/day, week 1 | Last week (95% CI) | Sensitivity (95% CI) | Critical caught | PPV | Alerts/patient/day |')
    ..writeln('|---|---|---|---|---|---|---|');
  for (final s in systemNames.keys) {
    final m = r.metrics[s]!;
    b.writeln('| ${systemNames[s]} | ${f2(m.falsePerDayWeek1)} | ${f2(m.falsePerDayLastWeek)} (${f2(m.falseLastWeekCI.lo)}–${f2(m.falseLastWeekCI.hi)}) | ${p(m.sensitivity)} (${p(m.sensitivityCI.lo)}–${p(m.sensitivityCI.hi)}) | ${p(m.criticalCaught)} | ${p(m.ppv)} | ${f2(m.alertsPerDay)} |');
  }
  b
    ..writeln()
    ..writeln('False-alarm reduction vs fixed threshold, last week: AdaptAlert ${p(r.reduction('C'))}, with federated prior ${p(r.reduction('E'))}.');
  if (noise != null) {
    b
      ..writeln()
      ..writeln('Alarm fatigue: share of real alerts dismissed as false alarms (mean of 5 seeds).')
      ..writeln()
      ..writeln('| Real alerts dismissed | Sensitivity, AdaptAlert | Sensitivity, unguarded | Critical caught, AdaptAlert | Critical caught, unguarded | False alarms/day, AdaptAlert |')
      ..writeln('|---|---|---|---|---|---|');
    for (final n in noise) {
      b.writeln('| ${p(n.noise)} | ${p(n.sensC)} | ${p(n.sensD)} | ${p(n.critC)} | ${p(n.critD)} | ${f2(n.falseC)} |');
    }
  }
  return b.toString();
}
