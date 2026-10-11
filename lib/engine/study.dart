import 'dart:math';

import 'adapt_alert.dart';

/// A simulated 30-day comparison of three systems on the same virtual patients:
///   A fixed thresholds (HR > 100, SpO₂ < 94, Temp > 37.8, no quality check)
///   B personal normal + quality check, no learning (τ fixed at 0.5)
///   C AdaptAlert (B plus feedback learning)
/// The event mix and rates are assumptions, stated in the README.
class StudyMetrics {
  StudyMetrics(this.falsePerDayWeek1, this.falsePerDayWeek5, this.sensitivity, this.ppv);
  final double falsePerDayWeek1, falsePerDayWeek5, sensitivity, ppv;
}

class StudyResult {
  StudyResult(this.days, this.patients, this.realEvents, this.series, this.metrics);
  final int days, patients, realEvents;
  final Map<String, List<double>> series;
  final Map<String, StudyMetrics> metrics;
}

class _Ev {
  _Ev({this.fixed = false, this.real = false, this.safety = false, this.f});
  final bool fixed, real, safety;
  final Features? f;
}

StudyResult runStudy({int seed = 7, int patients = 40, int days = 30}) {
  final r = Random(seed);
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

  final fa = {for (final s in ['A', 'B', 'C']) s: List<double>.filled(days, 0)};
  final alerted = {'A': 0, 'B': 0, 'C': 0};
  final caught = {'A': 0, 'B': 0, 'C': 0};
  var real = 0;

  for (var i = 0; i < patients; i++) {
    var tau = .5, wk = .5;
    final buckets = <String, Bucket>{};
    for (var d = 0; d < days; d++) {
      if (d % 7 == 0) wk = tau;
      final ev = <_Ev>[];
      for (var k = pois(2); k > 0; k--) {
        ev.add(_Ev(fixed: true)); // exercise
      }
      for (var k = pois(1.5); k > 0; k--) {
        ev.add(_Ev(fixed: r.nextDouble() < .7)); // loose sensor
      }
      for (var k = pois(1.2); k > 0; k--) {
        ev.add(_Ev(fixed: r.nextDouble() < .3, f: Features(act: 'rest', primary: 'hr', zHR: 2.6 + r.nextDouble() * 2.2, zSpO2: -.3, zTemp: .1, numAbn: 1, night: r.nextDouble() < .15)));
      }
      if (r.nextDouble() < .5) {
        ev.add(_Ev(fixed: r.nextDouble() < .6, f: Features(act: 'rest', primary: 'spo2', zHR: .2, zSpO2: -(2.6 + r.nextDouble() * .8), zTemp: 0, numAbn: 1, night: true)));
      }
      if (r.nextDouble() < .12) {
        final ty = r.nextDouble();
        if (ty < .3) {
          ev.add(_Ev(real: true, fixed: true, f: Features(act: 'rest', primary: 'multi', zHR: 5 + r.nextDouble() * 3, zSpO2: -(2.5 + r.nextDouble()), zTemp: .3, numAbn: 2, night: r.nextDouble() < .3)));
        } else if (ty < .55) {
          ev.add(_Ev(real: true, fixed: true, f: Features(act: 'rest', primary: 'multi', zHR: 2 + r.nextDouble() * 2, zSpO2: -.5, zTemp: 4 + r.nextDouble() * 3, numAbn: 2, night: r.nextDouble() < .3)));
        } else if (ty < .75) {
          ev.add(_Ev(real: true, fixed: true, safety: true));
        } else {
          ev.add(_Ev(real: true, fixed: r.nextDouble() < .6, f: Features(act: 'rest', primary: 'spo2', zHR: .8, zSpO2: -(2.8 + r.nextDouble() * .6), zTemp: 0, numAbn: 1)));
        }
      }
      for (final e in ev) {
        if (e.real) real++;
        void hit(String s, bool sent) {
          if (!sent) return;
          alerted[s] = alerted[s]! + 1;
          if (e.real) {
            caught[s] = caught[s]! + 1;
          } else {
            fa[s]![d] += 1;
          }
        }

        hit('A', e.fixed);
        hit('B', e.safety || (e.f != null && globalTree(e.f!).p >= .5));
        var sent = false;
        if (e.safety) {
          sent = true;
        } else if (e.f != null) {
          final key = bucketKey(e.f!);
          final q = personal(buckets[key]);
          final p = (1 - q.w) * globalTree(e.f!).p + q.w * q.pu;
          sent = p >= tau;
          if (sent && r.nextDouble() < .9) {
            final b = buckets.putIfAbsent(key, Bucket.new);
            if (e.real) {
              b.r++;
              tau = nudgedTau(tau, wk, -.05);
            } else {
              b.f++;
              tau = nudgedTau(tau, wk, .03);
            }
          }
        }
        hit('C', sent);
      }
    }
  }

  double avg(List<double> xs) => xs.fold(0.0, (a, b) => a + b) / (patients * xs.length);
  return StudyResult(
    days,
    patients,
    real,
    {for (final s in fa.keys) s: fa[s]!.map((v) => v / patients).toList()},
    {
      for (final s in fa.keys)
        s: StudyMetrics(avg(fa[s]!.sublist(0, 7)), avg(fa[s]!.sublist(days - 7)), real == 0 ? 1 : caught[s]! / real, alerted[s] == 0 ? 0 : caught[s]! / alerted[s]!),
    },
  );
}
