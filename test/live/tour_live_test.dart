// The guided demo, end to end, against a running PulseOS service (the band and
// AdaptAlert run there now). Skipped unless PULSE_API names the service:
//
//   PULSE_API=http://localhost:8000/v1/pulse flutter test test/live
//
// It starts a fresh Demo Mode visit, plays the whole tour through the app's own
// TourController and MonitorController, and checks the story the voice-over
// tells: the walk raises no alert, coffee alerts and is labelled false, the
// second coffee is held back, the racing heart alerts, the safety floor fires.
import 'dart:io';

import 'package:bt39_care/services/monitor.dart';
import 'package:bt39_care/services/pulse_api.dart';
import 'package:bt39_care/services/tour.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = Platform.environment['PULSE_API'];
  // Flutter's test binding answers every HTTP request with a 400; this test talks to a real service.
  setUpAll(() => HttpOverrides.global = null);

  test('guided demo walks through the whole story on the service', () async {
    final start = await PulseApi(token: () async => null, base: base).postPublic('/demo/start', {'role': 'patient'});
    expect(start.ok, isTrue, reason: start.message);
    final token = start.map['token'] as String;
    final api = PulseApi(token: () async => token, base: base);
    final m = MonitorController(api: api)..start();
    final ready = Stopwatch()..start();
    while (!m.ready && ready.elapsed < const Duration(seconds: 90)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(m.ready, isTrue, reason: 'the first snapshot arrives');
    final morning = m.engine.alerts.length;

    final tabs = <int>[];
    final tour = TourController(m, tabs.add);
    await tour.start().timeout(const Duration(minutes: 5));

    final e = m.engine;
    expect(tour.index, TourController.totalSteps);
    expect(tour.step?.last, isTrue, reason: 'ends by asking to log in');
    expect(e.held, isNotEmpty, reason: 'second coffee is held back');
    expect(e.alerts.any((a) => a.safety && a.level == 4), isTrue, reason: 'safety floor fires');
    expect(e.alerts.any((a) => a.key == 'rest|multi|multi|day'), isTrue, reason: 'real event alerts');
    expect(e.alerts.length, greaterThan(morning), reason: 'the tour made alerts of its own');
    expect(e.alerts.any((a) => a.reviewedBy == 'Dr. Kavya Rao'), isTrue, reason: 'the doctor labelled the coffee alert');
    expect(tabs, containsAll([0, 1, 2]));
    expect(m.fast, isFalse, reason: 'fast forward is switched off again at the end');
    expect(m.scenarioId, 'rest');
    m.dispose();
    await api.post('/demo/end');
  }, skip: base == null ? 'set PULSE_API to a running PulseOS service' : null, timeout: const Timeout(Duration(minutes: 7)));
}
