// Plain data classes for the patient side, each with JSON for on-device storage.

DateTime _dt(Object? v) => DateTime.tryParse(v as String? ?? '') ?? DateTime.now();
List<String> _ls(Object? v) => (v as List?)?.map((e) => e.toString()).toList() ?? [];

class Medication {
  Medication({required this.name, required this.dose, required this.schedule});
  String name, dose, schedule;
  Map<String, dynamic> toJson() => {'name': name, 'dose': dose, 'schedule': schedule};
  factory Medication.fromJson(Map<String, dynamic> j) => Medication(name: j['name'] ?? '', dose: j['dose'] ?? '', schedule: j['schedule'] ?? '');
}

class UserProfile {
  UserProfile({
    required this.name,
    this.email = '',
    this.phone = '',
    this.age = 30,
    this.sex = 'F',
    this.bloodGroup = 'O+',
    this.heightCm = 165,
    this.weightKg = 60,
    this.city = '',
    List<String>? conditions,
    List<String>? allergies,
    List<Medication>? medications,
  })  : conditions = conditions ?? [],
        allergies = allergies ?? [],
        medications = medications ?? [];
  String name, email, phone, sex, bloodGroup, city;
  int age;
  double heightCm, weightKg;
  List<String> conditions, allergies;
  List<Medication> medications;

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  Map<String, dynamic> toJson() => {
        'name': name, 'email': email, 'phone': phone, 'age': age, 'sex': sex, 'bloodGroup': bloodGroup,
        'heightCm': heightCm, 'weightKg': weightKg, 'city': city, 'conditions': conditions, 'allergies': allergies,
        'medications': medications.map((m) => m.toJson()).toList(),
      };
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] ?? '', email: j['email'] ?? '', phone: j['phone'] ?? '', age: j['age'] ?? 30, sex: j['sex'] ?? 'F',
        bloodGroup: j['bloodGroup'] ?? 'O+', heightCm: (j['heightCm'] as num?)?.toDouble() ?? 165, weightKg: (j['weightKg'] as num?)?.toDouble() ?? 60,
        city: j['city'] ?? '', conditions: _ls(j['conditions']), allergies: _ls(j['allergies']),
        medications: ((j['medications'] as List?) ?? []).map((m) => Medication.fromJson(Map<String, dynamic>.from(m))).toList(),
      );
}

class FamilyMember {
  FamilyMember({required this.id, required this.name, required this.relation, required this.age, this.bloodGroup = 'O+', this.phone = '', List<String>? conditions, this.caregiver = false, this.emergencyContact = false})
      : conditions = conditions ?? [];
  final String id;
  String name, relation, bloodGroup, phone;
  int age;
  List<String> conditions;
  bool caregiver, emergencyContact;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'relation': relation, 'age': age, 'bloodGroup': bloodGroup, 'phone': phone, 'conditions': conditions, 'caregiver': caregiver, 'emergencyContact': emergencyContact};
  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
        id: j['id'], name: j['name'] ?? '', relation: j['relation'] ?? '', age: j['age'] ?? 0, bloodGroup: j['bloodGroup'] ?? 'O+', phone: j['phone'] ?? '',
        conditions: _ls(j['conditions']), caregiver: j['caregiver'] ?? false, emergencyContact: j['emergencyContact'] ?? false,
      );
}

class Doctor {
  const Doctor({required this.id, required this.name, required this.specialty, required this.hospital, required this.city, required this.years, required this.rating, required this.reviews, required this.fee, required this.languages, this.video = true, this.clinic = true, required this.nextFreeDays, required this.about, this.distanceKm = 5});
  final String id, name, specialty, hospital, city, about;
  final int years, reviews, fee, nextFreeDays;
  final double rating, distanceKm;
  final List<String> languages;
  final bool video, clinic;
}

enum ApptStatus { upcoming, completed, cancelled }

enum ApptMode { clinic, video }

class Appointment {
  Appointment({required this.id, required this.doctorId, required this.forMember, required this.at, required this.mode, required this.reason, this.notes = '', this.status = ApptStatus.upcoming, this.fromAlert});
  final String id;
  String doctorId, forMember, reason, notes;
  DateTime at;
  ApptMode mode;
  ApptStatus status;
  String? fromAlert;
  Map<String, dynamic> toJson() => {'id': id, 'doctorId': doctorId, 'forMember': forMember, 'at': at.toIso8601String(), 'mode': mode.name, 'reason': reason, 'notes': notes, 'status': status.name, 'fromAlert': fromAlert};
  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'], doctorId: j['doctorId'], forMember: j['forMember'] ?? 'self', at: _dt(j['at']), mode: ApptMode.values.byName(j['mode'] ?? 'clinic'),
        reason: j['reason'] ?? '', notes: j['notes'] ?? '', status: ApptStatus.values.byName(j['status'] ?? 'upcoming'), fromAlert: j['fromAlert'],
      );
}

const recordCategories = ['Lab report', 'Prescription', 'Imaging', 'Discharge summary', 'Vaccination', 'Other'];

