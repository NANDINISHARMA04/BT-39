import 'package:bt39_care/engine/adapt_alert.dart';
import 'package:bt39_care/services/monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('warm-up leaves one rejected heart-rate alert, then coffee is sent once and held after a reject', () {
    final m = MonitorController();
    final e = m.engine;
    expect(e.alerts, hasLength(1));
    expect(e.alerts.first.key, 'rest|hr|mod|day');
    expect(e.alerts.first.doctor, DoctorLabel.rejected);

    void minutes(int n) {
      for (var i = 0; i < n; i++) {
        m.tick();
      }
    }

    m.runScenario('stress');
    minutes(14);
    expect(e.alerts, hasLength(2), reason: 'first live coffee episode is still sent');
    m.doctorLabel(e.alerts.first, false);
    minutes(10);
    m.runScenario('stress');
    minutes(14);
    expect(e.alerts, hasLength(2), reason: 'second episode is held back');
    expect(e.held, isNotEmpty);

    m.runScenario('tachy');
    minutes(8);
    expect(e.alerts.first.key, 'rest|multi|multi|day');
    expect(e.alerts.first.n, 0, reason: 'a real event is not discounted by unrelated feedback');
    m.dispose();
  });
}
