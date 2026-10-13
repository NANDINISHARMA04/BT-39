import 'dart:async';

import 'package:bt39_care/engine/adapt_alert.dart';
import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/services/monitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const live = 'GET /wearer/live';

/// A started controller with its first snapshot in.
Future<(LiveService, MonitorController)> boot({Map<String, dynamic>? snapshot, void Function()? onDemoExpired, bool disposeAtEnd = true}) async {
  final svc = LiveService()..stream(live);
  final m = MonitorController(api: svc.api(onDemoExpired: onDemoExpired))..start();
  await until(() => svc.opened(live).isNotEmpty, reason: 'the stream to open');
  svc.send(live, snapshot ?? snapshotLine());
  await until(() => m.ready, reason: 'the snapshot');
  if (disposeAtEnd) addTearDown(m.dispose);
  return (svc, m);
}

void main() {
  setUp(() => appLang.value = 'en');

  group('the stream', () {
    test('opens GET /wearer/live and shows the snapshot', () async {
      final svc = LiveService()..stream(live);
      final m = MonitorController(api: svc.api())..start();
      addTearDown(m.dispose);
      expect(m.ready, isFalse);
      expect(m.status, 'connecting');
      await until(() => svc.opened(live).isNotEmpty);
      expect(svc.seen.single.headers['Authorization'], 'Bearer test-token');

      svc.send(live, snapshotLine(version: 7, scenario: 'walk', minutesLeft: 5, paused: true, fast: true, state: stateJson(alerts: [alertJson(1)], held: [heldJson(300)])));
      await until(() => m.ready);
      expect(m.status, 'live');
      expect(m.error, isNull);
      expect(m.engine.t, 512);
      expect(m.engine.alerts.single.id, 1);
      expect(m.last!.t, 511);
      expect(m.scenarioId, 'walk');
      expect(m.scenarioMinutesLeft, 5);
      expect(m.paused, isTrue);
      expect(m.fast, isTrue);
      expect(m.needsReply, 1);
    });

    test('a snapshot fires no events, even with alerts in it', () async {
      final svc = LiveService()..stream(live);
      final m = MonitorController(api: svc.api())..start();
      addTearDown(m.dispose);
      var fired = 0;
      for (final n in [m.alertEvents, m.heldEvents, m.badSignal, m.scenarioEnded]) {
        n.addListener(() => fired++);
      }
      await until(() => svc.opened(live).isNotEmpty);
      svc.send(live, snapshotLine(state: stateJson(alerts: [alertJson(1), alertJson(2)], held: [heldJson(300)])));
      await until(() => m.ready);
      await settle();
      expect(fired, 0);
      expect(m.alertEvents.value, isNull);
      expect(m.heldEvents.value, isNull);
      expect(m.badSignal.value, 0);
      expect(m.scenarioEnded.value, isNull);
    });

    test('notifies its listeners on every line', () async {
      final (svc, m) = await boot();
      var n = 0;
      m.addListener(() => n++);
      svc.send(live, updateLine(rec_: rec(512)));
      svc.send(live, updateLine(t: 514, rec_: rec(513)));
      await until(() => m.engine.t == 514);
      expect(n, 2);
      expect(m.engine.history.last.t, 513);
    });

    test('pings and unknown lines are ignored', () async {
      final (svc, m) = await boot();
      var n = 0;
      m.addListener(() => n++);
      svc.send(live, {'type': 'ping'});
      svc.send(live, {'type': 'something new'});
      svc.sendRaw(live, 'not json\n');
      svc.send(live, updateLine(t: 520, rec_: rec(519)));
      await until(() => m.engine.t == 520);
      expect(n, 1);
      expect(m.status, 'live');
    });

    test('an update that comes before any snapshot is ignored', () async {
      final svc = LiveService()..stream(live);
      final m = MonitorController(api: svc.api())..start();
      addTearDown(m.dispose);
      await until(() => svc.opened(live).isNotEmpty);
      svc.send(live, updateLine(t: 999, rec_: rec(998), events: [{'kind': 'bad_signal'}]));
      await settle();
      expect(m.ready, isFalse);
      expect(m.engine.t, isNot(999));
      expect(m.badSignal.value, 0);
    });

    test('start twice opens one connection; stop ends it', () async {
      final (svc, m) = await boot();
      m.start();
      m.start();
      await settle();
      expect(svc.opened(live).length, 1);
      m.stop();
      await settle(100);
      svc.send(live, updateLine(t: 700, rec_: rec(699)));
      await settle();
      expect(m.engine.t, 512, reason: 'nothing is read after stop');
      expect(svc.opened(live).length, 1, reason: 'and it does not reconnect');
    });

    test('lines arriving after dispose do no harm', () async {
      final (svc, m) = await boot(disposeAtEnd: false);
      m.dispose();
      svc.send(live, updateLine(t: 700, rec_: rec(699), events: [{'kind': 'bad_signal'}]));
      await settle(100);
      expect(m.badSignal.value, 0);
    });
  });

  group('events from update lines', () {
    test('alert, held, bad signal and scenario end each fire once', () async {
      final (svc, m) = await boot();
      final seen = <String>[];
      HealthAlert? alert;
      HeldEvent? held;
      m.alertEvents.addListener(() {
        seen.add('alert');
        alert = m.alertEvents.value;
      });
      m.heldEvents.addListener(() {
        seen.add('held');
        held = m.heldEvents.value;
      });
      m.badSignal.addListener(() => seen.add('bad'));
      m.scenarioEnded.addListener(() => seen.add('ended:${m.scenarioEnded.value}'));

      svc.send(live, updateLine(
        t: 520,
        rec_: rec(519, alert: 2),
        alerts: [alertJson(3, t: 519)],
        heldNew: [heldJson(519, p: .27)],
        events: [
          {'kind': 'alert', 'id': 3},
          {'kind': 'held'},
          {'kind': 'bad_signal'},
          {'kind': 'scenario_ended', 'id': 'walk'},
        ],
      ));
      await until(() => seen.length == 4);
      expect(seen, ['alert', 'held', 'bad', 'ended:rest']);
      expect(alert!.id, 3);
      expect(identical(alert, m.engine.alertById(3)), isTrue, reason: 'the alert on the list, not a copy');
      expect(m.engine.alerts.first.id, 3, reason: 'already on the list when the event fires');
      expect(held!.p, .27);
      expect(m.badSignal.value, 1);
      expect(m.scenarioEnded.value, 'rest', reason: 'a scenario ends by returning to resting');

      // An update with no events fires nothing.
      svc.send(live, updateLine(t: 521, rec_: rec(520)));
      await until(() => m.engine.t == 521);
      expect(seen.length, 4);
    });

    test('two held events in one line fire one each, oldest first', () async {
      final (svc, m) = await boot();
      final got = <int>[];
      m.heldEvents.addListener(() => got.add(m.heldEvents.value!.t));
      svc.send(live, updateLine(t: 520, rec_: rec(519), heldNew: [heldJson(518), heldJson(519)], events: [{'kind': 'held'}, {'kind': 'held'}]));
      await until(() => got.length == 2);
      expect(got, [518, 519]);
    });

    test('scenarioEnded is \'rest\' and, as in the original app, notifies only the first time', () async {
      final (svc, m) = await boot();
      var n = 0;
      m.scenarioEnded.addListener(() => n++);
      expect(m.scenarioEnded.value, isNull);

      svc.send(live, updateLine(t: 520, rec_: rec(519), events: [{'kind': 'scenario_ended', 'id': 'walk'}]));
      await until(() => n == 1);
      expect(m.scenarioEnded.value, 'rest', reason: 'whichever scenario ended');

      // A second and a third scenario end. The value is still 'rest', so a plain
      // ValueNotifier says nothing: the guided demo shows "Back to resting" once.
      svc.send(live, updateLine(t: 600, rec_: rec(599), events: [{'kind': 'scenario_ended', 'id': 'stress'}]));
      svc.send(live, updateLine(t: 700, rec_: rec(699), events: [{'kind': 'scenario_ended', 'id': 'tachy'}]));
      await until(() => m.engine.t == 700);
      expect(n, 1);
      expect(m.scenarioEnded.value, 'rest');
    });

    test('bad signal counts up', () async {
      final (svc, m) = await boot();
      for (var i = 1; i <= 3; i++) {
        svc.send(live, updateLine(t: 520 + i, rec_: rec(519 + i), events: [{'kind': 'bad_signal'}]));
        await until(() => m.badSignal.value == i);
      }
    });
  });

  group('scenario, pause and fast forward', () {
    test('a scenario shows at once, is sent, and a stale line cannot take it back', () async {
      final (svc, m) = await boot(snapshot: snapshotLine(version: 7));
      final gate = Completer<void>();
      svc.routes['POST /wearer/scenario'] = (_) async {
        await gate.future;
        return jsonReply({'version': 8, 'scenario': {'id': 'walk', 'minutes_left': 12}});
      };
      var notified = 0;
      m.addListener(() => notified++);

      final sent = m.runScenario('walk');
      // At once, before the service has answered:
      expect(m.scenarioId, 'walk');
      expect(m.scenarioMinutesLeft, 12);
      expect(notified, 1);

      // A line written before the command arrives while it is in flight.
      svc.send(live, updateLine(version: 7, t: 520, rec_: rec(519), scenario: 'rest'));
      await until(() => m.engine.t == 520);
      expect(m.scenarioId, 'walk', reason: 'control fields are ignored while a command is in flight');
      expect(m.engine.last!.t, 519, reason: 'everything else is still taken');

      gate.complete();
      await sent;
      expect(svc.to('POST /wearer/scenario').single.map, {'id': 'walk'});
      expect(m.scenarioId, 'walk');
      expect(m.scenarioMinutesLeft, 12);

      // An older line still on the wire after the answer.
      svc.send(live, updateLine(version: 7, t: 521, rec_: rec(520), scenario: 'rest'));
      await until(() => m.engine.t == 521);
      expect(m.scenarioId, 'walk', reason: 'older than the version the command returned');

      // Lines from the command on are taken again.
      svc.send(live, updateLine(version: 8, t: 522, rec_: rec(521), scenario: 'walk', minutesLeft: 11));
      await until(() => m.engine.t == 522);
      expect(m.scenarioMinutesLeft, 11);
      svc.send(live, updateLine(version: 9, t: 523, rec_: rec(522), scenario: 'rest'));
      await until(() => m.engine.t == 523);
      expect(m.scenarioId, 'rest');
      expect(m.scenarioMinutesLeft, 0);
    });

    test('a scenario that is not on the list still shows, with no minutes', () async {
      final (svc, m) = await boot();
      svc.routes['POST /wearer/scenario'] = (_) => jsonReply({'version': 8, 'scenario': {'id': 'new', 'minutes_left': 3}});
      final f = m.runScenario('new');
      expect(m.scenarioId, 'new');
      expect(m.scenarioMinutesLeft, 0);
      await f;
      expect(m.scenarioMinutesLeft, 3);
    });

    test('a failed command puts the old state back and sets error, without throwing', () async {
      final (svc, m) = await boot(snapshot: snapshotLine(scenario: 'walk', minutesLeft: 4));
      svc.routes['POST /wearer/scenario'] = (_) => errorReply(422, 'unknown_scenario', 'No such scenario.');
      var notified = 0;
      m.addListener(() => notified++);
      final f = m.runScenario('fever');
      expect(m.scenarioId, 'fever');
      await f;
      expect(m.scenarioId, 'walk');
      expect(m.scenarioMinutesLeft, 4);
      expect(m.error, 'No such scenario.');
      expect(notified, greaterThanOrEqualTo(2));

      // The next good command clears it.
      svc.routes['POST /wearer/scenario'] = (_) => jsonReply({'version': 9, 'scenario': {'id': 'rest', 'minutes_left': 0}});
      await m.runScenario('rest');
      expect(m.error, isNull);
      expect(m.scenarioId, 'rest');
    });

    test('a service that cannot be reached fails the same way', () async {
      final (svc, m) = await boot();
      svc.routes['POST /wearer/paused'] = (_) => throw StateError('offline');
      await m.setPaused(true);
      expect(m.paused, isFalse);
      expect(m.error, 'The service could not be reached. It may be waking up. Try again in a minute.');
    });

    test('pause and fast forward show at once and follow the same rule', () async {
      final (svc, m) = await boot(snapshot: snapshotLine(version: 3));
      final gate = Completer<void>();
      svc.routes['POST /wearer/paused'] = (_) async {
        await gate.future;
        return jsonReply({'version': 4, 'paused': true});
      };
      svc.routes['POST /wearer/fast'] = (_) => jsonReply({'version': 5, 'fast': true});

      final a = m.setPaused(true);
      final b = m.setFast(true);
      expect(m.paused, isTrue);
      expect(m.fast, isTrue);
      svc.send(live, updateLine(version: 3, t: 520, rec_: rec(519), paused: false, fast: false));
      await until(() => m.engine.t == 520);
      expect(m.paused, isTrue);
      expect(m.fast, isTrue);

      gate.complete();
      await Future.wait([a, b]);
      expect(svc.to('POST /wearer/paused').single.map, {'paused': true});
      expect(svc.to('POST /wearer/fast').single.map, {'fast': true});
      svc.send(live, updateLine(version: 4, t: 521, rec_: rec(520), paused: false));
      await until(() => m.engine.t == 521);
      expect(m.paused, isTrue, reason: 'version 4 is older than the answer to the fast command (5)');
      expect(m.fast, isTrue);
      svc.send(live, updateLine(version: 6, t: 522, rec_: rec(521), paused: false, fast: false));
      await until(() => m.engine.t == 522);
      expect(m.paused, isFalse);
      expect(m.fast, isFalse);
    });

    test('commands in a row end on the last one', () async {
      final (svc, m) = await boot(snapshot: snapshotLine(version: 3));
      svc.routes['POST /wearer/scenario'] = (r) async {
        final id = r.map['id'] as String;
        if (id == 'walk') await Future<void>.delayed(const Duration(milliseconds: 60));
        return jsonReply({'version': id == 'walk' ? 4 : 5, 'scenario': {'id': id, 'minutes_left': id == 'walk' ? 12 : 0}});
      };
      final first = m.runScenario('walk');
      final second = m.runScenario('rest');
      await Future.wait([first, second]);
      expect(m.scenarioId, 'rest');
      svc.send(live, updateLine(version: 4, t: 530, rec_: rec(529), scenario: 'walk', minutesLeft: 10));
      await until(() => m.engine.t == 530);
      expect(m.scenarioId, 'rest', reason: 'the walk\'s version is older than the last answer');
    });

    test('a new snapshot starts over, even if the service restarted at a lower version', () async {
      final (svc, m) = await boot(snapshot: snapshotLine(version: 40));
      svc.routes['POST /wearer/fast'] = (_) => jsonReply({'version': 41, 'fast': true});
      await m.setFast(true);
      await svc.drop(live);
      await until(() => svc.opened(live).length == 2, ms: 4000, reason: 'the reconnect');
      svc.send(live, snapshotLine(version: 1, scenario: 'tachy', minutesLeft: 9));
      await until(() => m.scenarioId == 'tachy');
      expect(m.fast, isFalse);
      svc.send(live, updateLine(version: 2, t: 600, rec_: rec(599), scenario: 'tachy', minutesLeft: 8));
      await until(() => m.scenarioMinutesLeft == 8);
    });
  });

  group('answering alerts', () {
    test('the wearer\'s answer shows at once and the service\'s alert replaces it', () async {
      final (svc, m) = await boot(snapshot: snapshotLine(state: stateJson(alerts: [alertJson(1, level: 3)])));
      final a = m.engine.alertById(1)!;
      final gate = Completer<void>();
      svc.routes['POST /wearer/alerts/1/feedback'] = (_) async {
        await gate.future;
        final j = alertJson(1, level: 3, feedback: 'unwell');
        (j['escalation'] as List).add({'t': 100, 'who': 'Doctor', 'what': {'t': 'Priority: patient feels unwell'}});
        return jsonReply({'alert': j});
      };
      expect(m.needsReply, 1);
      final f = m.feedback(a, PatientFeedback.unwell);
      expect(a.patientFeedback, PatientFeedback.unwell);
      expect(m.needsReply, 0);

      // A line written before the answer must not take it back.
      svc.send(live, updateLine(t: 520, rec_: rec(519), alerts: [alertJson(1, level: 3)]));
      await until(() => m.engine.t == 520);
      expect(a.patientFeedback, PatientFeedback.unwell);

      gate.complete();
      await f;
      expect(svc.to('POST /wearer/alerts/1/feedback').single.map, {'kind': 'unwell'});
      expect(a.patientFeedback, PatientFeedback.unwell);
      expect(a.escalation.length, 2, reason: 'what the service added shows');
      expect(a.escalation.last.what, 'Priority: patient feels unwell');
      expect(identical(m.engine.alertById(1), a), isTrue);
    });

    test('an alert that already has an answer is not sent again', () async {
      final (svc, m) = await boot(snapshot: snapshotLine(state: stateJson(alerts: [alertJson(1, feedback: 'active', doctor: 'confirmed')])));
      final a = m.engine.alertById(1)!;
      await m.feedback(a, PatientFeedback.loose);
      await m.doctorLabel(a, false, by: 'Dr. X');
      expect(svc.seen.where((s) => s.method == 'POST'), isEmpty);
      expect(a.patientFeedback, PatientFeedback.active);
      expect(a.doctor, DoctorLabel.confirmed);
    });

    test('the doctor\'s label shows at once with who gave it', () async {
      final (svc, m) = await boot(snapshot: snapshotLine(state: stateJson(alerts: [alertJson(1)])));
      final a = m.engine.alertById(1)!;
      svc.routes['POST /wearer/alerts/1/label'] = (_) => jsonReply({'alert': alertJson(1, doctor: 'rejected', reviewedBy: 'Dr. Kavya Rao', tau: .56)});
      final f = m.doctorLabel(a, false, by: 'Dr. Kavya Rao');
      expect(a.doctor, DoctorLabel.rejected);
      expect(a.reviewedBy, 'Dr. Kavya Rao');
      await f;
      expect(svc.to('POST /wearer/alerts/1/label').single.map, {'real': false, 'by': 'Dr. Kavya Rao'});
      expect(a.doctor, DoctorLabel.rejected);
      expect(a.reviewedBy, 'Dr. Kavya Rao');
    });

    test('without a name the label is sent with by: null', () async {
      final (svc, m) = await boot(snapshot: snapshotLine(state: stateJson(alerts: [alertJson(1)])));
      svc.routes['POST /wearer/alerts/1/label'] = (_) => jsonReply({'alert': alertJson(1, doctor: 'confirmed')});
      await m.doctorLabel(m.engine.alertById(1)!, true);
      expect(svc.to('POST /wearer/alerts/1/label').single.map, {'real': true, 'by': null});
      expect(m.engine.alertById(1)!.doctor, DoctorLabel.confirmed);
    });

    test('a refused answer is taken back and error says why', () async {
      final (svc, m) = await boot(snapshot: snapshotLine(state: stateJson(alerts: [alertJson(1)])));
      final a = m.engine.alertById(1)!;
      svc.routes['POST /wearer/alerts/1/feedback'] = (_) => errorReply(404, 'no_such_alert', 'That alert is gone.');
      svc.routes['POST /wearer/alerts/1/label'] = (_) => errorReply(403, 'forbidden', 'Not allowed.');
      await m.feedback(a, PatientFeedback.active);
      expect(a.patientFeedback, isNull);
      expect(m.error, 'That alert is gone.');
      await m.doctorLabel(a, true, by: 'Dr. X');
      expect(a.doctor, DoctorLabel.pending);
      expect(a.reviewedBy, isNull);
      expect(m.error, 'Not allowed.');
    });
  });

  group('reconnecting', () {
    test('a dropped stream goes offline, comes back after a second and starts from a new snapshot', () async {
      final (svc, m) = await boot(snapshot: snapshotLine(state: stateJson(alerts: [alertJson(1)])));
      var fired = 0;
      m.alertEvents.addListener(() => fired++);
      final one = m.engine.alertById(1)!;

      await svc.drop(live);
      await until(() => m.status == 'offline');
      expect(m.ready, isTrue, reason: 'what was shown stays up');
      expect(m.engine.alerts.length, 1);

      await until(() => svc.opened(live).length == 2, ms: 4000, reason: 'the second connection');
      svc.send(live, snapshotLine(version: 12, scenario: 'stress', minutesLeft: 6, state: stateJson(t: 900, alerts: [alertJson(2, t: 880), alertJson(1)])));
      await until(() => m.status == 'live');
      expect(m.engine.t, 900);
      expect(m.engine.alerts.map((a) => a.id), [2, 1]);
      expect(identical(m.engine.alertById(1), one), isTrue);
      expect(m.scenarioId, 'stress');
      expect(m.scenarioMinutesLeft, 6);
      expect(fired, 0, reason: 'a snapshot is not an event');
    });

    test('a line that cannot be read ends the connection and starts a new one', () async {
      final (svc, m) = await boot();
      svc.send(live, {'type': 'update', 'version': 8, 't': 600, 'alerts': 'garbage'});
      await until(() => m.status == 'offline');
      await until(() => svc.opened(live).length == 2, ms: 4000);
      svc.send(live, snapshotLine(state: stateJson(t: 700)));
      await until(() => m.engine.t == 700);
      expect(m.status, 'live');
    });

    test('a refused stream is retried and never reaches ready', () async {
      final svc = LiveService()..stream(live);
      svc.refused[live] = (503, 'unavailable', 'Waking up.');
      final m = MonitorController(api: svc.api())..start();
      addTearDown(m.dispose);
      await until(() => svc.seen.length >= 2, ms: 4000, reason: 'a second try');
      expect(m.ready, isFalse);
      expect(m.status, 'connecting');
    });

    test('demo_expired on the stream tells the app', () async {
      var expired = 0;
      final svc = LiveService()..stream(live);
      svc.refused[live] = (401, 'demo_expired', 'Over.');
      final m = MonitorController(api: svc.api(onDemoExpired: () => expired++))..start();
      addTearDown(m.dispose);
      await until(() => expired >= 1);
      m.stop();
    });
  });

  testWidgets('the retry waits grow 1, 2, 4, 8 then stay at 15 seconds', (t) async {
    final svc = LiveService()..stream(live);
    svc.refused[live] = (503, 'unavailable', 'Waking up.');
    final m = MonitorController(api: svc.api())..start();
    int tries() => svc.seen.where((s) => s.route == live).length;

    Future<void> after(double seconds) => t.pump(Duration(milliseconds: (seconds * 1000).round()));
    await after(0.2);
    expect(tries(), 1, reason: 'the first try is at once');
    await after(0.9); // 1.1 s
    expect(tries(), 2);
    await after(1.5); // 2.6 s: next due at 1 + 2 = 3 s
    expect(tries(), 2);
    await after(0.6); // 3.2 s
    expect(tries(), 3);
    await after(3.0); // 6.2 s: next due at 3 + 4 = 7 s
    expect(tries(), 3);
    await after(1.0); // 7.2 s
    expect(tries(), 4);
    await after(7.0); // 14.2 s: next due at 7 + 8 = 15 s
    expect(tries(), 4);
    await after(1.0); // 15.2 s
    expect(tries(), 5);
    await after(14.0); // 29.2 s: next due at 15 + 15 = 30 s
    expect(tries(), 5);
    await after(1.0); // 30.2 s
    expect(tries(), 6);
    await after(15.0); // 45.2 s: and again after 15 s
    expect(tries(), 7);

    m.dispose();
    await after(20);
  });
}
