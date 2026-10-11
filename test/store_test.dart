import 'package:bt39_care/models/patient_models.dart';
import 'package:bt39_care/services/patient_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  test('seeds example data and persists changes per account', () async {
    final s = PatientStore();
    await s.load('t1', name: 'Test User');
    expect(s.profile.name, 'Test User');
    expect(s.family, isNotEmpty);
    final before = s.appointments.length;
    final d = doctorCatalog.first;
    final slot = s.slotsFor(d, DateTime.now().add(const Duration(days: 2))).first;
    s.upsertAppointment(Appointment(id: 'x', doctorId: d.id, forMember: 'self', at: slot, mode: ApptMode.video, reason: 'Check'));
    expect(s.appointments.length, before + 1);
    expect(s.slotsFor(d, slot), isNot(contains(slot)));
    await s.save();

    final again = PatientStore();
    await again.load('t1', name: 'ignored');
    expect(again.appointments.any((a) => a.id == 'x'), isTrue);
    again.cancelAppointment('x');
    expect(again.appointments.firstWhere((a) => a.id == 'x').status, ApptStatus.cancelled);
    again.deleteAppointment('x');
    expect(again.appointments.any((a) => a.id == 'x'), isFalse);
  });

  test('claims move through their states and count against cover', () async {
    final s = PatientStore();
    await s.load('t2', name: 'T');
    final p = s.policies.first;
    final used = s.usedOf(p);
    final c = Claim(id: 'c9', policyId: p.id, title: 'OPD', hospital: 'X', amount: 10000, forMember: 'self', timeline: [ClaimEvent(ClaimStatus.submitted, DateTime.now())]);
    s.upsertClaim(c);
    s.advanceClaim(c);
    s.advanceClaim(c);
    expect(c.status, ClaimStatus.approved);
    expect(s.usedOf(p), used + c.approved!);
  });

  test('deleting a family member cancels their appointments', () async {
    final s = PatientStore();
    await s.load('t3', name: 'T');
    final m = s.family.firstWhere((f) => s.appointments.any((a) => a.forMember == f.id));
    s.deleteMember(m.id);
    expect(s.appointments.where((a) => a.forMember == m.id).every((a) => a.status == ApptStatus.cancelled), isTrue);
  });
}
