import 'dart:async';

import 'package:flutter/foundation.dart';

import 'monitor.dart';
import 'narrator.dart';

class TourStep {
  const TourStep(this.title, this.body, {this.tab, this.last = false});
  final String title, body;

  /// The final step, which asks the person to log in or sign up.
  final bool last;

  /// Patient tab to show during this step (see PatientTab).
  final int? tab;
}

/// A guided demo that drives the simulated band through the project's story,
/// with a caption for each step, read aloud in the browser. About 2 minutes.
class TourController extends ChangeNotifier {
  TourController(this.m, this.showTab);
  final MonitorController m;
  final void Function(int tab) showTab;

  bool running = false;
  int index = 0;
  TourStep? step;
  bool _cancel = false;

  static const totalSteps = 11;

  final narrator = Narrator.instance;

  void _show(TourStep s) {
    step = s;
    if (s.tab != null) showTab(s.tab!);
    notifyListeners();
  }

  Future<void> _wait(int ms) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (!_cancel && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Waits until [done] is true or [minutes] simulated minutes have passed.
  Future<void> _until(bool Function() done, {int minutes = 30}) async {
    final start = m.engine.t;
    while (!_cancel && !done() && m.engine.t - start < minutes) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _minutes(int n) => _until(() => false, minutes: n);

  Future<void> start() async {
    if (running) return;
    running = true;
    _cancel = false;
    index = 0;
    final wasFast = m.fast;
    m.setPaused(false);
    m.setFast(true);
    try {
      await _run();
    } finally {
      m.setFast(wasFast);
      m.runScenario('rest');
      running = false;
      if (_cancel) step = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cancel = true;
    narrator.stop();
    super.dispose();
  }

  void stop() {
    _cancel = true;
    narrator.stop();
    step = null;
    notifyListeners();
  }

  void finish() {
    narrator.stop();
    step = null;
    notifyListeners();
  }

  /// Lets the narrator finish the last step before moving on. Gives up after
  /// about as long as the words take to say, in case a browser never reports
  /// the end of speech.
  Future<void> _speechDone() async {
    final words = step == null ? 0 : '${step!.title} ${step!.body}'.split(' ').length;
    final end = DateTime.now().add(Duration(milliseconds: 1500 + words * 420));
    while (!_cancel && narrator.speaking && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _next(TourStep s) async {
    await _speechDone();
    if (_cancel) return;
    index++;
    _show(s);
    narrator.say('${s.title}. ${s.body}');
  }

  void toggleMute() {
    narrator.setMuted(!narrator.muted);
    notifyListeners();
  }

  Future<void> _run() async {
    final e = m.engine;
    await _next(const TourStep('Meet Nandini', 'Nandini Sharma is recovering at home after heart valve surgery. Her wrist band sends heart rate, oxygen, temperature and movement every minute.', tab: 0));
    await _wait(5000);

    await _next(const TourStep('She goes for a walk', 'Her heart rate climbs past 100. A fixed-threshold monitor would alarm now. AdaptAlert sees she is moving and stays quiet.', tab: 0));
    m.runScenario('walk');
    await _until(() => m.scenarioId == 'rest', minutes: 20);
    await _minutes(6);

    await _next(const TourStep('The band slips', 'Readings jump all over the place. The signal-quality check marks them unreliable, so they can\'t cause an alarm or change her normal.', tab: 0));
    m.runScenario('loose');
    await _until(() => m.scenarioId == 'rest', minutes: 12);
    await _minutes(6);

    await _next(const TourStep('Coffee, sitting down', 'Her heart rate rises for several minutes while she rests. AdaptAlert isn\'t sure it matters, so it sends an alert and says exactly why.', tab: 0));
    final before = e.alerts.length;
    m.runScenario('stress');
    await _until(() => e.alerts.length > before, minutes: 14);
    if (_cancel) return;
    await _next(const TourStep('Every alert explains itself', 'The reasons, how sure the AI is, and the question "what was happening?". Tap "See how AdaptAlert decided" on any alert for the full breakdown.', tab: 1));
    await _wait(5500);

    final coffee = e.alerts.length > before ? e.alerts.first : null;
    await _next(const TourStep('The doctor gives feedback', 'Dr. Rao marks it a false alarm. AdaptAlert updates what it knows about this pattern, for Nandini only.', tab: 1));
    if (coffee != null) m.doctorLabel(coffee, false, by: 'Dr. Kavya Rao');
    await _until(() => m.scenarioId == 'rest', minutes: 14);
    await _minutes(12);
    await _wait(1500);

    await _next(const TourStep('Same coffee, next day', 'This time the alert is held back. It learned, not stopped watching: if it got worse or hit a safety limit, it would alert at once.', tab: 0));
    final held = e.held.length;
    m.runScenario('stress');
    await _until(() => e.held.length > held, minutes: 14);
    await _wait(3500);
    await _until(() => m.scenarioId == 'rest', minutes: 14);
    await _minutes(10);

    await _next(const TourStep('Now a real problem', 'Heart racing at rest while oxygen falls. Two vitals moving together means an urgent alert to Nandini, her mother Sunita and Dr. Rao.', tab: 0));
    final beforeReal = e.alerts.length;
    m.runScenario('tachy');
    await _until(() => e.alerts.length > beforeReal, minutes: 14);
    showTab(1);
    await _wait(5000);
    await _until(() => m.scenarioId == 'rest', minutes: 14);
    await _minutes(10);

    await _next(const TourStep('The safety floor', 'Oxygen falls to 89%. A critical alert fires without asking the model. Learning can never switch this off.', tab: 0));
    m.runScenario('hypoxia');
    await _until(() => e.alerts.isNotEmpty && e.alerts.first.safety, minutes: 14);
    await _wait(4500);

    await _next(TourStep(
      'The result',
      'Today a fixed monitor would have alarmed ${e.fixedCount} times; AdaptAlert sent ${e.sentCount} and held back ${e.held.length}. Over 30 simulated days it cut false alarms by about 97% and caught every real event. See the Research Lab for the evidence.',
      tab: 2,
    ));
    m.runScenario('rest');
    await _wait(3000);

    await _next(const TourStep(
      'Your turn',
      'That was PulseOS. To use it yourself, log in or create your own account as a patient, a doctor or a nurse.',
      last: true,
    ));
  }
}
