import 'package:bt39_care/services/monitor.dart';
import 'package:bt39_care/services/tour.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guided demo walks through the whole story', () async {
    final m = MonitorController();
    final tabs = <int>[];
    final tour = TourController(m, tabs.add);
    // Drive the band from the test, at a pace close to the app's fast mode,
    // so the simulated clock stays in daytime as it does in the real demo.
    var ticking = true;
    Future<void> ticker() async {
      while (ticking) {
        m.tick();
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }

    final t = ticker();
    await tour.start().timeout(const Duration(minutes: 3));
    ticking = false;
    await t;

    final e = m.engine;
    expect(tour.index, TourController.totalSteps);
    expect(tour.step?.last, isTrue, reason: 'ends by asking to log in');
    expect(e.held, isNotEmpty, reason: 'second coffee is held back');
    expect(e.alerts.any((a) => a.safety && a.level == 4), isTrue, reason: 'safety floor fires');
    expect(e.alerts.any((a) => a.key == 'rest|multi|multi|day'), isTrue, reason: 'real event alerts');
    expect(tabs, containsAll([0, 1, 2]));
    m.dispose();
  }, timeout: const Timeout(Duration(minutes: 4)));
}
