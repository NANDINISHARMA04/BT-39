import 'dart:async';

import 'package:bt39_care/models/patient_models.dart';
import 'package:bt39_care/services/patient_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map<String, dynamic> profileJson({String name = 'Jai'}) => {
      'name': name, 'email': 'patient@pulseos.app', 'phone': '+91 98100 12345', 'age': 24, 'sex': 'M', 'bloodGroup': 'B+', 'heightCm': 174, 'weightKg': 66.0,
      'city': 'Noida', 'conditions': ['Mild asthma'], 'allergies': ['Penicillin'],
      'medications': [
        {'name': 'Aspirin', 'dose': '75 mg', 'schedule': 'Once daily'},
      ],
    };

Map<String, dynamic> memberJson(String id, {String name = 'Sunita Sharma', bool caregiver = false, bool emergency = false}) =>
    {'id': id, 'name': name, 'relation': 'Mother', 'age': 50, 'bloodGroup': 'B+', 'phone': '+91 98111 22334', 'conditions': <String>[], 'caregiver': caregiver, 'emergencyContact': emergency};

Map<String, dynamic> apptJson(String id, DateTime at, {String status = 'upcoming', String forMember = 'self', String doctorId = 'd1'}) =>
    {'id': id, 'doctorId': doctorId, 'forMember': forMember, 'at': at.toUtc().toIso8601String(), 'mode': 'video', 'reason': 'Review', 'notes': '', 'status': status, 'fromAlert': null};

Map<String, dynamic> claimJson(String id, {List<String> recordIds = const [], String policyId = 'p1'}) => {
      'id': id, 'policyId': policyId, 'title': 'Surgery', 'hospital': 'Fortis', 'amount': 420000, 'approved': null, 'forMember': 'self', 'recordIds': recordIds,
      'timeline': [
        {'status': 'submitted', 'at': '2026-10-07T03:30:00.000Z', 'note': ''},
      ],
    };

/// The patient document as the service sends it.
Map<String, dynamic> docJson({List<Map<String, dynamic>>? family, List<Map<String, dynamic>>? appointments, List<Map<String, dynamic>>? claims, String name = 'Jai'}) => {
      'profile': profileJson(name: name),
      'family': family ?? [memberJson('f1', caregiver: true, emergency: true), memberJson('f2', name: 'Rajesh Sharma')],
      'appointments': appointments ?? [apptJson('a1', DateTime.now().add(const Duration(days: 1)))],
      'records': [
        {'id': 'r1', 'title': 'Discharge summary', 'category': 'Discharge summary', 'date': '2026-10-07T00:00:00.000Z', 'forMember': 'self', 'fileName': 'd.pdf', 'sizeBytes': 482113, 'notes': '', 'shared': true},
      ],
      'policies': [
        {'id': 'p1', 'insurer': 'Star Health', 'plan': 'Family Optima', 'policyNo': 'SH-1', 'sumInsured': 1000000, 'validTill': '2027-03-31T00:00:00.000Z', 'members': ['self'], 'cashless': true, 'premium': 28400},
      ],
      'claims': claims ?? [claimJson('c1', recordIds: ['r1'])],
      'prefs': {'theme': 'system', 'fahrenheit': false, 'notifications': true, 'autoSos': true, 'shareWithCareTeam': true, 'caregiverEscalation': true, 'language': 'English'},
    };

Map<String, dynamic> doctorJson(String id, String name) => {
      'id': id, 'name': name, 'specialty': 'Cardiologist', 'hospital': 'Fortis', 'city': 'Noida', 'years': 14, 'rating': 4.9, 'reviews': 612, 'fee': 900,
      'languages': ['English', 'Hindi'], 'video': true, 'clinic': true, 'nextFreeDays': 0, 'about': 'Heart.', 'distanceKm': 3.2,
    };

