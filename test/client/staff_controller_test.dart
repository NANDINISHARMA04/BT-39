import 'dart:async';

import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/services/staff_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const ward = 'GET /ward/live';

Map<String, dynamic> bedJson(String bed, {String? patientId, int hr = 72, int news2 = 2, String band = 'low'}) => {
      'bed': bed,
      'patient_id': patientId,
      'name': patientId == null ? null : 'Ramesh Iyer',
      'age': patientId == null ? null : 67,
      'sex': patientId == null ? null : 'M',
      'hr': patientId == null ? null : hr,
      'spo2': patientId == null ? null : 96,
      'rr': patientId == null ? null : 16,
      'sbp': patientId == null ? null : 120,
      'dbp': patientId == null ? null : 75,
      'temp': patientId == null ? null : 36.8,
      'news2': patientId == null ? null : news2,
      'band': patientId == null ? null : band,
      'on_oxygen': patientId == null ? null : true,
      'consciousness': 'A',
      'stale_s': 0,
      'nibp_age_s': 300,
      'open_alerts': [],
      'points': patientId == null ? {} : {'hr': 0, 'spo2': 1, 'rr': 0, 'sbp': null, 'temp': 0},
    };

Map<String, dynamic> staffAlertJson(String id, {String severity = 'high', String? ackBy, String? ackAt, String? resolvedAt, String? resolution, Object? message}) => {
      'id': id,
      'patient_id': 'demo-B05',
      'bed': 'B05',
      'patient_name': 'Harpreet Gill',
      'kind': 'acute_spo2',
      'severity': severity,
      'message': message ?? {'t': 'SpO₂ {spo2}% for 30 s on air', 'a': {'spo2': 85}},
      'started_at': '2026-10-13T09:00:00Z',
      'news2': 7,
      'ack_by': ackBy,
      'ack_at': ackAt,
      'resolved_at': resolvedAt,
      'resolution': resolution,
    };

Map<String, dynamic> frame({List<Map<String, dynamic>>? beds, List<Map<String, dynamic>>? alerts}) => {
      'beds': beds ?? [bedJson('B01', patientId: 'demo-B01'), bedJson('B07')],
      'alerts': alerts ?? [],
      'status': 'live',
    };

Future<(LiveService, StaffController)> demoWard({List<Map<String, dynamic>>? alerts, Map<String, dynamic>? labels}) async {
  final svc = LiveService()..stream(ward);
  svc.on('GET /labels', {'labels': labels ?? {}});
  final sc = StaffController(demo: true, token: () async => 'pd1.doc.sig', myName: 'Dr. Kavya Rao', api: svc.api());
  addTearDown(sc.dispose);
  sc.start();
  await until(() => svc.opened(ward).isNotEmpty, reason: 'the ward stream');
  svc.send(ward, frame(alerts: alerts ?? [staffAlertJson('demo-1')]));
  await until(() => sc.alerts.isNotEmpty, reason: 'the first frame');
  return (svc, sc);
}

