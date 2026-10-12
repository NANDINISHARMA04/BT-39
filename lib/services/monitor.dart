import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/adapt_alert.dart';
import '../engine/simulator.dart';
import '../l10n/l10n.dart';

/// Runs the wearer's band and the AdaptAlert engine.
///
/// The band is simulated: one reading window per real second, standing in for
/// one minute of wear. Replace [BandSimulator] with a BLE source to use a real
/// ESP32 band (see README).
class MonitorController extends ChangeNotifier {
  MonitorController() {
    // Engine text (alert titles, reasons, pipeline steps) follows the app language.
    engineTr = tr;
    engine = AdaptAlertEngine(
      onAlert: (a) {
        if (!_silent) alertEvents.value = a;
      },
      onHeld: (h) {
        if (!_silent) heldEvents.value = h;
      },
      onBadSignal: () {
        if (!_silent) badSignal.value++;
      },
    );
    _warmup();
  }

  late final AdaptAlertEngine engine;
  final BandSimulator band = BandSimulator();
  Timer? _timer;
  bool _silent = true;
  bool paused = false;
  bool fast = false;

  /// UI listens to these for banners, toasts and auto-SOS.
  final ValueNotifier<HealthAlert?> alertEvents = ValueNotifier(null);
  final ValueNotifier<HeldEvent?> heldEvents = ValueNotifier(null);
  final ValueNotifier<int> badSignal = ValueNotifier(0);
  final ValueNotifier<String?> scenarioEnded = ValueNotifier(null);

  WindowRecord? get last => engine.last;
  String get scenarioId => band.scenario.id;
  int get scenarioMinutesLeft => band.minutesLeft;

  /// A morning of history so every screen opens with real-looking data,
  /// including one coffee-related alert the doctor already marked false.
  void _warmup() {
    const plan = [('rest', 38), ('walk', 12), ('rest', 24), ('stress', 11), ('rest', 22), ('loose', 6), ('rest', 20)];
    for (final (id, n) in plan) {
      band.start(id);
      band.minutesLeft = 999;
      for (var i = 0; i < n; i++) {
        engine.process(band.next());
        final a = engine.alerts.isEmpty ? null : engine.alerts.first;
        if (a != null && a.doctor == DoctorLabel.pending && engine.t - a.t >= 3) {
          engine.patientFeedback(a, PatientFeedback.notSure);
          engine.doctorLabel(a, false);
        }
      }
    }
    band.start('rest');
    _silent = false;
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: fast ? 250 : 1000), (_) => tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void tick() {
    if (paused) return;
    engine.process(band.next());
    if (band.advance()) scenarioEnded.value = band.scenario.id;
    notifyListeners();
  }

  void runScenario(String id) {
    band.start(id);
    notifyListeners();
  }

  void setPaused(bool v) {
    paused = v;
    notifyListeners();
  }

  void setFast(bool v) {
    fast = v;
    if (_timer != null) start();
    notifyListeners();
  }

  void feedback(HealthAlert a, PatientFeedback f) {
    engine.patientFeedback(a, f);
    notifyListeners();
  }

  void doctorLabel(HealthAlert a, bool real, {String? by}) {
    engine.doctorLabel(a, real, by: by);
    notifyListeners();
  }

  int get needsReply => engine.alerts.where((a) => a.patientFeedback == null).length;

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