String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A service with a patient document that changes the way the real one does.
FakeService service({Map<String, dynamic>? doc}) {
  final svc = FakeService();
  svc.on('GET /me/data', doc ?? docJson());
  svc.on('GET /doctors', {
    'doctors': [doctorJson('d1', 'Dr. Kavya Rao'), doctorJson('d2', 'Dr. Arjun Malhotra')],
    'specialties': ['Cardiologist'],
  });
  return svc;
}

Future<PatientStore> loaded(FakeService svc, {String account = 'acct-1'}) async {
  final s = PatientStore();
  addTearDown(s.dispose);
  await s.load(svc.api(), account, name: 'Jai', email: 'patient@pulseos.app');
  expect(s.loaded, isTrue);
  return s;
}

void main() {
  setUp(() => doctorCatalog.clear());

  group('loading', () {
    test('reads the document and the doctors', () async {
      final svc = service();
      final s = PatientStore();
      final notes = <bool>[];
      s.addListener(() => notes.add(s.loaded));
      final f = s.load(svc.api(), 'acct-1', name: 'Jai', email: 'patient@pulseos.app', details: {'age': '24', 'sex': 'M'});
      expect(s.loaded, isFalse, reason: 'false from the first moment');
      await f;
      expect(s.loaded, isTrue);
      expect(notes.last, isTrue);
      expect(s.error, isNull);

      expect(s.profile.name, 'Jai');
      expect(s.profile.heightCm, 174.0);
      expect(s.profile.medications.single.name, 'Aspirin');
      expect(s.family.map((m) => m.id), ['f1', 'f2']);
      expect(s.appointments.single.id, 'a1');
      expect(s.records.single.sizeBytes, 482113);
      expect(s.policies.single.sumInsured, 1000000);
      expect(s.claims.single.recordIds, ['r1']);
      expect(s.prefs.autoSos, isTrue);

      expect(doctorCatalog.map((d) => d.id), ['d1', 'd2']);
      expect(doctorById('d2').name, 'Dr. Arjun Malhotra');
      expect(doctorById('nope').id, 'd1', reason: 'the first doctor stands in for an unknown one');
      expect(svc.seen.map((r) => r.route).toSet(), {'GET /me/data', 'GET /doctors'});
      expect(svc.seen.first.headers['Authorization'], 'Bearer test-token');
    });

    test('does not tell listeners before it returns control, because the app starts it from initState', () async {
      final svc = service();
      final s = PatientStore();
      addTearDown(s.dispose);
      var told = 0;
      s.addListener(() => told++);
      final f = s.load(svc.api(), 'acct-1', name: 'Jai');
      expect(told, 0, reason: 'a listener that marks a page dirty during build would throw');
      expect(s.loaded, isFalse);
      await f;
      expect(told, greaterThanOrEqualTo(1));
    });

    test('a second load starts again from not loaded', () async {
      final svc = service();
      final s = await loaded(svc);
      final f = s.load(svc.api(), 'acct-2', name: 'Other');
      expect(s.loaded, isFalse);
      expect(s.profile.name, 'Other', reason: 'a placeholder until the document arrives');
      expect(s.family, isEmpty);
      await f;
      expect(s.loaded, isTrue);
    });

    test('a service that is down leaves it unloaded with the reason, and reload tries again', () async {
      final svc = FakeService();
      svc.routes['GET /me/data'] = (_) => errorReply(503, 'unavailable', 'Waking up.');
      svc.on('GET /doctors', {'doctors': [doctorJson('d1', 'Dr. Kavya Rao')]});
      final s = PatientStore();
      addTearDown(s.dispose);
      await s.load(svc.api(), 'acct-1', name: 'Jai');
      expect(s.loaded, isFalse);
      expect(s.error, 'Waking up.');

      svc.on('GET /me/data', docJson());
      await s.reload();
      expect(s.loaded, isTrue);
      expect(s.error, isNull);
      expect(s.profile.name, 'Jai');
    });

    test('a slow answer for the last account does not land in the next one', () async {
      final slow = Completer<void>();
      final svc = service(doc: docJson(name: 'Account two'));
      var first = true;
      svc.routes['GET /me/data'] = (_) async {
        if (first) {
          first = false;
          await slow.future;
          return jsonReply(docJson(name: 'Account one'));
        }
        return jsonReply(docJson(name: 'Account two'));
      };
      final s = PatientStore();
      addTearDown(s.dispose);
      final one = s.load(svc.api(), 'one', name: 'x');
      await s.load(svc.api(), 'two', name: 'y');
      expect(s.profile.name, 'Account two');
      slow.complete();
      await one;
      expect(s.profile.name, 'Account two');
      expect(s.loaded, isTrue);
    });

    test('times come back in the phone\'s time zone and go out in UTC', () async {
      final at = DateTime.utc(2026, 10, 14, 3, 30);
      final svc = service(doc: docJson(appointments: [apptJson('a1', at)]));
      final s = await loaded(svc);
      final a = s.appointments.single;
      expect(a.at.isUtc, isFalse);
      expect(a.at.isAtSameMomentAs(at), isTrue);

      svc.on('PUT /me/appointments/a1', docJson(appointments: [apptJson('a1', at)]));
      await s.upsertAppointment(a);
      final sent = svc.to('PUT /me/appointments/a1').single.map;
      expect(sent['at'], '2026-10-14T03:30:00.000Z');
      expect(sent['mode'], 'video');
    });
  });

  group('changes show at once, then the service\'s document replaces them', () {
    test('a new family member', () async {
      final svc = service();
      final gate = Completer<void>();
      svc.routes['PUT /me/family/f3'] = (r) async {
        await gate.future;
        // The service keeps one caregiver: the new one takes over from f1.
        return jsonReply(docJson(family: [memberJson('f1', caregiver: false, emergency: true), memberJson('f2', name: 'Rajesh Sharma'), memberJson('f3', name: 'Ishaan Sharma', caregiver: true)]));
      };
      final s = await loaded(svc);
      var notified = 0;
      s.addListener(() => notified++);
      final mine = FamilyMember(id: 'f3', name: 'Ishaan Sharma', relation: 'Brother', age: 12, caregiver: true);

      final f = s.upsertMember(mine);
      // Before the service has answered:
      expect(s.family.map((m) => m.id), ['f1', 'f2', 'f3']);
      expect(identical(s.family.last, mine), isTrue);
      expect(notified, 1);
      expect(s.family.first.caregiver, isTrue, reason: 'not yet corrected');

      gate.complete();
      await f;
      expect(svc.to('PUT /me/family/f3').single.map['name'], 'Ishaan Sharma');
      expect(identical(s.family.last, mine), isFalse, reason: 'the service\'s document replaced the local one');
      expect(s.family.last.caregiver, isTrue);
      expect(s.family.first.caregiver, isFalse, reason: 'one caregiver at most');
      expect(s.caregiver!.id, 'f3');
      expect(s.error, isNull);
      expect(notified, greaterThanOrEqualTo(2));
    });

    test('profile and preferences', () async {
      final svc = service();
      svc.on('PUT /me/profile', docJson(name: 'Jai S.'));
      svc.on('PUT /me/prefs', docJson());
      final s = await loaded(svc);
      final f = s.updateProfile((p) => p.name = 'Jai S.');
      expect(s.profile.name, 'Jai S.');
      await f;
      expect(svc.to('PUT /me/profile').single.map['name'], 'Jai S.');
      final g = s.updatePrefs((p) => p.fahrenheit = true);
      expect(s.prefs.fahrenheit, isTrue, reason: 'shown at once');
      await g;
      expect(svc.to('PUT /me/prefs').single.map['fahrenheit'], isTrue);
      expect(s.prefs.fahrenheit, isFalse, reason: 'this stub service answers with false, and its document is the truth');
    });

    test('a refused change is shown, then the saved document is read again', () async {
      final svc = service();
      svc.routes['PUT /me/family/f3'] = (_) => errorReply(422, 'invalid', 'Add a name.');
      final s = await loaded(svc);
      final f = s.upsertMember(FamilyMember(id: 'f3', name: '', relation: '', age: 0));
      expect(s.family.length, 3, reason: 'shown at once');
      await f;
      expect(s.error, 'Add a name.');
      expect(s.family.map((m) => m.id), ['f1', 'f2'], reason: 'what is really saved');
      expect(svc.to('GET /me/data').length, 2, reason: 'once to load, once to put it right');

      svc.on('PUT /me/family/f2', docJson());
      await s.upsertMember(s.family.last);
      expect(s.error, isNull, reason: 'cleared by the next one that works');
    });

    test('changes go one at a time and the first answer does not undo the second', () async {
      final svc = service();
      final gate = Completer<void>();
      svc.routes['PUT /me/family/f3'] = (_) async {
        await gate.future;
        return jsonReply(docJson(family: [memberJson('f1'), memberJson('f2'), memberJson('f3', name: 'Third')]));
      };
      svc.routes['PUT /me/family/f4'] = (_) => jsonReply(docJson(family: [memberJson('f1'), memberJson('f2'), memberJson('f3', name: 'Third'), memberJson('f4', name: 'Fourth')]));
      final s = await loaded(svc);

      final a = s.upsertMember(FamilyMember(id: 'f3', name: 'Third', relation: '', age: 1));
      final b = s.upsertMember(FamilyMember(id: 'f4', name: 'Fourth', relation: '', age: 2));
      await settle();
      expect(svc.to('PUT /me/family/f4'), isEmpty, reason: 'waits its turn');

      gate.complete();
      await a;
      expect(s.family.map((m) => m.id), contains('f4'), reason: 'the answer to the first has no f4, so it must not replace the list yet');
      await b;
      expect(s.family.map((m) => m.id), ['f1', 'f2', 'f3', 'f4']);
      expect(s.family.last.name, 'Fourth');
    });

    test('deleting a family member cancels their appointments', () async {
      final svc = service(doc: docJson(appointments: [apptJson('a1', DateTime.now().add(const Duration(days: 1)), forMember: 'f2'), apptJson('a2', DateTime.now().add(const Duration(days: 2)))]));
      svc.routes['DELETE /me/family/f2'] = (_) => jsonReply(docJson(family: [memberJson('f1')], appointments: [apptJson('a1', DateTime.now().add(const Duration(days: 1)), forMember: 'f2', status: 'cancelled'), apptJson('a2', DateTime.now().add(const Duration(days: 2)))]));
      final s = await loaded(svc);
      final f = s.deleteMember('f2');
      expect(s.family.map((m) => m.id), ['f1']);
      expect(s.appointments.first.status, ApptStatus.cancelled);
      expect(s.appointments.last.status, ApptStatus.upcoming);
      expect(s.memberName('f2'), 'Removed member');
      await f;
      expect(s.upcoming.map((a) => a.id), ['a2']);
    });

    test('appointments: book, cancel, delete', () async {
      final svc = service();
      final s = await loaded(svc);
      final at = DateTime.now().add(const Duration(days: 3));
      svc.on('PUT /me/appointments/a9', docJson(appointments: [apptJson('a1', DateTime.now().add(const Duration(days: 1))), apptJson('a9', at)]));
      await s.upsertAppointment(Appointment(id: 'a9', doctorId: 'd2', forMember: 'self', at: at, mode: ApptMode.clinic, reason: 'Fever'));
      expect(s.upcoming.map((a) => a.id), ['a1', 'a9'], reason: 'soonest first');

      svc.on('POST /me/appointments/a9/cancel', docJson(appointments: [apptJson('a1', DateTime.now().add(const Duration(days: 1))), apptJson('a9', at, status: 'cancelled')]));
      final f = s.cancelAppointment('a9');
      expect(s.appointments.last.status, ApptStatus.cancelled);
      await f;
      expect(s.past.map((a) => a.id), ['a9']);
      expect(svc.to('POST /me/appointments/a9/cancel').single.body, isEmpty);

      svc.on('DELETE /me/appointments/a9', docJson());
      await s.deleteAppointment('a9');
      expect(s.appointments.map((a) => a.id), ['a1']);
    });

    test('records, policies and claims keep each other in step', () async {
      final svc = service();
      final s = await loaded(svc);

      svc.on('DELETE /me/records/r1', docJson(claims: [claimJson('c1')]));
      final del = s.deleteRecord('r1');
      expect(s.records, isEmpty);
      expect(s.claims.single.recordIds, isEmpty, reason: 'unlinked at once');
      await del;

      svc.on('PUT /me/records/r2', docJson());
      final rec = MedicalRecord(id: 'r2', title: 'X-ray', category: 'Imaging', date: DateTime.utc(2026, 10, 1), forMember: 'self', fileName: 'x.jpg', sizeBytes: 10);
      final up = s.upsertRecord(rec);
      expect(s.records.first.id, 'r2', reason: 'a new record goes to the top');
      await up;
      expect(svc.to('PUT /me/records/r2').single.map['date'], '2026-10-01T00:00:00.000Z');

      svc.on('DELETE /me/policies/p1', docJson(claims: []));
      final dp = s.deletePolicy('p1');
      expect(s.policies, isEmpty);
      expect(s.claims, isEmpty, reason: 'its claims go with it');
      await dp;

      svc.on('PUT /me/policies/p2', docJson());
      await s.upsertPolicy(InsurancePolicy(id: 'p2', insurer: 'Acko', plan: 'P', policyNo: '1', sumInsured: 500000, validTill: DateTime.utc(2027, 1, 1)));
      expect(svc.to('PUT /me/policies/p2').single.map['validTill'], '2027-01-01T00:00:00.000Z');

      svc.on('PUT /me/claims/c9', docJson(claims: [claimJson('c9')]));
      await s.upsertClaim(Claim(id: 'c9', policyId: 'p1', title: 'OPD', hospital: 'H', amount: 6800, forMember: 'self', timeline: [ClaimEvent(ClaimStatus.submitted, DateTime.now())]));
      expect(svc.to('PUT /me/claims/c9').single.map['timeline'], isNotEmpty);

      svc.on('DELETE /me/claims/c9', docJson(claims: []));
      await s.deleteClaim('c9');
      expect(s.claims, isEmpty);
    });

    test('moving a claim along shows at once', () async {
      final svc = service();
      final s = await loaded(svc);
      final c = s.claims.single;
      expect(c.status, ClaimStatus.submitted);
      svc.routes['POST /me/claims/c1/advance'] = (_) => jsonReply(docJson(claims: [
            {
              ...claimJson('c1', recordIds: ['r1']),
              'timeline': [
                {'status': 'submitted', 'at': '2026-10-07T03:30:00.000Z', 'note': ''},
                {'status': 'underReview', 'at': '2026-10-13T03:30:00.000Z', 'note': 'Documents received'},
              ],
            }
          ]));
      final f = s.advanceClaim(c);
      expect(c.status, ClaimStatus.underReview);
      await f;
      expect(s.claims.single.status, ClaimStatus.underReview);
      expect(s.claims.single.timeline.last.note, 'Documents received');
      expect(s.usedOf(s.policies.single), 0);
    });

    test('the same object stays a different one after the document replaces it, but the lists are the store\'s', () async {
      final svc = service();
      final s = await loaded(svc);
      final before = s.family;
      svc.on('PUT /me/family/f1', docJson());
      await s.upsertMember(s.family.first);
      expect(identical(s.family, before), isFalse);
    });
  });

  group('free times', () {
    DateTime atLocal(DateTime day, int h, int m) => DateTime(day.year, day.month, day.day, h, m);

    test('are fetched once per doctor and arrive with a notification', () async {
      final svc = service();
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final soon = today.add(const Duration(minutes: 45)); // may be tomorrow, near midnight
      svc.on('GET /doctors/d1/slots', {
        'days': {
          dayKey(soon): [soon.toUtc().toIso8601String()],
          dayKey(tomorrow): [atLocal(tomorrow, 9, 0).toUtc().toIso8601String(), atLocal(tomorrow, 9, 30).toUtc().toIso8601String()],
        },
      });
      final s = await loaded(svc);
      final d1 = doctorById('d1');
      var notified = 0;
      s.addListener(() => notified++);

      expect(s.slotsFor(d1, tomorrow), isEmpty, reason: 'nothing yet');
      expect(s.slotsLoading(d1), isTrue);
      await until(() => !s.slotsLoading(d1), reason: 'the times');
      expect(notified, greaterThanOrEqualTo(1));

      final slots = s.slotsFor(d1, tomorrow);
      expect(slots.length, dayKey(soon) == dayKey(tomorrow) ? 3 : 2);
      expect(slots.where((x) => x.hour == 9).first, atLocal(tomorrow, 9, 0));
      expect(slots.first.isUtc, isFalse);
      expect(s.slotsFor(d1, DateTime(2020, 1, 1)), isEmpty, reason: 'a day with none');
      expect(s.slotsFor(d1, soon).contains(soon), isTrue);

      final asked = svc.to('GET /doctors/d1/slots');
      expect(asked.length, 1, reason: 'fetched once, however often it is asked');
      expect(asked.single.url.queryParameters, {'from': dayKey(today), 'days': '14'});
      expect(asked.single.headers['X-Tz-Offset'], '${DateTime.now().timeZoneOffset.inMinutes}');
    });

    test('leave out times that have come within 30 minutes of now since they were fetched', () async {
      final svc = service();
      final now = DateTime.now();
      final tooSoon = now.add(const Duration(minutes: 10)), fine = now.add(const Duration(minutes: 50)), past = now.subtract(const Duration(minutes: 40));
      final all = [past, tooSoon, fine];
      final byDay = <String, List<String>>{};
      for (final t in all) {
        byDay.putIfAbsent(dayKey(t), () => []).add(t.toUtc().toIso8601String());
      }
      svc.on('GET /doctors/d1/slots', {'days': byDay});
      final s = await loaded(svc);
      final d1 = doctorById('d1');
      s.slotsFor(d1, now);
      await until(() => !s.slotsLoading(d1));
      final shown = [for (final t in all) ...s.slotsFor(d1, t)];
      expect(shown.toSet(), {fine});
    });

    test('are kept separately for another doctor and for moving an appointment', () async {
      final svc = service();
      svc.on('GET /doctors/d1/slots', {'days': {}});
      svc.on('GET /doctors/d2/slots', {'days': {}});
      final s = await loaded(svc);
      final d1 = doctorById('d1'), d2 = doctorById('d2');
      final today = DateTime.now();
      s.slotsFor(d1, today);
      s.slotsFor(d1, today, exceptAppt: 'a1');
      s.slotsFor(d2, today);
      await until(() => !s.slotsLoading(d1) && !s.slotsLoading(d2) && !s.slotsLoading(d1, exceptAppt: 'a1'));
      expect(svc.to('GET /doctors/d1/slots').length, 2);
      expect(svc.to('GET /doctors/d2/slots').length, 1);
      expect(svc.to('GET /doctors/d1/slots').map((r) => r.url.queryParameters['except']), [null, 'a1']);
    });

    test('are fetched again after an appointment changes', () async {
      final svc = service();
      svc.on('GET /doctors/d1/slots', {'days': {}});
      svc.on('PUT /me/appointments/a9', docJson());
      final s = await loaded(svc);
      final d1 = doctorById('d1');
      s.slotsFor(d1, DateTime.now());
      await until(() => !s.slotsLoading(d1));
      await s.upsertAppointment(Appointment(id: 'a9', doctorId: 'd1', forMember: 'self', at: DateTime.now().add(const Duration(days: 2)), mode: ApptMode.video, reason: 'x'));
      expect(s.slotsLoading(d1), isTrue, reason: 'the old times may include the one just booked');
      s.slotsFor(d1, DateTime.now());
      await until(() => !s.slotsLoading(d1));
      expect(svc.to('GET /doctors/d1/slots').length, 2);
    });

    test('a service that cannot answer leaves no times and does not hang the page', () async {
      final svc = service();
      svc.routes['GET /doctors/d1/slots'] = (_) => errorReply(503, 'unavailable', 'Waking up.');
      final s = await loaded(svc);
      final d1 = doctorById('d1');
      expect(s.slotsFor(d1, DateTime.now()), isEmpty);
      await until(() => !s.slotsLoading(d1), reason: 'to stop loading');
      expect(s.slotsFor(d1, DateTime.now()), isEmpty);
      expect(svc.to('GET /doctors/d1/slots').length, 1, reason: 'not asked again at once');
    });
  });

  group('SOS', () {
    test('startSos sends the alert and returns who was told', () async {
      final svc = service();
      svc.on('POST /sos', {
        'id': 's1',
        'contacts': [
          {'id': 'f1', 'name': 'Sunita Sharma', 'delivered_ms': 1200, 'seen_ms': 4500},
          {'id': 'f2', 'name': 'Rajesh Sharma', 'delivered_ms': 1500, 'seen_ms': 9000},
        ],
        'location': 'Sector 62, Noida',
      });
      svc.on('POST /sos/s1/end', {'ok': true});
      final s = await loaded(svc);
      final plan = await s.startSos(alertId: 4);
      expect(svc.to('POST /sos').single.map, {'alert_id': 4});
      expect(plan!.id, 's1');
      expect(plan.location, 'Sector 62, Noida');
      expect(plan.contacts.map((c) => c.name), ['Sunita Sharma', 'Rajesh Sharma']);
      expect(plan.contacts.first.id, 'f1');
      expect(plan.contacts.first.deliveredMs, 1200);
      expect(plan.contacts.first.seenMs, 4500);

      await s.endSos(plan.id);
      expect(svc.to('POST /sos/s1/end').length, 1);

      await s.startSos();
      expect(svc.to('POST /sos').last.map, {'alert_id': null});
    });

    test('a refused SOS gives null and the reason', () async {
      final svc = service();
      svc.routes['POST /sos'] = (_) => errorReply(429, 'rate_limited', 'Slow down.');
      final s = await loaded(svc);
      expect(await s.startSos(), isNull);
      expect(s.error, 'Slow down.');
    });
  });

  group('what stays on the phone', () {
    test('new ids are different', () {
      final s = PatientStore();
      addTearDown(s.dispose);
      expect({for (var i = 0; i < 50; i++) s.newId()}.length, 50);
    });

    test('nothing is sent before a document is loaded', () async {
      final s = PatientStore();
      addTearDown(s.dispose);
      await s.upsertMember(FamilyMember(id: 'x', name: 'X', relation: '', age: 1));
      expect(s.family.single.id, 'x', reason: 'still shown');
      expect(await s.startSos(), isNull);
    });

    test('helpers read the loaded lists', () async {
      final svc = service();
      final s = await loaded(svc);
      expect(s.memberName('self'), 'You');
      expect(s.memberName('f2'), 'Rajesh Sharma');
      expect(s.emergencyContacts.map((m) => m.id), ['f1']);
      expect(s.caregiver!.id, 'f1');
      expect(specialties, contains('Cardiologist'));
    });
  });
}
