import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/patient_models.dart';
import 'patient_store.dart';
import 'session.dart';

/// Where a patient in the doctor's and nurse's list comes from.
enum PatientSource { live, account, example }

/// One patient as the care team sees them.
class CarePatient {
  CarePatient({
    required this.id,
    required this.name,
    required this.age,
    required this.sex,
    required this.condition,
    required this.source,
    this.bloodGroup = 'O+',
    this.phone = '',
    this.email,
    this.conditions = const [],
    this.allergies = const [],
    this.medications = const [],
    this.records = const [],
    this.vitals,
    this.status = 'Stable',
    this.learned,
    this.store,
  });
  final String id, name, sex, condition, bloodGroup, phone, status;
  final int age;
  final PatientSource source;
  final String? email, learned;
  final List<String> conditions, allergies;
  final List<Medication> medications;

  /// Records the patient shared with their care team.
  final List<MedicalRecord> records;

  /// Last vitals for patients without a live band: heart rate, SpO₂, temperature.
  final ({int hr, int spo2, double temp})? vitals;

  /// The patient's own saved data, when they have an account on this device.
  final PatientStore? store;

  bool get live => source == PatientSource.live;
}

class ClinicalNote {
  ClinicalNote({required this.id, required this.patientId, required this.at, required this.kind, required this.text, required this.by});
  final String id, patientId, kind, text, by; // kind: note | prescription | consult | nursing
  final DateTime at;
  Map<String, dynamic> toJson() => {'id': id, 'patientId': patientId, 'at': at.toIso8601String(), 'kind': kind, 'text': text, 'by': by};
  factory ClinicalNote.fromJson(Map<String, dynamic> j) => ClinicalNote(id: j['id'], patientId: j['patientId'], at: DateTime.parse(j['at']), kind: j['kind'], text: j['text'], by: j['by'] ?? '');
}

enum VisitStatus { upcoming, completed, cancelled, noShow }

const visitStatusLabel = {VisitStatus.upcoming: 'Upcoming', VisitStatus.completed: 'Completed', VisitStatus.cancelled: 'Cancelled', VisitStatus.noShow: 'No-show'};

/// An appointment in a doctor's schedule.
class Visit {
  Visit({required this.id, required this.patientId, required this.patientName, required this.at, required this.reason, required this.video, this.status = VisitStatus.upcoming, this.bookedByPatient = false});
  final String id, patientId, patientName, reason;
  final DateTime at;
  final bool video, bookedByPatient;
  VisitStatus status;
  Map<String, dynamic> toJson() => {'id': id, 'patientId': patientId, 'patientName': patientName, 'at': at.toIso8601String(), 'reason': reason, 'video': video, 'status': status.name};
  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        id: j['id'], patientId: j['patientId'], patientName: j['patientName'], at: DateTime.parse(j['at']), reason: j['reason'] ?? '', video: j['video'] ?? false, status: VisitStatus.values.byName(j['status'] ?? 'upcoming'),
      );
}

/// A nursing task for one shift.
class NurseTask {
  const NurseTask(this.id, this.hour, this.title, this.detail, this.kind);
  final String id, title, detail, kind; // kind: vitals | meds | check | care | handover
  final int hour;
}

class Handover {
  Handover(this.at, this.by, this.text);
  final DateTime at;
  final String by, text;
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'by': by, 'text': text};
  factory Handover.fromJson(Map<String, dynamic> j) => Handover(DateTime.parse(j['at']), j['by'] ?? '', j['text'] ?? '');
}

/// The live home patient: the demo patient account, monitored by a band.
const livePatientId = 'live';