void main() {
  setUp(() => appLang.value = 'en');
  tearDown(() => appLang.value = 'en');

  group('Demo Mode ward', () {
    test('streams GET /ward/live with the staff token, and each frame replaces the beds and alerts', () async {
      final svc = LiveService()..stream(ward);
      svc.on('GET /labels', {'labels': {}});
      final sc = StaffController(demo: true, token: () async => 'x', myName: 'Dr. Kavya Rao', api: svc.api());
      addTearDown(sc.dispose);
      expect(sc.status, 'connecting');
      sc.start();
      await until(() => svc.opened(ward).isNotEmpty);
      expect(svc.to(ward).single.headers['Authorization'], 'Bearer test-token');

      svc.send(ward, frame(alerts: [staffAlertJson('demo-1'), staffAlertJson('demo-2', severity: 'low')]));
      await until(() => sc.beds.isNotEmpty);
      expect(sc.status, 'live');
      expect(sc.beds.map((b) => b.bed), ['B01', 'B07']);
      expect(sc.beds.first.empty, isFalse);
      expect(sc.beds.last.empty, isTrue);
      expect(sc.beds.first.name, 'Ramesh Iyer');
      expect(sc.beds.first.news2, 2);
      expect(sc.beds.first.points, {'hr': 0, 'spo2': 1, 'rr': 0, 'sbp': null, 'temp': 0});
      expect(sc.alerts.map((a) => a.id), ['demo-1', 'demo-2']);

      svc.send(ward, frame(beds: [bedJson('B01', patientId: 'demo-B01', hr: 80, news2: 5, band: 'medium')], alerts: [staffAlertJson('demo-3')]));
      await until(() => sc.beds.length == 1);
      expect(sc.beds.single.hr, 80);
      expect(sc.beds.single.band, 'medium');
      expect(sc.alerts.map((a) => a.id), ['demo-3'], reason: 'a frame is the whole ward');
    });

    test('keeps the heart-rate history of each bed, up to 120 readings', () async {
      final (svc, sc) = await demoWard();
      for (var i = 0; i < 130; i++) {
        svc.send(ward, frame(beds: [bedJson('B01', patientId: 'demo-B01', hr: 60 + i % 40)]));
      }
      await until(() => sc.hrHistory['B01']!.length == 120, reason: 'the history to fill');
      await settle(50);
      expect(sc.hrHistory['B01']!.length, 120);
      expect(sc.hrHistory['B01']!.last, 60 + 129 % 40);
      expect(sc.hrHistory['B07']!.every((x) => x == null), isTrue, reason: 'an empty bed has no heart rate');
    });

    test('an alert\'s text is a message and follows the language', () async {
      final (_, sc) = await demoWard();
      final a = sc.alerts.single;
      expect(a.message, 'SpO₂ 85% for 30 s on air');
      expect(a.kindName, 'Very low oxygen');
      expect(a.patientName, 'Harpreet Gill');
      expect(a.bed, 'B05');
      expect(a.news2, 7);
      expect(a.open, isTrue);
      expect(a.startedAt.isAtSameMomentAs(DateTime.utc(2026, 10, 13, 9)), isTrue);
      expect(a.startedAt.isUtc, isFalse);
      appLang.value = 'hi';
      expect(a.message, 'सामान्य हवा पर 30 सेकंड से SpO₂ 85%');
    });

    test('a plain string message still works (alerts from the real ward)', () {
      final a = StaffAlert(id: 'x', patientId: 'p', bed: 'B1', patientName: 'N', kind: 'news2', severity: 'low', message: 'NEWS2 5 (Medium)', startedAt: DateTime.now());
      expect(a.message, 'NEWS2 5 (Medium)');
      expect(a.kindName, 'NEWS2');
    });

    test('reads the acknowledgement and the resolution of an alert', () async {
      final (_, sc) = await demoWard(alerts: [staffAlertJson('demo-1', ackBy: 'Dr. Kavya Rao', ackAt: '2026-10-13T09:01:00Z', resolvedAt: '2026-10-13T09:05:00Z', resolution: 'auto')]);
      final a = sc.alerts.single;
      expect(a.ackBy, 'Dr. Kavya Rao');
      expect(a.ackAt!.isAtSameMomentAs(DateTime.utc(2026, 10, 13, 9, 1)), isTrue);
      expect(a.open, isFalse);
      expect(a.resolution, 'auto');
      expect(sc.openUnacked, 0);
    });

    test('a dropped stream goes offline and comes back with the ward again', () async {
      final (svc, sc) = await demoWard();
      await svc.drop(ward);
      await until(() => sc.status == 'offline');
      await until(() => svc.opened(ward).length == 2, ms: 4000, reason: 'the reconnect');
      svc.send(ward, frame(beds: [bedJson('B01', patientId: 'demo-B01', hr: 99)], alerts: []));
      await until(() => sc.status == 'live');
      expect(sc.beds.single.hr, 99);
      expect(sc.alerts, isEmpty);
    });

    testWidgets('goes stale when the frames stop', (t) async {
      final svc = LiveService()..stream(ward);
      svc.on('GET /labels', {'labels': {}});
      final sc = StaffController(demo: true, token: () async => 'x', myName: 'Dr. X', api: svc.api())..start();
      await t.pump(const Duration(milliseconds: 100));
      svc.send(ward, frame());
      await t.pump(const Duration(milliseconds: 100));
      expect(sc.status, 'live');
      await t.pump(const Duration(seconds: 4));
      expect(sc.status, 'live', reason: 'a frame within five seconds keeps it live');
      await t.pump(const Duration(seconds: 2));
      expect(sc.status, 'stale');
      svc.send(ward, frame());
      await t.pump(const Duration(milliseconds: 100));
      expect(sc.status, 'live', reason: 'and a new frame brings it back');
      sc.dispose();
      await svc.drop(ward);
      await t.pump(const Duration(seconds: 2));
    });

    test('a ward that is refused is retried and stays connecting', () async {
      final svc = LiveService()..stream(ward);
      svc.refused[ward] = (503, 'unavailable', 'Waking up.');
      svc.on('GET /labels', {'labels': {}});
      final sc = StaffController(demo: true, token: () async => 'x', myName: 'Dr. X', api: svc.api());
      addTearDown(sc.dispose);
      sc.start();
      await until(() => svc.to(ward).length >= 2, ms: 4000, reason: 'a second try');
      expect(sc.status, 'connecting');
      expect(sc.beds, isEmpty);
    });
  });

  group('acknowledging and resolving', () {
    test('an acknowledgement shows at once and is sent', () async {
      final (svc, sc) = await demoWard();
      final gate = Completer<void>();
      svc.routes['POST /ward/alerts/demo-1/ack'] = (_) async {
        await gate.future;
        return jsonReply({'ok': true});
      };
      final a = sc.alerts.single;
      expect(sc.openUnacked, 1);
      var notified = 0;
      sc.addListener(() => notified++);
      final f = sc.ack(a);
      expect(a.ackBy, 'Dr. Kavya Rao');
      expect(a.ackAt, isNotNull);
      expect(sc.openUnacked, 0);
      expect(notified, 1);

      // A frame written before the acknowledgement must not take it back.
      svc.send(ward, frame(alerts: [staffAlertJson('demo-1')]));
      await until(() => notified >= 2);
      expect(sc.alerts.single.ackAt, isNotNull);
      expect(sc.alerts.single.ackBy, 'Dr. Kavya Rao');

      gate.complete();
      expect(await f, isNull);
      expect(svc.to('POST /ward/alerts/demo-1/ack').single.body, isEmpty);
    });

    test('an alert that was already acknowledged is not an error', () async {
      final (svc, sc) = await demoWard();
      svc.routes['POST /ward/alerts/demo-1/ack'] = (_) => errorReply(409, 'already_acknowledged', 'Already acknowledged.');
      final a = sc.alerts.single;
      expect(await sc.ack(a), isNull);
      expect(a.ackAt, isNotNull);
    });

    test('a refused acknowledgement is taken back and returns the sentence', () async {
      final (svc, sc) = await demoWard();
      svc.routes['POST /ward/alerts/demo-1/ack'] = (_) => errorReply(404, 'not_found', 'No such alert.');
      final a = sc.alerts.single;
      expect(await sc.ack(a), 'No such alert.');
      expect(a.ackAt, isNull);
      expect(a.ackBy, isNull);
    });

    test('a serious alert needs a note to resolve', () async {
      final (svc, sc) = await demoWard();
      final a = sc.alerts.single;
      expect(await sc.resolve(a, ' ok '), 'Add a short note on what was done (at least 3 characters).');
      expect(a.open, isTrue);
      expect(svc.to('POST /ward/alerts/demo-1/resolve'), isEmpty);
    });

    test('resolving shows at once, sends the note, and a stale frame cannot reopen it', () async {
      final (svc, sc) = await demoWard();
      final gate = Completer<void>();
      svc.routes['POST /ward/alerts/demo-1/resolve'] = (_) async {
        await gate.future;
        return jsonReply({'ok': true});
      };
      final a = sc.alerts.single;
      final f = sc.resolve(a, '  Oxygen started, SpO2 back to 95.  ');
      expect(a.open, isFalse);
      expect(a.resolution, 'Oxygen started, SpO2 back to 95.');
      var notified = 0;
      sc.addListener(() => notified++);
      svc.send(ward, frame(alerts: [staffAlertJson('demo-1')]));
      await until(() => notified >= 1);
      expect(sc.alerts.single.open, isFalse);
      gate.complete();
      expect(await f, isNull);
      expect(svc.to('POST /ward/alerts/demo-1/resolve').single.map, {'note': 'Oxygen started, SpO2 back to 95.'});
    });

    test('a low alert may be resolved with no note, shown as resolved', () async {
      final (svc, sc) = await demoWard(alerts: [staffAlertJson('demo-1', severity: 'low')]);
      svc.on('POST /ward/alerts/demo-1/resolve', {'ok': true});
      final a = sc.alerts.single;
      expect(await sc.resolve(a, ''), isNull);
      expect(a.resolution, 'resolved');
      expect(svc.to('POST /ward/alerts/demo-1/resolve').single.map, {'note': ''});
    });

    test('a refused resolution is taken back', () async {
      final (svc, sc) = await demoWard();
      svc.routes['POST /ward/alerts/demo-1/resolve'] = (_) => errorReply(403, 'forbidden', 'Staff only.');
      final a = sc.alerts.single;
      expect(await sc.resolve(a, 'Checked the probe.'), 'Staff only.');
      expect(a.open, isTrue);
      expect(a.resolution, isNull);
    });

    test('sorts open and serious alerts first', () async {
      final (_, sc) = await demoWard(alerts: [
        staffAlertJson('a', severity: 'low'),
        staffAlertJson('b', severity: 'high', resolvedAt: '2026-10-13T09:05:00Z', resolution: 'auto'),
        staffAlertJson('c', severity: 'medium'),
        staffAlertJson('d', severity: 'high'),
      ]);
      expect(sc.sortedAlerts.map((a) => a.id), ['d', 'c', 'a', 'b']);
      expect(sc.openUnacked, 3);
    });
  });

  group('other actions', () {
    test('a scenario for a bed', () async {
      final (svc, sc) = await demoWard();
      svc.on('POST /ward/scenario', {'ok': true});
      expect(await sc.runScenario('B01', 'sepsis'), isNull);
      expect(svc.to('POST /ward/scenario').single.map, {'bed': 'B01', 'scenario': 'sepsis'});
      svc.routes['POST /ward/scenario'] = (_) => errorReply(422, 'unknown_scenario', 'No such scenario.');
      expect(await sc.runScenario('B01', 'nope'), 'No such scenario.');
    });

    test('the bed chat is answered by the service, in the language of the app', () async {
      final (svc, sc) = await demoWard();
      svc.on('POST /ward/chat', {
        'text': {
          'c': [
            {'t': 'Heart rate {hr} for 30 s', 'a': {'hr': 152}},
            '.',
          ],
        },
      });
      final bed = sc.beds.first;
      expect(await sc.demoAnswer(bed, 'How is he?'), 'Heart rate 152 for 30 s.');
      expect(svc.to('POST /ward/chat').single.map, {'bed': 'B01', 'q': 'How is he?'});
      appLang.value = 'hi';
      expect(await sc.demoAnswer(bed, 'kaisa hai'), '30 सेकंड से धड़कन 152.');
      expect(svc.to('POST /ward/chat').last.headers['X-Lang'], 'hi');
      svc.routes['POST /ward/chat'] = (_) => errorReply(429, 'rate_limited', 'Slow down.');
      expect(await sc.demoAnswer(bed, 'again'), 'Slow down.');
    });
  });

  group('labels', () {
    test('saved labels are read when it starts, without overwriting a newer one', () async {
      final svc = LiveService()..stream(ward);
      final gate = Completer<void>();
      svc.routes['GET /labels'] = (_) async {
        await gate.future;
        return jsonReply({
          'labels': {'demo-1': false, 'demo-2': true, 'demo-9': 'not a label'},
        });
      };
      svc.on('POST /labels', {'ok': true});
      final sc = StaffController(demo: true, token: () async => 'x', myName: 'Dr. X', api: svc.api());
      addTearDown(sc.dispose);
      sc.start();
      await until(() => svc.opened(ward).isNotEmpty);
      svc.send(ward, frame(alerts: [staffAlertJson('demo-1'), staffAlertJson('demo-2')]));
      await until(() => sc.alerts.length == 2);

      final l = sc.label(sc.alerts.first, true); // demo-1, while the saved labels are still loading
      gate.complete();
      await l;
      await until(() => sc.labels.length == 2, reason: 'the saved labels');
      expect(sc.labels['demo-1'], isTrue, reason: 'the newer answer wins');
      expect(sc.labels['demo-2'], isTrue);
      expect(sc.labels.containsKey('demo-9'), isFalse);
    });

    test('a label shows at once and is saved', () async {
      final (svc, sc) = await demoWard();
      svc.on('POST /labels', {'ok': true});
      var notified = 0;
      sc.addListener(() => notified++);
      final f = sc.label(sc.alerts.single, false);
      expect(sc.labels['demo-1'], isFalse);
      expect(notified, 1);
      await f;
      expect(svc.to('POST /labels').single.map, {'alert_id': 'demo-1', 'real': false});
      expect(sc.error, isNull);
    });

    test('a label the service refused stays on screen, with the reason', () async {
      final (svc, sc) = await demoWard();
      svc.routes['POST /labels'] = (_) => errorReply(500, 'boom', 'Could not save.');
      await sc.label(sc.alerts.single, true);
      expect(sc.labels['demo-1'], isTrue);
      expect(sc.error, 'Could not save.');
    });

    test('precision by kind', () async {
      final (svc, sc) = await demoWard(alerts: [
        staffAlertJson('a'),
        staffAlertJson('b'),
        {...staffAlertJson('c'), 'kind': 'news2'},
        staffAlertJson('d'),
      ]);
      svc.on('POST /labels', {'ok': true});
      await sc.label(sc.alerts[0], true);
      await sc.label(sc.alerts[1], false);
      await sc.label(sc.alerts[2], true);
      expect(sc.precisionByKind['Very low oxygen'], (real: 1, total: 2));
      expect(sc.precisionByKind['NEWS2'], (real: 1, total: 1));
      expect(sc.precisionByKind.length, 2);
    });
  });

  group('the real ward', () {
    test('streams GET /v1/live and leaves the alerts to Supabase', () async {
      final svc = LiveService()..stream('GET /v1/live');
      svc.on('GET /labels', {'labels': {}});
      final sc = StaffController(demo: false, token: () async => 'sb-token', myName: 'Nurse X', api: svc.api());
      addTearDown(sc.dispose);
      sc.start();
      await until(() => svc.opened('GET /v1/live').isNotEmpty);
      expect(svc.to('GET /v1/live').single.url.path, '/v1/live', reason: 'the BT39 route, not a PulseOS one');
      expect(svc.to('GET /v1/live').single.headers['Authorization'], 'Bearer sb-token');
      svc.send('GET /v1/live', {
        'beds': [bedJson('B01', patientId: 'p-1')],
      });
      await until(() => sc.beds.isNotEmpty);
      expect(sc.status, 'live');
      expect(sc.beds.single.points['spo2'], 1);
      expect(sc.alerts, isEmpty);
      expect(svc.to('GET /labels').length, 1, reason: 'labels are saved for real wards too');
      expect(svc.to(ward), isEmpty);
    });
  });
}