class MedicalRecord {
  MedicalRecord({required this.id, required this.title, required this.category, required this.date, required this.forMember, required this.fileName, required this.sizeBytes, this.notes = '', this.shared = false});
  final String id;
  String title, category, forMember, fileName, notes;
  DateTime date;
  int sizeBytes;
  bool shared;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'category': category, 'date': date.toIso8601String(), 'forMember': forMember, 'fileName': fileName, 'sizeBytes': sizeBytes, 'notes': notes, 'shared': shared};
  factory MedicalRecord.fromJson(Map<String, dynamic> j) => MedicalRecord(
        id: j['id'], title: j['title'] ?? '', category: j['category'] ?? 'Other', date: _dt(j['date']), forMember: j['forMember'] ?? 'self',
        fileName: j['fileName'] ?? '', sizeBytes: j['sizeBytes'] ?? 0, notes: j['notes'] ?? '', shared: j['shared'] ?? false,
      );
}

class InsurancePolicy {
  InsurancePolicy({required this.id, required this.insurer, required this.plan, required this.policyNo, required this.sumInsured, required this.validTill, List<String>? members, this.cashless = true, this.premium = 0})
      : members = members ?? ['self'];
  final String id;
  String insurer, plan, policyNo;
  int sumInsured, premium;
  DateTime validTill;
  List<String> members;
  bool cashless;
  Map<String, dynamic> toJson() => {'id': id, 'insurer': insurer, 'plan': plan, 'policyNo': policyNo, 'sumInsured': sumInsured, 'validTill': validTill.toIso8601String(), 'members': members, 'cashless': cashless, 'premium': premium};
  factory InsurancePolicy.fromJson(Map<String, dynamic> j) => InsurancePolicy(
        id: j['id'], insurer: j['insurer'] ?? '', plan: j['plan'] ?? '', policyNo: j['policyNo'] ?? '', sumInsured: j['sumInsured'] ?? 0,
        validTill: _dt(j['validTill']), members: _ls(j['members']), cashless: j['cashless'] ?? true, premium: j['premium'] ?? 0,
      );
}

enum ClaimStatus { submitted, underReview, approved, paid, rejected }

const claimStatusLabel = {
  ClaimStatus.submitted: 'Submitted',
  ClaimStatus.underReview: 'Under review',
  ClaimStatus.approved: 'Approved',
  ClaimStatus.paid: 'Paid',
  ClaimStatus.rejected: 'Rejected',
};

class ClaimEvent {
  ClaimEvent(this.status, this.at, [this.note = '']);
  final ClaimStatus status;
  final DateTime at;
  final String note;
  Map<String, dynamic> toJson() => {'status': status.name, 'at': at.toIso8601String(), 'note': note};
  factory ClaimEvent.fromJson(Map<String, dynamic> j) => ClaimEvent(ClaimStatus.values.byName(j['status']), _dt(j['at']), j['note'] ?? '');
}

class Claim {
  Claim({required this.id, required this.policyId, required this.title, required this.hospital, required this.amount, required this.forMember, this.approved, List<String>? recordIds, List<ClaimEvent>? timeline})
      : recordIds = recordIds ?? [],
        timeline = timeline ?? [];
  final String id;
  String policyId, title, hospital, forMember;
  int amount;
  int? approved;
  List<String> recordIds;
  List<ClaimEvent> timeline;
  ClaimStatus get status => timeline.isEmpty ? ClaimStatus.submitted : timeline.last.status;
  DateTime get filed => timeline.isEmpty ? DateTime.now() : timeline.first.at;
  Map<String, dynamic> toJson() => {'id': id, 'policyId': policyId, 'title': title, 'hospital': hospital, 'amount': amount, 'approved': approved, 'forMember': forMember, 'recordIds': recordIds, 'timeline': timeline.map((e) => e.toJson()).toList()};
  factory Claim.fromJson(Map<String, dynamic> j) => Claim(
        id: j['id'], policyId: j['policyId'], title: j['title'] ?? '', hospital: j['hospital'] ?? '', amount: j['amount'] ?? 0, approved: j['approved'],
        forMember: j['forMember'] ?? 'self', recordIds: _ls(j['recordIds']),
        timeline: ((j['timeline'] as List?) ?? []).map((e) => ClaimEvent.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
}

class Preferences {
  Preferences({this.theme = 'system', this.fahrenheit = false, this.notifications = true, this.autoSos = true, this.shareWithCareTeam = true, this.caregiverEscalation = true, this.language = 'English'});
  String theme, language;
  bool fahrenheit, notifications, autoSos, shareWithCareTeam, caregiverEscalation;
  Map<String, dynamic> toJson() => {'theme': theme, 'fahrenheit': fahrenheit, 'notifications': notifications, 'autoSos': autoSos, 'shareWithCareTeam': shareWithCareTeam, 'caregiverEscalation': caregiverEscalation, 'language': language};
  factory Preferences.fromJson(Map<String, dynamic> j) => Preferences(
        theme: j['theme'] ?? 'system', fahrenheit: j['fahrenheit'] ?? false, notifications: j['notifications'] ?? true, autoSos: j['autoSos'] ?? true,
        shareWithCareTeam: j['shareWithCareTeam'] ?? true, caregiverEscalation: j['caregiverEscalation'] ?? true, language: j['language'] ?? 'English',
      );
}
