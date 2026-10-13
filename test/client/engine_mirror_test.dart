import 'package:bt39_care/engine/adapt_alert.dart';
import 'package:bt39_care/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late AdaptAlertEngine e;

  setUp(() {
    appLang.value = 'en';
    e = AdaptAlertEngine();
  });
  tearDown(() => appLang.value = 'en');

  group('snapshot', () {
    test('fills every field the screens read', () {
      e.applySnapshot(stateJson(
        alerts: [alertJson(3, t: 500), alertJson(1, t: 120)],
        held: [heldJson(480), heldJson(300)],
        buckets: [bucketJson('rest|hr|mod|day', r: 0, f: 1.5, p: .41), bucketJson('rest|multi|multi|day', r: 1, f: 0, p: .9, send: true)],
      ));
      expect(e.t, 512);
      expect(e.tau, .53);
      expect(e.weekStartTau, .5);
      expect(e.sqiMin, .5);
      expect(e.labels, 2);
      expect(e.fixedCount, 3);
      expect(e.sentCount, 1);
      expect(e.status, 'ok');

      expect(e.base['rest']!['hr']!.mu, 66.4);
      expect(e.base['rest']!['hr']!.sd, 6.0);
      expect(e.base['active']!['temp']!.mu, 36.55);

      expect(e.buckets.keys, ['rest|hr|mod|day', 'rest|multi|multi|day'], reason: 'order kept');
      expect(e.buckets['rest|hr|mod|day']!.f, 1.5);
      expect(e.buckets['rest|multi|multi|day']!.send, isTrue);
      expect(e.bucketP('rest|multi|multi|day'), .9);

      expect(e.alerts.map((a) => a.id), [3, 1], reason: 'newest first');
      expect(e.alertById(1)!.t, 120);
      expect(e.alertById(99), isNull);
      expect(e.held.map((h) => h.t), [480, 300]);
      expect(e.held.first.rec.r.hr, 88);

      expect(e.history.length, 5);
      expect(e.history.first.t, 507, reason: 'oldest first');
      expect(e.last!.t, 511);
      expect(e.pipe.keys, ['A', 'B', 'C', 'D', 'E', 'F', 'G']);
    });

    test('replaces what was there before', () {
      e.applySnapshot(stateJson(alerts: [alertJson(1)], held: [heldJson(10)]));
      e.applySnapshot(stateJson(t: 900, alerts: [alertJson(7, t: 890)], held: [], buckets: [], history: [rec(899)]));
      expect(e.alerts.map((a) => a.id), [7]);
      expect(e.held, isEmpty);
      expect(e.buckets, isEmpty);
      expect(e.history.single.t, 899);
      expect(e.t, 900);
    });

    test('an alert that is still listed keeps its object, with the server\'s word final', () {
      e.applySnapshot(stateJson(alerts: [alertJson(1)]));
      final a = e.alertById(1)!;
      a.patientFeedback = PatientFeedback.active; // an answer the server never got
      e.applySnapshot(stateJson(alerts: [alertJson(1)]));
      expect(identical(e.alertById(1), a), isTrue);
      expect(a.patientFeedback, isNull, reason: 'a snapshot is authoritative');
    });

    test('keeps the 240 newest windows of history', () {
      e.applySnapshot(stateJson(t: 300, history: [for (var i = 0; i < 300; i++) rec(i)]));
      expect(e.history.length, 240);
      expect(e.history.first.t, 60);
      expect(e.history.last.t, 299);
    });

    test('has sensible values before the first snapshot', () {
      expect(e.alerts, isEmpty);
      expect(e.last, isNull);
      expect(e.base['rest']!['hr']!.mu, isNonZero);
      expect(e.bucketP('anything'), .5);
    });

    test('a window record exposes the vital by name', () {
      e.applySnapshot(stateJson(history: [rec(1, hr: 71, spo2: 95, temp: 37.1)]));
      final r = e.last!;
      expect(r.value('hr'), 71);
      expect(r.value('spo2'), 95);
      expect(r.value('temp'), 37.1);
      expect(r.r.motion, .05);
      expect(r.mu['hr'], 66.0);
      expect(r.sd['spo2'], 1.0);
      expect(r.z['hr'], closeTo(5 / 6, 1e-9));
      expect(r.act, 'Resting');
      expect(r.good, isTrue);
    });
  });

  group('updates', () {
    setUp(() => e.applySnapshot(stateJson(alerts: [alertJson(2, t: 400), alertJson(1, t: 100)], held: [heldJson(300)])));

    test('a new window is appended and the figures move', () {
      e.applyUpdate(updateLine(t: 513, rec_: rec(512, hr: 70), events: []));
      expect(e.last!.t, 512);
      expect(e.last!.r.hr, 70);
      expect(e.history.length, 6);
      expect(e.t, 513);
      expect(e.tau, .53);
    });

    test('a null rec adds no window but still updates the rest', () {
      final before = e.history.length;
      e.applyUpdate(updateLine(t: 600, rec_: null, extra: {'status': 'watch', 'labels': 9, 'fixed': 12, 'sent': 4, 'tau': .61, 'week_start_tau': .55, 'sqi_min': .6}));
      expect(e.history.length, before);
      expect(e.t, 600);
      expect(e.status, 'watch');
      expect(e.labels, 9);
      expect(e.fixedCount, 12);
      expect(e.sentCount, 4);
      expect(e.tau, .61);
      expect(e.weekStartTau, .55);
      expect(e.sqiMin, .6);
    });

    test('history never grows past 240', () {
      e.applySnapshot(stateJson(t: 300, history: [for (var i = 0; i < 240; i++) rec(i)]));
      for (var i = 240; i < 260; i++) {
        e.applyUpdate(updateLine(t: i + 1, rec_: rec(i)));
      }
      expect(e.history.length, 240);
      expect(e.history.first.t, 20);
      expect(e.last!.t, 259);
    });

    test('learned patterns are replaced only when the line has them', () {
      e.applyUpdate(updateLine(rec_: rec(512)));
      expect(e.buckets.keys, ['rest|hr|mod|day'], reason: 'absent: kept');
      e.applyUpdate(updateLine(rec_: rec(513), buckets: [bucketJson('rest|spo2|mod|night', f: 2, p: .3)]));
      expect(e.buckets.keys, ['rest|spo2|mod|night']);
      e.applyUpdate(updateLine(rec_: rec(514), buckets: []));
      expect(e.buckets, isEmpty);
    });

    test('baselines and the pipeline are replaced', () {
      e.applyUpdate(updateLine(rec_: rec(512), extra: {
        'base': baseJson(hr: 70.5),
        'pipe': {
          'A': {'s': 'bad', 'x': 'Quality 0.20 · unreliable, ignore it'},
        },
      }));
      expect(e.base['rest']!['hr']!.mu, 70.5);
      expect(e.pipe.keys, ['A']);
      expect(e.pipe['A']!.state, StageState.bad);
      expect(e.pipe['A']!.text, 'Quality 0.20 · unreliable, ignore it');
    });

    test('a new alert goes to the front', () {
      e.applyUpdate(updateLine(rec_: rec(512, alert: 3), alerts: [alertJson(3, t: 512, level: 3)]));
      expect(e.alerts.map((a) => a.id), [3, 2, 1]);
      expect(e.alertById(3)!.level, 3);
      expect(e.last!.alert, 3);
    });

    test('a changed alert is updated in place, in the same object and position', () {
      final two = e.alertById(2)!;
      e.applyUpdate(updateLine(alerts: [alertJson(2, t: 400, feedback: 'loose', doctor: 'confirmed', reviewedBy: 'Dr. Kavya Rao')]));
      expect(e.alerts.map((a) => a.id), [2, 1]);
      expect(identical(e.alertById(2), two), isTrue);
      expect(two.patientFeedback, PatientFeedback.loose);
      expect(two.doctor, DoctorLabel.confirmed);
      expect(two.reviewedBy, 'Dr. Kavya Rao');
    });

    test('a new and a changed alert in one line', () {
      e.applyUpdate(updateLine(alerts: [alertJson(1, t: 100, feedback: 'unwell'), alertJson(5, t: 520)]));
      expect(e.alerts.map((a) => a.id), [5, 2, 1]);
      expect(e.alertById(1)!.patientFeedback, PatientFeedback.unwell);
    });

    test('two new alerts end up newest first, whatever order they come in', () {
      e.applyUpdate(updateLine(alerts: [alertJson(4, t: 510), alertJson(6, t: 530), alertJson(5, t: 520)]));
      expect(e.alerts.map((a) => a.id), [6, 5, 4, 2, 1]);
    });

    test('an answer already on the alert is not taken back by a line that predates it', () {
      final a = e.alertById(2)!;
      a.patientFeedback = PatientFeedback.active;
      a.doctor = DoctorLabel.rejected;
      a.reviewedBy = 'Dr. Kavya Rao';
      // A line the service wrote before it saw our answer.
      e.applyUpdate(updateLine(alerts: [alertJson(2, t: 400)]));
      expect(a.patientFeedback, PatientFeedback.active);
      expect(a.doctor, DoctorLabel.rejected);
      expect(a.reviewedBy, 'Dr. Kavya Rao');
    });

    test('held events are put in front and returned oldest first', () {
      final added = e.applyUpdate(updateLine(rec_: rec(512), heldNew: [heldJson(510, p: .2), heldJson(512, p: .3)]));
      expect(added.map((h) => h.t), [510, 512]);
      expect(e.held.map((h) => h.t), [512, 510, 300], reason: 'newest first');
      expect(e.held.first.p, .3);
      expect(e.applyUpdate(updateLine(rec_: rec(513))), isEmpty);
    });

    test('alerts and held events are capped like the server\'s lists', () {
      e.applySnapshot(stateJson(alerts: [for (var i = 250; i >= 1; i--) alertJson(i, t: i)], held: [for (var i = 250; i >= 1; i--) heldJson(i)]));
      expect(e.alerts.length, 200);
      expect(e.held.length, 200);
      e.applyUpdate(updateLine(alerts: [alertJson(251, t: 251)], heldNew: [heldJson(251)]));
      expect(e.alerts.length, 200);
      expect(e.alerts.first.id, 251);
      expect(e.held.length, 200);
      expect(e.held.first.t, 251);
    });

    test('an update with nothing in it changes nothing', () {
      final before = e.alerts.map((a) => a.id).toList();
      e.applyUpdate({'type': 'update', 'version': 7});
      expect(e.alerts.map((a) => a.id), before);
      expect(e.tau, .53);
    });
  });

  group('alerts', () {
    test('parse every field', () {
      e.applySnapshot(stateJson(alerts: [
        alertJson(4, t: 640, level: 4, safety: true, autoSos: true, feedback: 'notSure', doctor: 'rejected', reviewedBy: 'Dr. Kavya Rao', tau: .55),
      ]));
      final a = e.alertById(4)!;
      expect(a.t, 640);
      expect(a.level, 4);
      expect(a.levelLabel, 'Critical');
      expect(a.safety, isTrue);
      expect(a.autoSos, isTrue);
      expect(a.patientFeedback, PatientFeedback.notSure);
      expect(a.doctor, DoctorLabel.rejected);
      expect(a.reviewedBy, 'Dr. Kavya Rao');
      expect(a.key, 'rest|hr|mod|day');
      expect([a.p, a.pg, a.pu, a.w, a.n, a.tau], [.58, .58, .5, 0, 0, .55]);
      expect([a.hr, a.spo2, a.temp], [89, 97, 36.6]);
      expect(a.escalation.single.who, 'You');
      expect(a.escalation.single.t, 640);
    });

    test('the explanation', () {
      e.applySnapshot(stateJson(alerts: [
        alertJson(1, explain: {'ci': {'lo': .31, 'hi': .74}, 'single_p': .44, 'if_false': .45, 'tau_false': .53, 'if_real': .7, 'tau_real': .45}),
        alertJson(2, explain: {'ci': {'lo': .1, 'hi': .9}, 'single_p': null, 'if_false': .6, 'tau_false': .5, 'if_real': .8, 'tau_real': .4}),
      ]));
      final x = e.alertById(1)!.explain!;
      expect(x.ci.lo, .31);
      expect(x.ci.hi, .74);
      expect(x.singleP, .44);
      expect([x.ifFalse, x.tauFalse, x.ifReal, x.tauReal], [.45, .53, .7, .45]);
      expect(x.ifFalseSends, isFalse, reason: '.45 is under .53');
      final y = e.alertById(2)!.explain!;
      expect(y.singleP, isNull);
      expect(y.ifFalseSends, isTrue);
    });

    test('an alert with no explanation or Auto SOS flag still parses', () {
      final j = alertJson(1)..remove('explain')..remove('auto_sos')..remove('escalation')..remove('reviewed_by')..remove('feedback')..remove('doctor');
      e.applySnapshot(stateJson(alerts: [j]));
      final a = e.alertById(1)!;
      expect(a.explain, isNull);
      expect(a.autoSos, isFalse);
      expect(a.escalation, isEmpty);
      expect(a.patientFeedback, isNull);
      expect(a.doctor, DoctorLabel.pending);
    });

    test('numbers that arrive as whole numbers or decimals both read', () {
      final j = alertJson(1)..['p'] = 1..['tau'] = 1..['n'] = 2.0..['hr'] = 89.0;
      e.applySnapshot(stateJson(alerts: [j]));
      final a = e.alertById(1)!;
      expect(a.p, 1.0);
      expect(a.n, 2.0);
      expect(a.hr, 89);
    });
  });

  group('text follows the language', () {
    test('an alert\'s title, reasons, path, level and steps render when read', () {
      e.applySnapshot(stateJson(alerts: [alertJson(1, level: 1)]));
      final a = e.alertById(1)!;
      expect(a.title, 'Heart rate above your normal');
      expect(a.reasons.first, 'Heart rate 89 bpm, 35% above your usual resting 66 bpm');
      expect(a.reasons.last, 'Signal quality good (0.95)', reason: 'plain text stays');
      expect(a.path.single, 'Moderate heart-rate rise at rest');
      expect(a.levelLabel, 'Check-in');
      expect(a.escalation.single.what, 'Phone notification');

      appLang.value = 'hi';
      expect(a.title, 'धड़कन आपके सामान्य से ज़्यादा');
      expect(a.levelLabel, 'हालचाल');
      expect(a.escalation.single.what, 'फ़ोन पर सूचना');
      expect(a.reasons.last, 'Signal quality good (0.95)');

      appLang.value = 'en';
      expect(a.title, 'Heart rate above your normal');
    });

    test('pipeline steps render when read', () {
      e.applySnapshot(stateJson());
      expect(e.pipe['A']!.text, 'Quality 0.95 · good, use it');
      expect(e.pipe['E']!.text, 'Within your normal range');
      appLang.value = 'hi';
      expect(e.pipe['A']!.text, 'क्वालिटी 0.95 · अच्छी, इस्तेमाल करें');
      expect(e.pipe['E']!.text, 'आपकी सामान्य सीमा में');
    });

    test('a changed alert keeps rendering in the current language', () {
      e.applySnapshot(stateJson(alerts: [alertJson(1)]));
      final a = e.alertById(1)!;
      appLang.value = 'hi';
      e.applyUpdate(updateLine(alerts: [alertJson(1, title: {'t': 'Check-in'})]));
      expect(a.title, 'हालचाल');
    });

    test('Stage keeps the constructor the screens use', () {
      const s = Stage(StageState.idle, '—');
      expect(s.state, StageState.idle);
      expect(s.text, '—');
    });

    test('an unknown stage state is idle, not a crash', () {
      expect(Stage.fromJson({'s': 'whatever', 'x': 'text'}).state, StageState.idle);
      expect(Stage.fromJson({'x': 'text'}).text, 'text');
    });

    test('bucketLabel is unchanged display code', () {
      expect(bucketLabel('rest|hr|mod|day'), 'Resting · heart rate up a little · day');
      expect(bucketLabel('SAFETY|spo2'), 'Safety floor · oxygen');
      expect(pct(.534), '53%');
      expect(hhmm(7 * 60 + 5), '7:05');
    });
  });
}