final _examples = [
  CarePatient(
    id: 'ex-sunita', name: 'Sunita Verma', age: 64, sex: 'F', bloodGroup: 'O+', phone: '+91 98110 44120', source: PatientSource.example,
    condition: 'COPD, home oxygen at night', conditions: ['COPD (moderate)', 'High blood pressure'], allergies: [],
    medications: [Medication(name: 'Tiotropium inhaler', dose: '18 mcg', schedule: 'Once daily'), Medication(name: 'Amlodipine', dose: '5 mg', schedule: 'Once daily')],
    vitals: (hr: 82, spo2: 93, temp: 36.8), learned: 'Night oxygen dips to 91–92% are normal for her',
  ),
  CarePatient(
    id: 'ex-farhan', name: 'Farhan Ali', age: 71, sex: 'M', bloodGroup: 'A+', phone: '+91 98990 31207', source: PatientSource.example, status: 'Watching',
    condition: 'Heart failure, weight up 1.2 kg in 3 days', conditions: ['Heart failure (EF 35%)', 'Type 2 diabetes'], allergies: ['Sulfa drugs'],
    medications: [Medication(name: 'Furosemide', dose: '40 mg', schedule: 'Morning'), Medication(name: 'Ramipril', dose: '5 mg', schedule: 'Once daily'), Medication(name: 'Bisoprolol', dose: '2.5 mg', schedule: 'Once daily')],
    vitals: (hr: 91, spo2: 94, temp: 36.9),
  ),
  CarePatient(
    id: 'ex-rahul', name: 'Rahul Iyer', age: 47, sex: 'M', bloodGroup: 'B-', phone: '+91 99580 77215', source: PatientSource.example,
    condition: 'After appendix surgery, day 4', conditions: ['Laparoscopic appendectomy'], allergies: [],
    medications: [Medication(name: 'Paracetamol', dose: '650 mg', schedule: 'Every 6 hours if needed'), Medication(name: 'Cefuroxime', dose: '500 mg', schedule: 'Twice daily for 5 days')],
    vitals: (hr: 76, spo2: 98, temp: 37.1),
  ),
  CarePatient(
    id: 'ex-pooja', name: 'Pooja Desai', age: 35, sex: 'F', bloodGroup: 'AB+', phone: '+91 98201 66453', source: PatientSource.example,
    condition: 'Pregnancy, 30 weeks, high blood pressure', conditions: ['Pregnancy (30 weeks)', 'Gestational hypertension'], allergies: ['Penicillin'],
    medications: [Medication(name: 'Labetalol', dose: '100 mg', schedule: 'Twice daily'), Medication(name: 'Iron and folic acid', dose: '1 tablet', schedule: 'Once daily')],
    vitals: (hr: 90, spo2: 99, temp: 36.7),
  ),
];

/// Today's example visits: (hour, minute, patient id, reason, video).
const _visitPlan = [
  (9, 30, 'ex-sunita', 'COPD review and inhaler check', false),
  (11, 0, 'ex-farhan', 'Weight gain and breathlessness', true),
  (14, 30, 'ex-rahul', 'Wound check after surgery', false),
  (16, 0, 'ex-pooja', 'Blood pressure review', true),
];

/// What the doctor and nurse apps keep: patients, notes, prescriptions,
/// visits, nursing tasks and handovers. Stored on this device and shared by
/// every staff account on it, so a doctor's note is there for the nurse.
class ClinicalStore extends ChangeNotifier {
  ClinicalStore(this.session);
  final Session session;

  List<CarePatient> patients = [];
  final List<ClinicalNote> _notes = [];
  final List<Visit> _visits = [];
  final Map<String, String> _visitStatus = {}; // example or patient-booked visit id -> status
  final Map<String, String> _done = {}; // 'yyyy-mm-dd|task' -> 'by · h:mm'
  final List<Handover> handovers = [];
  bool loaded = false;

