import 'dart:async';

import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/models/patient_models.dart';
import 'package:bt39_care/services/clinical_store.dart';
import 'package:bt39_care/services/session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

String key(DateTime d) => ClinicalStore.dayKey(d);

DateTime day(int offset) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset);
}

Map<String, dynamic> visitJson(String id, String patientId, DateTime at, {String status = 'upcoming', bool video = false, bool byPatient = false, String name = 'Farhan Ali'}) => {
      'id': id, 'patientId': patientId, 'patientName': name, 'at': at.toUtc().toIso8601String(), 'reason': 'Review', 'video': video, 'status': status, 'bookedByPatient': byPatient,
    };

Map<String, dynamic> patientJson(String id, String name, String source, {bool hasStore = false, Map<String, dynamic>? vitals, String? email, String status = 'Stable'}) => {
      'id': id, 'name': name, 'age': 41, 'sex': 'F', 'bloodGroup': 'A+', 'phone': '+91 98000 00000', 'email': email, 'source': source, 'condition': 'Heart failure',
      'conditions': ['Heart failure', 'Type 2 diabetes'], 'allergies': ['Sulfa drugs'],
      'medications': [
        {'name': 'Furosemide', 'dose': '40 mg', 'schedule': 'Morning'},
      ],
      'records': [
        {'id': 'r1', 'title': 'Lab report', 'category': 'Lab report', 'date': '2026-10-07T00:00:00.000Z', 'forMember': 'self', 'fileName': 'l.pdf', 'sizeBytes': 10, 'notes': '', 'shared': true},
      ],
      'vitals': vitals, 'status': status, 'learned': source == 'example' ? 'Night dips are normal for her' : null, 'hasStore': hasStore,
    };

/// The care state as the service sends it.
Map<String, dynamic> careState({List<String> beds = const [], Map<String, dynamic>? extra, List<Map<String, dynamic>>? notes, Map<String, List<Map<String, dynamic>>>? visits, Map<String, String>? done, List<Map<String, dynamic>>? tasks}) {
  final now = DateTime.now();
  return {
    'patients': [
      patientJson('live', 'Jai', 'live', hasStore: true, email: 'patient@pulseos.app'),
      patientJson('acct-ria@x.in', 'Ria Sen', 'account', email: 'ria@x.in'),
      patientJson('ex-farhan', 'Farhan Ali', 'example', vitals: {'hr': 91, 'spo2': 94, 'temp': 36.9}, status: 'Watching'),
    ],
    'notes': notes ??
        [
          {'id': 'n1', 'patientId': 'live', 'at': now.subtract(const Duration(days: 2)).toUtc().toIso8601String(), 'kind': 'nursing', 'text': 'Wound clean.', 'by': 'Nurse Anjali Singh'},
          {'id': 'n2', 'patientId': 'live', 'at': now.subtract(const Duration(hours: 1)).toUtc().toIso8601String(), 'kind': 'note', 'text': 'Doing well.', 'by': 'Dr. Kavya Rao'},
          {'id': 'n3', 'patientId': 'ex-farhan', 'at': now.subtract(const Duration(days: 1)).toUtc().toIso8601String(), 'kind': 'consult', 'text': 'Weight up.', 'by': 'Dr. Kavya Rao'},
        ],
    'visits': visits ?? {},
    'slots': {
      for (var i = 0; i < 3; i++)
        key(day(i)): [DateTime(day(i).year, day(i).month, day(i).day, 10, 30).toUtc().toIso8601String(), DateTime(day(i).year, day(i).month, day(i).day, 9, 0).toUtc().toIso8601String()],
    },
    'beds': beds,
    'tasks': tasks ??
        [
          {'id': 'v08', 'hour': 8, 'title': {'t': 'Vitals round'}, 'detail': {'t': 'All occupied beds'}, 'kind': 'vitals'},
          {
            'id': 'm09',
            'hour': 9,
            'title': {'t': 'Morning medicines'},
            'detail': {'t': '{a}: metoprolol 25 mg · {b}: insulin before breakfast', 'a': {'a': 'B01 Ramesh Iyer', 'b': 'B02 Sunita Deshmukh'}},
            'kind': 'meds',
          },
        ],
    'done': done ?? {'v08': 'Dr. Kavya Rao · 9:05 AM'},
    'handovers': [
      {'at': now.subtract(const Duration(hours: 3)).toUtc().toIso8601String(), 'by': 'Nurse Anjali Singh', 'text': 'Bed 4 needs oxygen checks.'},
    ],
    ...?extra,
  };
}

