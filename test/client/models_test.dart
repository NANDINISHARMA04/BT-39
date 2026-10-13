import 'package:bt39_care/engine/news2.dart';
import 'package:bt39_care/engine/simulator.dart';
import 'package:bt39_care/models/patient_models.dart';
import 'package:bt39_care/services/bt39_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('times', () {
    test('are read as UTC and shown in local time', () {
      final a = Appointment.fromJson({'id': 'a', 'doctorId': 'd1', 'at': '2026-10-14T03:30:00.000Z', 'mode': 'video', 'status': 'upcoming'});
      expect(a.at.isUtc, isFalse);
      expect(a.at.isAtSameMomentAs(DateTime.utc(2026, 10, 14, 3, 30)), isTrue);
    });

    test('are written in UTC with a Z, whatever the phone\'s zone', () {
      final local = DateTime(2026, 10, 14, 9, 0);
      final json = Appointment(id: 'a', doctorId: 'd1', forMember: 'self', at: local, mode: ApptMode.clinic, reason: 'x').toJson();
      expect(json['at'], local.toUtc().toIso8601String());
      expect(json['at'], endsWith('Z'));
      expect(MedicalRecord(id: 'r', title: 't', category: 'c', date: local, forMember: 'self', fileName: 'f', sizeBytes: 1).toJson()['date'], endsWith('Z'));
      expect(InsurancePolicy(id: 'p', insurer: 'i', plan: 'p', policyNo: 'n', sumInsured: 1, validTill: local).toJson()['validTill'], endsWith('Z'));
      expect(ClaimEvent(ClaimStatus.paid, local).toJson()['at'], endsWith('Z'));
    });

    test('survive a round trip', () {
      final at = DateTime(2026, 11, 2, 17, 45);
      final back = Appointment.fromJson(Appointment(id: 'a', doctorId: 'd1', forMember: 'self', at: at, mode: ApptMode.video, reason: 'x').toJson());
      expect(back.at, at);
      expect(back.mode, ApptMode.video);
    });

    test('a missing or broken time becomes now rather than an error', () {
      final r = MedicalRecord.fromJson({'id': 'r', 'date': 'garbage'});
      expect(r.date.difference(DateTime.now()).inSeconds.abs(), lessThan(5));
    });
  });

  group('numbers', () {
    test('whole numbers that arrive with a decimal point still read', () {
      final p = InsurancePolicy.fromJson({'id': 'p', 'sumInsured': 1000000.0, 'premium': 28400.0, 'validTill': '2027-03-31T00:00:00Z'});
      expect(p.sumInsured, 1000000);
      expect(p.premium, 28400);
      final c = Claim.fromJson({'id': 'c', 'policyId': 'p', 'amount': 420000.0, 'approved': 395000.0});
      expect([c.amount, c.approved], [420000, 395000]);
      expect(Claim.fromJson({'id': 'c', 'policyId': 'p', 'amount': 5, 'approved': null}).approved, isNull);
      expect(FamilyMember.fromJson({'id': 'f', 'age': 12.0}).age, 12);
      expect(UserProfile.fromJson({'age': 24.0}).age, 24);
    });
  });

  group('Doctor', () {
    final json = {
      'id': 'd4', 'name': 'Dr. Rohan Verma', 'specialty': 'Endocrinologist', 'hospital': 'Medanta', 'city': 'Gurugram', 'years': 11, 'rating': 4.6, 'reviews': 287,
      'fee': 1000, 'languages': ['English', 'Hindi'], 'video': true, 'clinic': false, 'nextFreeDays': 2, 'about': 'Diabetes, thyroid and hormone disorders.', 'distanceKm': 21.4,
    };

    test('reads and writes the service\'s keys', () {
      final d = Doctor.fromJson(json);
      expect(d.id, 'd4');
      expect(d.clinic, isFalse);
      expect(d.video, isTrue);
      expect(d.rating, 4.6);
      expect(d.languages, ['English', 'Hindi']);
      expect(d.nextFreeDays, 2);
      expect(d.distanceKm, 21.4);
      expect(d.toJson(), json);
    });

    test('defaults for a sparse record', () {
      final d = Doctor.fromJson({'id': 'x'});
      expect(d.video, isTrue);
      expect(d.clinic, isTrue);
      expect(d.distanceKm, 5);
      expect(d.languages, isEmpty);
    });
  });

  group('beds', () {
    test('carry the NEWS2 points the service scored', () {
      final b = LiveBed.fromJson({
        'bed': 'B02', 'patient_id': 'p', 'name': 'N', 'hr': 128.0, 'news2': 7, 'band': 'high',
        'points': {'hr': 2, 'spo2': 3, 'rr': 3, 'sbp': null, 'temp': 1.0},
      });
      expect(b.points, {'hr': 2, 'spo2': 3, 'rr': 3, 'sbp': null, 'temp': 1});
      expect(b.points['sbp'], isNull);
      expect(b.hr, 128);
    });

    test('have no points when the frame sends none', () {
      expect(LiveBed.fromJson({'bed': 'B01'}).points, isEmpty);
      expect(LiveBed(bed: 'B01').points, isEmpty);
    });
  });

  test('the scenarios and the band names the screens use are still here', () {
    expect(scenarios.map((s) => s.id), ['rest', 'walk', 'loose', 'stress', 'tachy', 'hypoxia', 'fever']);
    expect(scenarioById('walk').minutes, 12);
    expect(scenarioById('rest').minutes, 0);
    expect(scenarioById('fever').name, 'Fever');
    expect(bandLabel['low_medium'], 'Low–medium');
    expect(severityLabel['high'], 'Emergency');
  });
}
