import 'package:bt39_care/engine/adapt_alert.dart';
import 'package:bt39_care/engine/simulator.dart';
import 'package:bt39_care/engine/study.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs [n] windows of a scenario through the engine.
void run(AdaptAlertEngine e, BandSimulator band, String id, int n) {
  band.start(id);
  band.minutesLeft = 999;
  for (var i = 0; i < n; i++) {
    e.process(band.next());
  }
}

void main() {
  test('a mild heart-rate rise at rest is sent first, then held back after the doctor rejects it', () {
    final e = AdaptAlertEngine();
    final band = BandSimulator(seed: 1);
    run(e, band, 'rest', 40);
    run(e, band, 'stress', 11);
    expect(e.alerts, hasLength(1));
    final first = e.alerts.first;
    expect(first.key, 'rest|hr|mod|day');
    e.doctorLabel(first, false);

    run(e, band, 'rest', 25);
    run(e, band, 'stress', 11);
    // Two false labels for the same pattern pull it below the threshold.
    e.doctorLabel(e.alerts.first, false);
    run(e, band, 'rest', 25);
    run(e, band, 'stress', 11);
    expect(e.held, isNotEmpty);
    expect(e.held.first.key, 'rest|hr|mod|day');
    expect(e.held.first.p, lessThan(e.held.first.tau));
  });

  test('walking raises heart rate without an alert, while the fixed monitor alarms', () {
    final e = AdaptAlertEngine();
    final band = BandSimulator(seed: 2);
    run(e, band, 'rest', 30);
    run(e, band, 'walk', 12);
    run(e, band, 'rest', 15);
    expect(e.alerts, isEmpty);
    expect(e.fixedCount, greaterThan(0));
  });

  test('a loose band never causes an alert', () {
    final e = AdaptAlertEngine();
    final band = BandSimulator(seed: 3);
    run(e, band, 'rest', 30);
    run(e, band, 'loose', 10);
    expect(e.alerts, isEmpty);
    expect(e.status, 'band');
  });

  test('the safety floor alerts even when the threshold is at its maximum', () {
    final e = AdaptAlertEngine()..tau = tauMax;
    final band = BandSimulator(seed: 4);
    run(e, band, 'rest', 30);
    run(e, band, 'hypoxia', 10);
    expect(e.alerts.any((a) => a.safety && a.level == 4), isTrue);
  });

  test('threshold moves at most 10 points a week and stays within bounds', () {
    var tau = .5;
    for (var i = 0; i < 20; i++) {
      tau = nudgedTau(tau, .5, .03);
    }
    expect(tau, closeTo(.6, 1e-9));
    expect(nudgedTau(.31, .31, -.5), tauMin);
  });

  test('30-day study: AdaptAlert cuts false alarms and keeps sensitivity', () {
    final r = runStudy(seed: 7);
    final a = r.metrics['A']!, c = r.metrics['C']!;
    expect(c.falsePerDayWeek5, lessThan(a.falsePerDayWeek5 * .2));
    expect(c.sensitivity, greaterThanOrEqualTo(.95));
  });
}