/// A doctor in Demo Mode, whose calls go to [svc].
Future<Session> doctor(FakeService svc) async {
  svc.on('POST /demo/start', {'token': 'pd1.doc.sig', 'role': 'doctor', 'name': 'Dr. Kavya Rao', 'email': 'doctor@pulseos.app', 'expires_in': 1800});
  final s = Session(httpClient: svc.client);
  addTearDown(s.dispose);
  expect(await s.startDemo(Role.doctor), isNull);
  return s;
}

Future<(FakeService, ClinicalStore)> loaded({Map<String, dynamic>? state, bool disposeAtEnd = true}) async {
  final svc = FakeService();
  svc.on('GET /care/state', state ?? careState());
  final cs = ClinicalStore(await doctor(svc));
  if (disposeAtEnd) addTearDown(cs.dispose);
  await cs.load();
  return (svc, cs);
}

void main() {
  setUp(() => appLang.value = 'en');
  tearDown(() => appLang.value = 'en');

  group('loading', () {
    test('reads GET /care/state with the staff token', () async {
      final (svc, cs) = await loaded();
      expect(cs.loaded, isTrue);
      expect(cs.error, isNull);
      final req = svc.to('GET /care/state').single;
      expect(req.headers['Authorization'], 'Bearer pd1.doc.sig');
      expect(req.url.queryParameters, isEmpty);
    });

    test('patients, with their source, store flag, vitals and records', () async {
      final (_, cs) = await loaded();
      expect(cs.patients.map((p) => p.id), ['live', 'acct-ria@x.in', 'ex-farhan']);
      final jai = cs.byId(livePatientId)!;
      expect(jai.live, isTrue);
      expect(jai.source, PatientSource.live);
      expect(jai.hasStore, isTrue);
      expect(jai.email, 'patient@pulseos.app');
      expect(jai.medications.single.name, 'Furosemide');
      expect(jai.records.single.sizeBytes, 10);
      expect(jai.conditions, ['Heart failure', 'Type 2 diabetes']);
      expect(jai.vitals, isNull);

      final ria = cs.byId('acct-ria@x.in')!;
      expect(ria.source, PatientSource.account);
      expect(ria.hasStore, isFalse);

      final f = cs.byId('ex-farhan')!;
      expect(f.source, PatientSource.example);
      expect(f.vitals!.hr, 91);
      expect(f.vitals!.spo2, 94);
      expect(f.vitals!.temp, 36.9);
      expect(f.status, 'Watching');
      expect(f.learned, 'Night dips are normal for her');
      expect(f.bloodGroup, 'A+');
      expect(cs.byId('nobody'), isNull);
    });

    test('notes, newest first, per patient', () async {
      final (_, cs) = await loaded();
      expect(cs.notesFor('live').map((n) => n.id), ['n2', 'n1']);
      expect(cs.notesFor('ex-farhan').single.by, 'Dr. Kavya Rao');
      expect(cs.notesFor('acct-ria@x.in'), isEmpty);
      expect(cs.notesFor('live').first.at.isUtc, isFalse);
    });

    test('handovers and who did a task today', () async {
      final (_, cs) = await loaded();
      expect(cs.handovers.single.by, 'Nurse Anjali Singh');
      expect(cs.handovers.single.text, 'Bed 4 needs oxygen checks.');
      expect(cs.doneBy('v08'), 'Dr. Kavya Rao · 9:05 AM');
      expect(cs.doneBy('m09'), isNull);
      expect(cs.doneBy('v08', DateTime.now()), 'Dr. Kavya Rao · 9:05 AM');
      expect(cs.doneBy('v08', DateTime.now().subtract(const Duration(days: 1))), isNull, reason: 'the list is today\'s');
    });

    test('a service that is down leaves it not loaded, with the reason', () async {
      final svc = FakeService();
      svc.routes['GET /care/state'] = (_) => errorReply(503, 'unavailable', 'Waking up.');
      final cs = ClinicalStore(await doctor(svc));
      addTearDown(cs.dispose);
      await cs.load();
      expect(cs.loaded, isFalse);
      expect(cs.error, 'Waking up.');
      expect(cs.patients, isEmpty);
      svc.on('GET /care/state', careState());
      await cs.refreshPatients();
      expect(cs.error, isNull);
      expect(cs.patients.length, 3);
    });
  });

  group('the schedule', () {
    Map<String, dynamic> withVisits(List<(DateTime, Map<String, dynamic>)> v) {
      final byDay = <String, List<Map<String, dynamic>>>{};
      for (final (at, j) in v) {
        byDay.putIfAbsent(key(at), () => []).add(j);
      }
      return careState(visits: byDay);
    }

    test('visitsOn gives a day\'s visits by time', () async {
      final d = day(1);
      final nine = DateTime(d.year, d.month, d.day, 9), eleven = DateTime(d.year, d.month, d.day, 11), two = DateTime(d.year, d.month, d.day, 14, 30);
      final (_, cs) = await loaded(state: withVisits([
        (two, visitJson('v3', 'ex-farhan', two)),
        (nine, visitJson('v1', 'live', nine, name: 'Jai', byPatient: true)),
        (eleven, visitJson('v2', 'ex-farhan', eleven, video: true)),
      ]));
      final visits = cs.visitsOn(d);
      expect(visits.map((v) => v.id), ['v1', 'v2', 'v3']);
      expect(visits.first.bookedByPatient, isTrue);
      expect(visits.first.patientName, 'Jai');
      expect(visits[1].video, isTrue);
      expect(visits.first.at.isAtSameMomentAs(nine), isTrue);
      expect(cs.visitsOn(DateTime(d.year, d.month, d.day, 23, 59)).length, 3, reason: 'any time of that day');
      expect(cs.visitsOn(day(5)), isEmpty);
    });

    test('upcomingFor keeps this patient\'s upcoming visits from the last hour on, within two weeks', () async {
      final now = DateTime.now();
      final soon = now.add(const Duration(hours: 2));
      final justPast = now.subtract(const Duration(minutes: 30));
      final longPast = now.subtract(const Duration(hours: 2));
      final next = day(3).add(const Duration(hours: 10));
      final far = day(20).add(const Duration(hours: 10));
      final (_, cs) = await loaded(state: withVisits([
        (soon, visitJson('soon', 'ex-farhan', soon)),
        (justPast, visitJson('justPast', 'ex-farhan', justPast)),
        (longPast, visitJson('longPast', 'ex-farhan', longPast)),
        (next, visitJson('next', 'ex-farhan', next)),
        (next, visitJson('done', 'ex-farhan', next, status: 'completed')),
        (next, visitJson('other', 'live', next)),
        (far, visitJson('far', 'ex-farhan', far)),
      ]));
      expect(cs.upcomingFor('ex-farhan').map((v) => v.id).toSet(), {'soon', 'justPast', 'next'});
      expect(cs.upcomingFor('live').map((v) => v.id), ['other']);
    });

    test('visit statuses read as the app names them', () async {
      final d = day(1);
      final at = DateTime(d.year, d.month, d.day, 9);
      final (_, cs) = await loaded(state: withVisits([
        (at, visitJson('a', 'live', at, status: 'noShow')),
        (at, visitJson('b', 'live', at, status: 'no_show')),
        (at, visitJson('c', 'live', at, status: 'cancelled')),
        (at, visitJson('d', 'live', at, status: 'completed')),
        (at, visitJson('e', 'live', at, status: 'mystery')),
      ]));
      final byId = {for (final v in cs.visitsOn(d)) v.id: v.status};
      expect(byId, {'a': VisitStatus.noShow, 'b': VisitStatus.noShow, 'c': VisitStatus.cancelled, 'd': VisitStatus.completed, 'e': VisitStatus.upcoming});
    });

    test('the booking sheet\'s days and times come from the state', () async {
      final (_, cs) = await loaded();
      final days = cs.bookingDays();
      expect(days.map(key), [key(day(0)), key(day(1)), key(day(2))]);
      expect(days.first, day(0), reason: 'a calendar day in the phone\'s time zone');
      final slots = cs.bookingSlots(day(1));
      expect(slots.length, 2);
      expect(slots.first, DateTime(day(1).year, day(1).month, day(1).day, 9), reason: 'sorted');
      expect(slots.last, DateTime(day(1).year, day(1).month, day(1).day, 10, 30));
      expect(cs.bookingSlots(day(1).add(const Duration(hours: 15))).length, 2, reason: 'any time of that day names it');
      expect(cs.bookingSlots(day(9)), isEmpty);
    });

    test('times that have come within 15 minutes of now since the state was read are left out', () async {
      final now = DateTime.now();
      final past = now.subtract(const Duration(hours: 1)), tooSoon = now.add(const Duration(minutes: 5)), fine = now.add(const Duration(minutes: 25));
      final byDay = <String, List<String>>{};
      for (final t in [past, tooSoon, fine]) {
        byDay.putIfAbsent(key(t), () => []).add(t.toUtc().toIso8601String());
      }
      final (_, cs) = await loaded(state: careState(extra: {'slots': byDay}));
      final shown = [for (final t in [past, tooSoon, fine]) ...cs.bookingSlots(t)];
      expect(shown.toSet(), {fine});
      expect(cs.bookingDays().length, byDay.length, reason: 'the days stay listed; a day with nothing left shows the empty message');
    });
  });

  group('changes', () {
    test('a note goes to the service and the new state replaces ours', () async {
      final (svc, cs) = await loaded();
      final now = DateTime.now();
      svc.on('POST /care/notes', careState(notes: [
        {'id': 'n9', 'patientId': 'live', 'at': now.toUtc().toIso8601String(), 'kind': 'consult', 'text': 'Review in a week.', 'by': 'Dr. Kavya Rao'},
      ]));
      var notified = 0;
      cs.addListener(() => notified++);
      await cs.addNote('live', 'consult', '  Review in a week.  ');
      expect(svc.to('POST /care/notes').single.map, {'patient_id': 'live', 'kind': 'consult', 'text': 'Review in a week.'});
      expect(cs.notesFor('live').single.id, 'n9');
      expect(notified, greaterThanOrEqualTo(1));
      expect(cs.error, isNull);
    });

    test('a prescription says whether it reached the patient\'s own list', () async {
      final (svc, cs) = await loaded();
      svc.on('POST /care/prescribe', careState());
      final med = Medication(name: 'Aspirin', dose: '75 mg', schedule: 'Once daily');

      expect(await cs.prescribe(cs.byId('live')!, med, days: ' 5 '), isTrue, reason: 'the home patient has an account');
      expect(svc.to('POST /care/prescribe').single.map, {
        'patient_id': 'live',
        'medication': {'name': 'Aspirin', 'dose': '75 mg', 'schedule': 'Once daily'},
        'days': '5',
      });
      expect(await cs.prescribe(cs.byId('ex-farhan')!, med), isFalse, reason: 'an example patient has no list of their own');
      expect(await cs.prescribe(cs.byId('acct-ria@x.in')!, med), isFalse, reason: 'a new patient has no saved data yet');

      svc.routes['POST /care/prescribe'] = (_) => errorReply(403, 'forbidden', 'Staff only.');
      expect(await cs.prescribe(cs.byId('live')!, med), isFalse);
      expect(cs.error, 'Staff only.');
    });

    test('a visit\'s new status shows at once; a refusal puts it back', () async {
      final d = day(1);
      final at = DateTime(d.year, d.month, d.day, 9);
      final state = careState(visits: {key(at): [visitJson('v1', 'live', at, name: 'Jai')]});
      final (svc, cs) = await loaded(state: state);
      final v = cs.visitsOn(d).single;
      final gate = Completer<void>();
      svc.routes['POST /care/visits/v1/status'] = (_) async {
        await gate.future;
        return jsonReply(careState(visits: {key(at): [visitJson('v1', 'live', at, name: 'Jai', status: 'completed')]}));
      };
      final f = cs.setVisitStatus(v, VisitStatus.completed, note: '  Seen. ');
      expect(v.status, VisitStatus.completed);
      gate.complete();
      await f;
      expect(svc.to('POST /care/visits/v1/status').single.map, {'status': 'completed', 'note': 'Seen.'});
      expect(cs.visitsOn(d).single.status, VisitStatus.completed);

      svc.routes['POST /care/visits/v1/status'] = (_) => errorReply(422, 'invalid', 'Cannot change that.');
      final again = cs.visitsOn(d).single;
      await cs.setVisitStatus(again, VisitStatus.noShow);
      expect(again.status, VisitStatus.completed, reason: 'put back');
      expect(cs.error, 'Cannot change that.');
      expect(svc.to('POST /care/visits/v1/status').last.map['status'], 'noShow');
    });

    test('booking sends the time in UTC and gives an empty reason a default', () async {
      final (svc, cs) = await loaded();
      svc.on('POST /care/visits', careState());
      final at = DateTime(day(1).year, day(1).month, day(1).day, 10, 30);
      await cs.book(cs.byId('ex-farhan')!, at, '   ', video: true);
      await cs.book(cs.byId('live')!, at, ' Follow-up after alert ', video: false);
      final sent = svc.to('POST /care/visits');
      expect(sent.first.map, {'patient_id': 'ex-farhan', 'at': at.toUtc().toIso8601String(), 'reason': 'Follow-up', 'video': true});
      expect(sent.first.map['at'], endsWith('Z'));
      expect(sent.last.map['reason'], 'Follow-up after alert');
      expect(sent.last.map['video'], isFalse);
    });

    test('ticking off a task and writing a handover', () async {
      final (svc, cs) = await loaded();
      svc.on('POST /care/tasks/m09/toggle', careState(done: {'v08': 'Dr. Kavya Rao · 9:05 AM', 'm09': 'Nurse Anjali Singh · 9:40 AM'}));
      await cs.toggleTask('m09');
      expect(cs.doneBy('m09'), 'Nurse Anjali Singh · 9:40 AM');
      expect(svc.to('POST /care/tasks/m09/toggle').single.body, isEmpty);

      svc.routes['POST /care/handovers'] = (r) => jsonReply({
            ...careState(),
            'handovers': [
              {'at': DateTime.now().toUtc().toIso8601String(), 'by': 'Nurse Anjali Singh', 'text': r.map['text']},
            ],
          });
      await cs.addHandover('  All stable.  ');
      expect(svc.to('POST /care/handovers').single.map, {'text': 'All stable.'});
      expect(cs.handovers.single.text, 'All stable.');
    });

    test('a refused change leaves the state as it was', () async {
      final (svc, cs) = await loaded();
      svc.routes['POST /care/notes'] = (_) => errorReply(422, 'invalid', 'Write something.');
      await cs.addNote('live', 'note', '');
      expect(cs.error, 'Write something.');
      expect(cs.notesFor('live').length, 2);
      expect(cs.patients.length, 3);
    });

    test('requests go one at a time, in order', () async {
      final (svc, cs) = await loaded();
      final gate = Completer<void>();
      svc.routes['POST /care/handovers'] = (_) async {
        await gate.future;
        return jsonReply(careState());
      };
      svc.on('POST /care/tasks/m09/toggle', careState());
      final a = cs.addHandover('first');
      final b = cs.toggleTask('m09');
      await settle();
      expect(svc.to('POST /care/tasks/m09/toggle'), isEmpty, reason: 'waits for the first answer');
      gate.complete();
      await Future.wait([a, b]);
      expect(svc.to('POST /care/tasks/m09/toggle').length, 1);
    });
  });

  group('nursing tasks', () {
    test('come with their text as messages, so they follow the language', () async {
      final (_, cs) = await loaded();
      final tasks = cs.tasksFor(const []);
      expect(tasks.map((t) => t.id), ['v08', 'm09']);
      expect(tasks.first.hour, 8);
      expect(tasks.first.kind, 'vitals');
      expect(tasks.first.title, 'Vitals round');
      expect(tasks.last.detail, 'B01 Ramesh Iyer: metoprolol 25 mg · B02 Sunita Deshmukh: insulin before breakfast');
      appLang.value = 'hi';
      expect(tasks.first.title, 'वाइटल्स राउंड');
      expect(tasks.last.detail, 'B01 Ramesh Iyer: मेटोप्रोलोल 25 mg · B02 Sunita Deshmukh: नाश्ते से पहले इंसुलिन');
    });

    test('a new list of beds is asked for once, after a short pause', () async {
      final (svc, cs) = await loaded();
      final beds = ['B01 Ramesh Iyer', 'B02 Sunita Deshmukh', 'B03 Imran Shaikh'];
      svc.routes['GET /care/state'] = (r) => jsonReply(careState(beds: (r.url.queryParameters['beds'] ?? '').split(',').where((b) => b.isNotEmpty).toList(), tasks: [
            {'id': 'v08', 'hour': 8, 'title': {'t': 'Vitals round'}, 'detail': 'for ${r.url.queryParameters['beds']}', 'kind': 'vitals'},
          ]));
      var notified = 0;
      cs.addListener(() => notified++);

      final first = cs.tasksFor(beds);
      expect(first.length, 2, reason: 'the tasks we have, meanwhile');
      cs.tasksFor(beds);
      cs.tasksFor(beds);
      await settle(40);
      expect(svc.to('GET /care/state').length, 1, reason: 'still waiting: 300 ms has not passed');
      await until(() => svc.to('GET /care/state').length == 2, reason: 'the refetch');
      await until(() => cs.tasksFor(beds).first.detail.startsWith('for '));

      final asked = svc.to('GET /care/state').last;
      expect(asked.url.queryParameters['beds'], 'B01 Ramesh Iyer,B02 Sunita Deshmukh,B03 Imran Shaikh');
      expect(cs.tasksFor(beds).single.detail, 'for B01 Ramesh Iyer,B02 Sunita Deshmukh,B03 Imran Shaikh');
      expect(notified, greaterThanOrEqualTo(1));

      // The same beds again, many times (this is called while building): nothing more is asked.
      for (var i = 0; i < 5; i++) {
        cs.tasksFor(beds);
      }
      await settle(450);
      expect(svc.to('GET /care/state').length, 2);
    });

    test('a change made after the tasks were built for the ward\'s beds keeps those tasks', () async {
      final (svc, cs) = await loaded();
      final beds = ['B01 Ramesh Iyer', 'B02 Sunita Deshmukh'];
      Map<String, dynamic> state(String detail, {Map<String, String>? done}) => careState(done: done, tasks: [
            {'id': 'v08', 'hour': 8, 'title': {'t': 'Vitals round'}, 'detail': detail, 'kind': 'vitals'},
          ]);
      svc.routes['GET /care/state'] = (r) => jsonReply(state('for ${r.url.queryParameters['beds'] ?? 'no beds'}'));
      // A change is sent with no beds, so the answer holds tasks for none.
      svc.routes['POST /care/tasks/v08/toggle'] = (_) => jsonReply(state('for no beds', done: {'v08': 'Nurse Anjali Singh · 9:40 AM'}));
      cs.tasksFor(beds);
      await until(() => cs.tasksFor(beds).length == 1 && cs.tasksFor(beds).first.detail == 'for B01 Ramesh Iyer,B02 Sunita Deshmukh', reason: 'the tasks for these beds');

      await cs.toggleTask('v08');
      expect(cs.doneBy('v08'), 'Nurse Anjali Singh · 9:40 AM', reason: 'the rest of the answer is taken');
      expect(cs.tasksFor(beds).single.detail, 'for B01 Ramesh Iyer,B02 Sunita Deshmukh', reason: 'but not tasks built for other beds');
      await settle(450);
      expect(svc.to('GET /care/state').length, 2, reason: 'and nothing is asked again');
    });

    test('with no beds asked for, a change\'s answer brings its tasks too', () async {
      final (svc, cs) = await loaded();
      svc.on('POST /care/handovers', careState(tasks: [
        {'id': 'x1', 'hour': 7, 'title': 'New task', 'detail': 'Plain text', 'kind': 'check'},
      ]));
      await cs.addHandover('Hello');
      expect(cs.tasksFor(const []).single.title, 'New task');
    });

    test('does not ask again when the service shows other beds back than it was asked for', () async {
      final (svc, cs) = await loaded();
      final beds = ['B01 Ramesh Iyer'];
      // The service leaves `beds` out of its answer.
      svc.on('GET /care/state', careState(beds: const []));
      cs.tasksFor(beds);
      await until(() => svc.to('GET /care/state').length == 2);
      for (var i = 0; i < 4; i++) {
        cs.tasksFor(beds);
        await settle(120);
      }
      await settle(400);
      expect(svc.to('GET /care/state').length, 2, reason: 'no loop');
    });

    test('does not ask when the state is already for these beds', () async {
      final (svc, cs) = await loaded(state: careState(beds: ['B01', 'B02']));
      cs.tasksFor(['B01', 'B02']);
      await settle(450);
      expect(svc.to('GET /care/state').length, 1);
    });

    test('only the last list is asked for when it changes during the pause', () async {
      final (svc, cs) = await loaded();
      cs.tasksFor(['B01']);
      await settle(30);
      cs.tasksFor(['B01', 'B02']);
      await until(() => svc.to('GET /care/state').length == 2);
      await settle(450);
      expect(svc.to('GET /care/state').length, 2);
      expect(svc.to('GET /care/state').last.url.queryParameters['beds'], 'B01,B02');
    });

    test('nothing is asked after dispose', () async {
      final (svc, cs) = await loaded(disposeAtEnd: false);
      cs.tasksFor(['B07']);
      cs.dispose();
      await settle(450);
      expect(svc.to('GET /care/state').length, 1);
    });
  });
}
