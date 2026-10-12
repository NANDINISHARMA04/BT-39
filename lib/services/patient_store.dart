import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/patient_models.dart';

/// Example doctors for discovery and booking. All fictional.
const doctorCatalog = [
  Doctor(id: 'd1', name: 'Dr. Kavya Rao', specialty: 'Cardiologist', hospital: 'Fortis Heart Institute', city: 'Noida', years: 14, rating: 4.9, reviews: 612, fee: 900, languages: ['English', 'Hindi', 'Kannada'], nextFreeDays: 0, distanceKm: 3.2, about: 'Heart rhythm problems and recovery after heart surgery. Reviews AdaptAlert alerts for her patients.'),
  Doctor(id: 'd2', name: 'Dr. Arjun Malhotra', specialty: 'General Physician', hospital: 'Max Clinic', city: 'Delhi', years: 9, rating: 4.7, reviews: 1204, fee: 500, languages: ['English', 'Hindi', 'Punjabi'], nextFreeDays: 0, distanceKm: 6.8, about: 'Fever, infections, diabetes and blood pressure follow-ups.'),
  Doctor(id: 'd3', name: 'Dr. Meenakshi Iyer', specialty: 'Pulmonologist', hospital: 'Apollo Hospitals', city: 'Delhi', years: 18, rating: 4.8, reviews: 433, fee: 1100, languages: ['English', 'Tamil', 'Hindi'], nextFreeDays: 1, distanceKm: 9.1, about: 'Asthma, COPD, sleep apnoea and low oxygen at night.'),
  Doctor(id: 'd4', name: 'Dr. Rohan Verma', specialty: 'Endocrinologist', hospital: 'Medanta', city: 'Gurugram', years: 11, rating: 4.6, reviews: 287, fee: 1000, languages: ['English', 'Hindi'], nextFreeDays: 2, distanceKm: 21.4, clinic: false, about: 'Diabetes, thyroid and hormone disorders. Video consults only.'),
  Doctor(id: 'd5', name: 'Dr. Sana Qureshi', specialty: 'Neurologist', hospital: 'AIIMS OPD', city: 'Delhi', years: 16, rating: 4.9, reviews: 815, fee: 1200, languages: ['English', 'Hindi', 'Urdu'], nextFreeDays: 3, distanceKm: 12.0, video: false, about: 'Headache, epilepsy, stroke recovery.'),
  Doctor(id: 'd6', name: 'Dr. Vikram Shetty', specialty: 'Orthopedic', hospital: 'Manipal Hospital', city: 'Bengaluru', years: 20, rating: 4.5, reviews: 954, fee: 800, languages: ['English', 'Kannada', 'Hindi'], nextFreeDays: 1, distanceKm: 4.4, about: 'Joint pain, sports injuries, fracture follow-up.'),
  Doctor(id: 'd7', name: 'Dr. Priya Nair', specialty: 'Pediatrician', hospital: 'Rainbow Children\'s Hospital', city: 'Noida', years: 12, rating: 4.9, reviews: 1530, fee: 700, languages: ['English', 'Malayalam', 'Hindi'], nextFreeDays: 0, distanceKm: 2.1, about: 'Child health, vaccination and growth checks.'),
  Doctor(id: 'd8', name: 'Dr. Ananya Ghosh', specialty: 'Gynecologist', hospital: 'Cloudnine', city: 'Gurugram', years: 10, rating: 4.7, reviews: 640, fee: 900, languages: ['English', 'Bengali', 'Hindi'], nextFreeDays: 2, distanceKm: 15.6, about: 'Pregnancy care, PCOS and women\'s health.'),
  Doctor(id: 'd9', name: 'Dr. Karan Mehta', specialty: 'Psychiatrist', hospital: 'Mind Wellness Clinic', city: 'Mumbai', years: 8, rating: 4.8, reviews: 372, fee: 1000, languages: ['English', 'Hindi', 'Gujarati'], nextFreeDays: 0, distanceKm: 30.0, clinic: false, about: 'Anxiety, sleep, stress after illness. Video consults only.'),
  Doctor(id: 'd10', name: 'Dr. Neha Kapoor', specialty: 'Dermatologist', hospital: 'Skin & You', city: 'Delhi', years: 7, rating: 4.4, reviews: 521, fee: 600, languages: ['English', 'Hindi'], nextFreeDays: 1, distanceKm: 7.3, about: 'Skin, hair and allergy problems.'),
  Doctor(id: 'd11', name: 'Dr. Suresh Pillai', specialty: 'Cardiologist', hospital: 'Narayana Health', city: 'Bengaluru', years: 22, rating: 4.8, reviews: 1102, fee: 1300, languages: ['English', 'Malayalam', 'Kannada'], nextFreeDays: 4, distanceKm: 8.0, about: 'Heart failure, high blood pressure and cardiac rehab.'),
  Doctor(id: 'd12', name: 'Dr. Farah Siddiqui', specialty: 'General Physician', hospital: 'HealthFirst Clinic', city: 'Noida', years: 6, rating: 4.6, reviews: 389, fee: 400, languages: ['English', 'Hindi', 'Urdu'], nextFreeDays: 0, distanceKm: 1.4, about: 'Everyday illness, check-ups and medicine reviews.'),
];