  static const _key = 'bt39.clinical';
  final _rnd = Random();
  String _id() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 16).toRadixString(36)}';

  String get me => session.name;

  /// This doctor's entry in the doctor catalogue, if any, so visits that
  /// patients booked in the patient app show up here.
  String? get _myDoctorId => doctorCatalog.where((d) => d.name == me).firstOrNull?.id;

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _notes.addAll(((j['notes'] as List?) ?? []).map((e) => ClinicalNote.fromJson(Map<String, dynamic>.from(e))));
        _visits.addAll(((j['visits'] as List?) ?? []).map((e) => Visit.fromJson(Map<String, dynamic>.from(e))));
        _visitStatus.addAll(Map<String, String>.from((j['visitStatus'] as Map?) ?? {}));
        _done.addAll(Map<String, String>.from((j['done'] as Map?) ?? {}));
        handovers.addAll(((j['handovers'] as List?) ?? []).map((e) => Handover.fromJson(Map<String, dynamic>.from(e))));
      }
    } catch (_) {}
    await refreshPatients();
    loaded = true;
    notifyListeners();
  }

  /// Rebuilds the patient list, picking up patients who signed up since.
  Future<void> refreshPatients() async {
    final demoMail = demoAccounts[Role.patient]!.$1;
    final demoName = demoAccounts[Role.patient]!.$3;
    final liveStore = await PatientStore.peek('local-$demoMail') ?? PatientStore.example(demoName, demoMail);
    final out = <CarePatient>[_fromStore(livePatientId, liveStore, PatientSource.live, demoMail)];
    for (final a in await session.patientAccounts()) {
      if (a.email == demoMail) continue;
      final st = await PatientStore.peek('local-${a.email}');
      if (st != null) {
        out.add(_fromStore('acct-${a.email}', st, PatientSource.account, a.email));
      } else {
        out.add(CarePatient(
          id: 'acct-${a.email}', name: a.name, email: a.email, source: PatientSource.account, condition: 'New patient, no readings yet',
          age: int.tryParse(a.details['age'] ?? '') ?? 0, sex: a.details['sex'] ?? '', phone: a.details['phone'] ?? '',
        ));
      }
    }
    out.addAll(_examples);
    patients = out;
    notifyListeners();
  }

  CarePatient _fromStore(String id, PatientStore st, PatientSource src, String email) {
    final p = st.profile;
    return CarePatient(
      id: id, name: p.name, age: p.age, sex: p.sex, bloodGroup: p.bloodGroup, phone: p.phone, email: email, source: src, store: st,
      condition: p.conditions.isEmpty ? 'No conditions recorded' : p.conditions.first,
      conditions: p.conditions, allergies: p.allergies, medications: p.medications,
      records: st.records.where((r) => r.shared && r.forMember == 'self').toList(),
    );
  }

  CarePatient? byId(String id) => patients.where((p) => p.id == id).firstOrNull;

  Future<void> _save() async {
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_key, jsonEncode({
        'notes': _notes.map((e) => e.toJson()).toList(),
        'visits': _visits.map((e) => e.toJson()).toList(),
        'visitStatus': _visitStatus,
        'done': _done,
        'handovers': handovers.map((e) => e.toJson()).toList(),
      }));
    } catch (_) {}
  }

  // ---------------------------------------------------------------- notes

  List<ClinicalNote> notesFor(String patientId) {
    final now = DateTime.now();
    final seeded = <ClinicalNote>[
      if (patientId == livePatientId) ...[
        ClinicalNote(id: 's1', patientId: patientId, at: now.subtract(const Duration(days: 6, hours: 3)), kind: 'consult', by: 'Dr. Kavya Rao', text: 'Discharged after mitral valve repair. Wrist band fitted; AdaptAlert monitoring at home. Review in one week.'),
        ClinicalNote(id: 's2', patientId: patientId, at: now.subtract(const Duration(days: 2, hours: 5)), kind: 'nursing', by: 'Nurse Anjali Singh', text: 'Video check: wound clean and dry, band fits well, no breathlessness.'),
      ],
      if (patientId == 'ex-farhan') ClinicalNote(id: 's3', patientId: patientId, at: now.subtract(const Duration(days: 1, hours: 2)), kind: 'note', by: 'Dr. Kavya Rao', text: 'Weight up 1.2 kg in 3 days, ankles a little swollen. Consider raising furosemide if it continues.'),
      if (patientId == 'ex-sunita') ClinicalNote(id: 's4', patientId: patientId, at: now.subtract(const Duration(days: 3)), kind: 'consult', by: 'Dr. Kavya Rao', text: 'Stable. Night SpO₂ 91–92% is her usual; AdaptAlert has learned this and no longer alerts on it.'),
    ];
    return [..._notes.where((n) => n.patientId == patientId), ...seeded]..sort((a, b) => b.at.compareTo(a.at));
  }

  Future<void> addNote(String patientId, String kind, String text) async {
    _notes.add(ClinicalNote(id: _id(), patientId: patientId, at: DateTime.now(), kind: kind, text: text.trim(), by: me));
    await _save();
  }

  /// Saves a prescription as a note and, when the patient has an account on
  /// this device, adds the medicine to their own medicine list.
  Future<void> prescribe(CarePatient p, Medication m, {String days = ''}) async {
    await addNote(p.id, 'prescription', '${m.name} ${m.dose}, ${m.schedule}${days.isEmpty ? '' : ' for $days days'}');
    final st = p.store;
    if (st != null && p.source != PatientSource.example) {
      st.profile.medications.add(m);
      await st.save();
      await refreshPatients();
    }
  }

  // ---------------------------------------------------------------- visits

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// All visits on [day]: example visits, visits the doctor booked, and
  /// visits patients on this device booked with this doctor.
  List<Visit> visitsOn(DateTime day) {
    final d = _day(day);
    final today = _day(DateTime.now());
    final out = <Visit>[];
    final offset = d.difference(today).inDays;
    if (d.weekday != DateTime.sunday && offset.abs() <= 14) {
      for (var i = 0; i < _visitPlan.length; i++) {
        // Some days are lighter: a stable pattern per date.
        if ((d.day + i) % 3 == 0 && offset != 0) continue;
        final (h, m, pid, reason, video) = _visitPlan[i];
        final p = byId(pid);
        if (p == null) continue;
        final id = 'ex-${d.year}${d.month}${d.day}-$i';
        final at = DateTime(d.year, d.month, d.day, h, m);
        final status = _visitStatus[id] != null ? VisitStatus.values.byName(_visitStatus[id]!) : (d.isBefore(today) ? VisitStatus.completed : VisitStatus.upcoming);
        out.add(Visit(id: id, patientId: pid, patientName: p.name, at: at, reason: reason, video: video, status: status));
      }
    }
    out.addAll(_visits.where((v) => _day(v.at) == d));
    final myId = _myDoctorId;
    if (myId != null) {
      for (final p in patients.where((p) => p.store != null)) {
        for (final a in p.store!.appointments.where((a) => a.doctorId == myId && _day(a.at) == d && a.status != ApptStatus.cancelled)) {
          final id = 'pt-${p.id}-${a.id}';
          final status = _visitStatus[id] != null
              ? VisitStatus.values.byName(_visitStatus[id]!)
              : a.status == ApptStatus.completed
                  ? VisitStatus.completed
                  : VisitStatus.upcoming;
          final who = a.forMember == 'self' ? p.name : '${p.store!.memberName(a.forMember)} (${p.name})';
          out.add(Visit(id: id, patientId: p.id, patientName: who, at: a.at, reason: a.reason, video: a.mode == ApptMode.video, status: status, bookedByPatient: true));
        }
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  List<Visit> upcomingFor(String patientId) {
    final now = DateTime.now();
    return [for (var i = 0; i < 14; i++) ...visitsOn(now.add(Duration(days: i)))].where((v) => v.patientId == patientId && v.status == VisitStatus.upcoming && v.at.isAfter(now.subtract(const Duration(hours: 1)))).toList();
  }

  Future<void> setVisitStatus(Visit v, VisitStatus s, {String note = ''}) async {
    v.status = s;
    final own = _visits.where((x) => x.id == v.id).firstOrNull;
    if (own != null) {
      own.status = s;
    } else {
      _visitStatus[v.id] = s.name;
    }
    // Tell the patient's own app when they booked it there.
    if (v.bookedByPatient) {
      final p = byId(v.patientId);
      final apptId = v.id.split('-').last;
      final a = p?.store?.appointments.where((a) => a.id == apptId).firstOrNull;
      if (a != null && p?.source != PatientSource.live) {
        a.status = s == VisitStatus.completed ? ApptStatus.completed : s == VisitStatus.cancelled ? ApptStatus.cancelled : a.status;
        await p!.store!.save();
      }
    }
    if (note.trim().isNotEmpty) await addNote(v.patientId, 'consult', note);
    await _save();
  }

  Future<void> book(CarePatient p, DateTime at, String reason, {required bool video}) async {
    _visits.add(Visit(id: _id(), patientId: p.id, patientName: p.name, at: at, reason: reason.trim().isEmpty ? 'Follow-up' : reason.trim(), video: video));
    // Patients with an account see it in their own Care tab.
    final myId = _myDoctorId;
    if (myId != null && p.store != null && p.source == PatientSource.account) {
      p.store!.appointments.add(Appointment(id: _id(), doctorId: myId, forMember: 'self', at: at, mode: video ? ApptMode.video : ApptMode.clinic, reason: reason.trim().isEmpty ? 'Follow-up' : reason.trim(), notes: 'Booked by $me'));
      await p.store!.save();
    }
    await _save();
  }

  // ---------------------------------------------------------------- nursing

  static String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The shift's tasks, built from the ward's beds and the home patient.
  List<NurseTask> tasksFor(List<String> bedNames) {
    String bed(int i) => bedNames.isEmpty ? 'Bed A${i + 1}' : bedNames[i % bedNames.length];
    final live = byId(livePatientId)?.name ?? 'home patient';
    return [
      const NurseTask('v08', 8, 'Vitals round', 'All occupied beds: NEWS2 for each', 'vitals'),
      NurseTask('m09', 9, 'Morning medicines', '${bed(0)}: metoprolol 25 mg · ${bed(1)}: insulin before breakfast', 'meds'),
      NurseTask('h10', 10, 'Home check by video', '$live: band fit, wound and how she feels', 'check'),
      const NurseTask('v12', 12, 'Vitals round', 'All occupied beds', 'vitals'),
      NurseTask('c13', 13, 'Fluid balance chart', bed(2), 'care'),
      NurseTask('m14', 14, 'Afternoon medicines', '${bed(3)}: antibiotics IV · ${bed(0)}: aspirin', 'meds'),
      const NurseTask('v16', 16, 'Vitals round', 'All occupied beds', 'vitals'),
      NurseTask('c18', 18, 'Wound dressing', bed(4), 'care'),
      const NurseTask('h20', 20, 'Handover to the next shift', 'Write the handover note below', 'handover'),
    ];
  }

  String? doneBy(String taskId, [DateTime? day]) => _done['${dayKey(day ?? DateTime.now())}|$taskId'];

  Future<void> toggleTask(String taskId) async {
    final k = '${dayKey(DateTime.now())}|$taskId';
    if (_done.containsKey(k)) {
      _done.remove(k);
    } else {
      final t = DateTime.now();
      _done[k] = '$me · ${t.hour % 12 == 0 ? 12 : t.hour % 12}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
    }
    await _save();
  }

  Future<void> addHandover(String text) async {
    handovers.insert(0, Handover(DateTime.now(), me, text.trim()));
    await _save();
  }
}