Doctor doctorById(String id) => doctorCatalog.firstWhere((d) => d.id == id, orElse: () => doctorCatalog.first);

const specialties = ['Cardiologist', 'General Physician', 'Pulmonologist', 'Endocrinologist', 'Neurologist', 'Orthopedic', 'Pediatrician', 'Gynecologist', 'Psychiatrist', 'Dermatologist'];

/// Everything the patient app stores, kept on the device per account.
class PatientStore extends ChangeNotifier {
  String _account = 'demo';
  late UserProfile profile;
  List<FamilyMember> family = [];
  List<Appointment> appointments = [];
  List<MedicalRecord> records = [];
  List<InsurancePolicy> policies = [];
  List<Claim> claims = [];
  Preferences prefs = Preferences();
  bool loaded = false;

  final _rnd = Random();
  String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 20).toRadixString(36)}';

  String _k(String part) => 'bt39.$_account.$part';

  Future<void> load(String account, {required String name, String email = '', Map<String, String> details = const {}}) async {
    _account = account;
    final sp = await SharedPreferences.getInstance();
    // The demo account starts from the same example data every time.
    final raw = account.startsWith('demo-') ? null : sp.getString(_k('data'));
    if (raw == null) {
      _seed(name, email);
      if (details['age'] != null) profile.age = int.tryParse(details['age']!) ?? profile.age;
      if (details['sex'] != null) profile.sex = details['sex']!;
      if (details['phone'] != null && details['phone']!.isNotEmpty) profile.phone = details['phone']!;
      await save();
    } else {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _seed(name, email);
      }
    }
    loaded = true;
    notifyListeners();
  }

  /// Reads another account's saved data without making it the active account,
  /// e.g. for a doctor opening a patient's record. Null if nothing is saved.
  static Future<PatientStore?> peek(String account) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('bt39.$account.data');
      if (raw == null) return null;
      final s = PatientStore().._account = account;
      s._fromJson(jsonDecode(raw) as Map<String, dynamic>);
      s.loaded = true;
      return s;
    } catch (_) {
      return null;
    }
  }

  /// The example data for [name], in memory only.
  static PatientStore example(String name, String email) {
    final s = PatientStore().._seed(name, email);
    s.loaded = true;
    return s;
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_k('data'), jsonEncode(_toJson()));
    } catch (_) {
      // Storage can be unavailable (private browsing). The app keeps working in memory.
    }
  }

  void _changed() {
    notifyListeners();
    save();
  }

  Map<String, dynamic> _toJson() => {
        'profile': profile.toJson(),
        'family': family.map((e) => e.toJson()).toList(),
        'appointments': appointments.map((e) => e.toJson()).toList(),
        'records': records.map((e) => e.toJson()).toList(),
        'policies': policies.map((e) => e.toJson()).toList(),
        'claims': claims.map((e) => e.toJson()).toList(),
        'prefs': prefs.toJson(),
      };

  void _fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(Object e) => Map<String, dynamic>.from(e as Map);
    profile = UserProfile.fromJson(m(j['profile']));
    family = (j['family'] as List).map((e) => FamilyMember.fromJson(m(e))).toList();
    appointments = (j['appointments'] as List).map((e) => Appointment.fromJson(m(e))).toList();
    records = (j['records'] as List).map((e) => MedicalRecord.fromJson(m(e))).toList();
    policies = (j['policies'] as List).map((e) => InsurancePolicy.fromJson(m(e))).toList();
    claims = (j['claims'] as List).map((e) => Claim.fromJson(m(e))).toList();
    prefs = Preferences.fromJson(m(j['prefs']));
  }

  /// Example data so every screen opens in a working state.
  void _seed(String name, String email) {
    final now = DateTime.now();
    DateTime day(int d, int h, [int m = 0]) => DateTime(now.year, now.month, now.day + d, h, m);
    profile = UserProfile(
      name: name, email: email, phone: '+91 98100 12345', age: 24, sex: 'M', bloodGroup: 'B+', heightCm: 174, weightKg: 66, city: 'Noida',
      conditions: ['Heart valve repair surgery, day 6 at home', 'Mild asthma'],
      allergies: ['Penicillin'],
      medications: [
        Medication(name: 'Aspirin', dose: '75 mg', schedule: 'Once daily, after breakfast'),
        Medication(name: 'Metoprolol', dose: '25 mg', schedule: 'Twice daily'),
        Medication(name: 'Pantoprazole', dose: '40 mg', schedule: 'Before breakfast'),
        Medication(name: 'Salbutamol inhaler', dose: '100 mcg', schedule: 'When needed for wheeze'),
      ],
    );
    family = [
      FamilyMember(id: 'f1', name: 'Sunita Sharma', relation: 'Mother', age: 50, bloodGroup: 'B+', phone: '+91 98111 22334', caregiver: true, emergencyContact: true),
      FamilyMember(id: 'f2', name: 'Rajesh Sharma', relation: 'Father', age: 54, bloodGroup: 'O+', phone: '+91 98111 99887', conditions: ['High blood pressure'], emergencyContact: true),
      FamilyMember(id: 'f3', name: 'Ishaan Sharma', relation: 'Brother', age: 12, bloodGroup: 'B+', conditions: ['Asthma (mild)']),
    ];
    appointments = [
      Appointment(id: 'a1', doctorId: 'd1', forMember: 'self', at: day(1, 11, 30), mode: ApptMode.video, reason: 'Post-surgery review, week 1', notes: 'Share AdaptAlert summary before the call.'),
      Appointment(id: 'a2', doctorId: 'd7', forMember: 'f3', at: day(4, 17), mode: ApptMode.clinic, reason: 'Inhaler check-up'),
      Appointment(id: 'a3', doctorId: 'd2', forMember: 'self', at: day(-9, 10), mode: ApptMode.clinic, reason: 'Fever follow-up', status: ApptStatus.completed),
    ];
    records = [
      MedicalRecord(id: 'r1', title: 'Discharge summary, Fortis', category: 'Discharge summary', date: day(-6, 0), forMember: 'self', fileName: 'discharge_summary.pdf', sizeBytes: 482113, notes: 'Mitral valve repair. Follow up with cardiology in 1 week.', shared: true),
      MedicalRecord(id: 'r2', title: 'Blood count and INR', category: 'Lab report', date: day(-12, 0), forMember: 'self', fileName: 'lab_report.pdf', sizeBytes: 210554, notes: 'Haemoglobin 11.8 g/dL. INR 1.1.', shared: true),
      MedicalRecord(id: 'r3', title: 'Chest X-ray', category: 'Imaging', date: day(-7, 0), forMember: 'self', fileName: 'chest_xray.jpg', sizeBytes: 1830220),
      MedicalRecord(id: 'r4', title: 'Discharge medicines', category: 'Prescription', date: day(-6, 0), forMember: 'self', fileName: 'prescription.jpg', sizeBytes: 642010, shared: true),
      MedicalRecord(id: 'r5', title: 'Vaccination card', category: 'Vaccination', date: day(-200, 0), forMember: 'f3', fileName: 'vaccines.pdf', sizeBytes: 120044),
    ];
    policies = [
      InsurancePolicy(id: 'p1', insurer: 'Star Health', plan: 'Family Health Optima', policyNo: 'SH-4471-2209-88', sumInsured: 1000000, validTill: DateTime(now.year + 1, 3, 31), members: ['self', 'f2', 'f3'], premium: 28400),
    ];
    claims = [
      Claim(id: 'c1', policyId: 'p1', title: 'Heart valve repair surgery', hospital: 'Fortis Heart Institute', amount: 420000, approved: 395000, forMember: 'self', recordIds: ['r1'], timeline: [
        ClaimEvent(ClaimStatus.submitted, day(-6, 9)),
        ClaimEvent(ClaimStatus.underReview, day(-5, 14), 'Documents received'),
        ClaimEvent(ClaimStatus.approved, day(-3, 16), '₹25,000 not covered: room upgrade'),
      ]),
      Claim(id: 'c2', policyId: 'p1', title: 'Pediatric OPD and nebuliser', hospital: 'Rainbow Children\'s Hospital', amount: 6800, forMember: 'f3', timeline: [ClaimEvent(ClaimStatus.submitted, day(-1, 18))]),
    ];
    prefs = Preferences();
  }

  // ---- profile & prefs
  void updateProfile(void Function(UserProfile p) f) {
    f(profile);
    _changed();
  }

  void updatePrefs(void Function(Preferences p) f) {
    f(prefs);
    _changed();
  }

  // ---- family
  String memberName(String id) => id == 'self' ? 'You' : family.firstWhere((m) => m.id == id, orElse: () => FamilyMember(id: id, name: 'Removed member', relation: '', age: 0)).name;
  List<FamilyMember> get emergencyContacts => family.where((m) => m.emergencyContact).toList();
  FamilyMember? get caregiver => family.where((m) => m.caregiver).firstOrNull;

  void upsertMember(FamilyMember m) {
    final i = family.indexWhere((x) => x.id == m.id);
    i < 0 ? family.add(m) : family[i] = m;
    _changed();
  }

  void deleteMember(String id) {
    family.removeWhere((m) => m.id == id);
    for (final a in appointments) {
      if (a.forMember == id) a.status = ApptStatus.cancelled;
    }
    _changed();
  }

  // ---- appointments
  List<Appointment> get upcoming => appointments.where((a) => a.status == ApptStatus.upcoming && a.at.isAfter(DateTime.now().subtract(const Duration(hours: 1)))).toList()..sort((a, b) => a.at.compareTo(b.at));
  List<Appointment> get past => appointments.where((a) => !upcoming.contains(a)).toList()..sort((a, b) => b.at.compareTo(a.at));

  void upsertAppointment(Appointment a) {
    final i = appointments.indexWhere((x) => x.id == a.id);
    i < 0 ? appointments.add(a) : appointments[i] = a;
    _changed();
  }

  void cancelAppointment(String id) {
    appointments.firstWhere((a) => a.id == id).status = ApptStatus.cancelled;
    _changed();
  }

  void deleteAppointment(String id) {
    appointments.removeWhere((a) => a.id == id);
    _changed();
  }

  /// Free 30-minute slots for a doctor on a day, minus booked ones.
  List<DateTime> slotsFor(Doctor d, DateTime date, {String? exceptAppt}) {
    final now = DateTime.now();
    final out = <DateTime>[];
    for (var h = 9; h < 18; h++) {
      for (final m in [0, 30]) {
        if (h == 13) continue; // lunch
        final s = DateTime(date.year, date.month, date.day, h, m);
        if (s.isBefore(now.add(const Duration(minutes: 30)))) continue;
        final taken = appointments.any((a) => a.id != exceptAppt && a.doctorId == d.id && a.status == ApptStatus.upcoming && a.at == s);
        // Doctors are busier on some slots: a stable pseudo-random pattern.
        final busy = (d.id.hashCode + s.day * 31 + h * 7 + m) % 5 == 0;
        if (!taken && !busy) out.add(s);
      }
    }
    return out;
  }

  // ---- records
  void upsertRecord(MedicalRecord r) {
    final i = records.indexWhere((x) => x.id == r.id);
    i < 0 ? records.insert(0, r) : records[i] = r;
    _changed();
  }

  void deleteRecord(String id) {
    records.removeWhere((r) => r.id == id);
    for (final c in claims) {
      c.recordIds.remove(id);
    }
    _changed();
  }

  // ---- insurance
  void upsertPolicy(InsurancePolicy p) {
    final i = policies.indexWhere((x) => x.id == p.id);
    i < 0 ? policies.add(p) : policies[i] = p;
    _changed();
  }

  void deletePolicy(String id) {
    policies.removeWhere((p) => p.id == id);
    claims.removeWhere((c) => c.policyId == id);
    _changed();
  }

  int usedOf(InsurancePolicy p) => claims.where((c) => c.policyId == p.id && (c.status == ClaimStatus.approved || c.status == ClaimStatus.paid)).fold(0, (a, c) => a + (c.approved ?? c.amount));

  void upsertClaim(Claim c) {
    final i = claims.indexWhere((x) => x.id == c.id);
    i < 0 ? claims.insert(0, c) : claims[i] = c;
    _changed();
  }

  void deleteClaim(String id) {
    claims.removeWhere((c) => c.id == id);
    _changed();
  }

  /// Demo only: moves a claim one step along, as the insurer would.
  void advanceClaim(Claim c) {
    final next = switch (c.status) {
      ClaimStatus.submitted => ClaimStatus.underReview,
      ClaimStatus.underReview => ClaimStatus.approved,
      ClaimStatus.approved => ClaimStatus.paid,
      _ => null,
    };
    if (next == null) return;
    if (next == ClaimStatus.approved) c.approved ??= (c.amount * .94).round();
    c.timeline.add(ClaimEvent(next, DateTime.now(), next == ClaimStatus.underReview ? 'Documents received' : ''));
    _changed();
  }
}
