import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/msg.dart';
import '../models/patient_models.dart';
import 'pulse_api.dart';
import 'session.dart';

/// Where a patient in the doctor's and nurse's list comes from.
enum PatientSource { live, account, example }

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.round() ?? 0;
Map<String, dynamic> _obj(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
DateTime _at(Object? v) => DateTime.tryParse('$v')?.toLocal() ?? DateTime.now();

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
    this.hasStore = false,
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

  /// True when the patient has an account with saved data (their own medicine
  /// list, records and appointments), as opposed to a new or example patient.
  final bool hasStore;

  bool get live => source == PatientSource.live;

  factory CarePatient.fromJson(Map<String, dynamic> j) {
    final v = j['vitals'];
    return CarePatient(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      age: _i(j['age']),
      sex: '${j['sex'] ?? ''}',
      condition: '${j['condition'] ?? ''}',
      source: PatientSource.values.asNameMap()['${j['source']}'] ?? PatientSource.example,
      bloodGroup: '${j['bloodGroup'] ?? 'O+'}',
      phone: '${j['phone'] ?? ''}',
      email: j['email'] as String?,
      conditions: [for (final c in (j['conditions'] as List? ?? const [])) '$c'],
      allergies: [for (final c in (j['allergies'] as List? ?? const [])) '$c'],
      medications: [for (final m in (j['medications'] as List? ?? const [])) Medication.fromJson(_obj(m))],
      records: [for (final r in (j['records'] as List? ?? const [])) MedicalRecord.fromJson(_obj(r))],
      vitals: v is Map ? (hr: _i(v['hr']), spo2: _i(v['spo2']), temp: _d(v['temp'])) : null,
      status: '${j['status'] ?? 'Stable'}',
      learned: j['learned'] as String?,
      hasStore: j['hasStore'] == true,
    );
  }
}

class ClinicalNote {
  ClinicalNote({required this.id, required this.patientId, required this.at, required this.kind, required this.text, required this.by});
  final String id, patientId, kind, text, by; // kind: note | prescription | consult | nursing
  final DateTime at;
  Map<String, dynamic> toJson() => {'id': id, 'patientId': patientId, 'at': at.toUtc().toIso8601String(), 'kind': kind, 'text': text, 'by': by};
  factory ClinicalNote.fromJson(Map<String, dynamic> j) => ClinicalNote(id: '${j['id']}', patientId: '${j['patientId']}', at: _at(j['at']), kind: '${j['kind'] ?? 'note'}', text: '${j['text'] ?? ''}', by: '${j['by'] ?? ''}');
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
  Map<String, dynamic> toJson() => {'id': id, 'patientId': patientId, 'patientName': patientName, 'at': at.toUtc().toIso8601String(), 'reason': reason, 'video': video, 'status': status.name, 'bookedByPatient': bookedByPatient};
  factory Visit.fromJson(Map<String, dynamic> j) {
    // The service writes `noShow`; `no_show` and `noshow` are read the same.
    final s = '${j['status'] ?? 'upcoming'}'.replaceAll('_', '').toLowerCase();
    return Visit(
      id: '${j['id']}',
      patientId: '${j['patientId']}',
      patientName: '${j['patientName'] ?? ''}',
      at: _at(j['at']),
      reason: '${j['reason'] ?? ''}',
      video: j['video'] == true,
      status: VisitStatus.values.where((v) => v.name.toLowerCase() == s).firstOrNull ?? VisitStatus.upcoming,
      bookedByPatient: j['bookedByPatient'] == true,
    );
  }
}

/// A nursing task for one shift. The service writes the title and detail as
/// messages, so they follow the app's language.
class NurseTask {
  const NurseTask(this.id, this.hour, Object? title, Object? detail, this.kind)
      : _title = title,
        _detail = detail;
  final String id, kind; // kind: vitals | meds | check | care | handover
  final int hour;
  final Object? _title, _detail;
  String get title => msg(_title);
  String get detail => msg(_detail);

  factory NurseTask.fromJson(Map<String, dynamic> j) => NurseTask('${j['id']}', _i(j['hour']), j['title'], j['detail'], '${j['kind'] ?? 'check'}');
}

class Handover {
  Handover(this.at, this.by, this.text);
  final DateTime at;
  final String by, text;
  Map<String, dynamic> toJson() => {'at': at.toUtc().toIso8601String(), 'by': by, 'text': text};
  factory Handover.fromJson(Map<String, dynamic> j) => Handover(_at(j['at']), '${j['by'] ?? ''}', '${j['text'] ?? ''}');
}

/// The live home patient: the demo patient account, monitored by a band.
const livePatientId = 'live';

/// What the doctor and nurse apps show: patients, notes, prescriptions,
/// visits, nursing tasks and handovers.
///
/// All of it lives on the PulseOS service and is shared by every staff account
/// (`GET /care/state`), so a doctor's note is there for the nurse. Each change
/// is sent to the service, which answers with the whole state again.
class ClinicalStore extends ChangeNotifier {
  ClinicalStore(this.session);
  final Session session;

  PulseApi get _api => session.api;

  bool loaded = false;

  /// The sentence for the last request that failed, until one succeeds.
  String? error;

  List<CarePatient> _patients = [];
  List<ClinicalNote> _notes = [];
  Map<String, List<Visit>> _visits = {};
  Map<String, List<DateTime>> _slots = {};
  List<String> _beds = [];
  List<NurseTask> _tasks = [];
  Map<String, String> _done = {};
  List<Handover> _handovers = [];
  bool _disposed = false;

  List<CarePatient> get patients => _patients;
  List<Handover> get handovers => _handovers;

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---------------------------------------------------------------- state

  /// The bed names the tasks were last asked for.
  List<String> _asked = [];

  Future<void> _tail = Future.value();

  /// Runs requests one at a time, in the order they were made, so an old
  /// answer can never replace a newer one.
  Future<T> _inOrder<T>(Future<T> Function() job) async {
    final before = _tail;
    final turn = Completer<void>();
    _tail = turn.future;
    await before;
    try {
      return await job();
    } finally {
      turn.complete();
    }
  }

  Future<void> load() async {
    loaded = await _fetch();
    _notify();
  }

  /// Reads the state again, picking up patients who signed up since.
  Future<void> refreshPatients() async {
    await _fetch();
    _notify();
  }

  Future<bool> _fetch() => _inOrder(() async {
        final beds = _asked.isEmpty ? '' : '?beds=${Uri.encodeQueryComponent(_asked.join(','))}';
        final r = await _api.get('/care/state$beds');
        return !_disposed && _take(r);
      });

  /// Sends one change; the answer is the whole state, which replaces ours.
  /// A change is not sent with the ward's beds, so when the tasks were built for
  /// a list of beds the answer's tasks (built for no beds) are not taken.
  Future<bool> _send(Future<ApiResult> Function(PulseApi api) call) async {
    final ok = await _inOrder(() async {
      final r = await call(_api);
      return !_disposed && _take(r, tasks: _asked.isEmpty);
    });
    _notify();
    return ok;
  }

  bool _take(ApiResult r, {bool tasks = true}) {
    if (!r.ok) {
      error = r.message;
      return false;
    }
    error = null;
    final j = r.map;
    if (j['patients'] is List) _patients = [for (final p in j['patients'] as List) CarePatient.fromJson(_obj(p))];
    if (j['notes'] is List) _notes = [for (final n in j['notes'] as List) ClinicalNote.fromJson(_obj(n))];
    if (j['visits'] is Map) {
      _visits = {
        for (final e in _obj(j['visits']).entries) e.key: [for (final v in (e.value as List? ?? const [])) Visit.fromJson(_obj(v))],
      };
    }
    if (j['slots'] is Map) {
      _slots = {
        for (final e in _obj(j['slots']).entries) e.key: [for (final s in (e.value as List? ?? const [])) _at(s)],
      };
    }
    if (tasks && j['beds'] is List) _beds = [for (final b in j['beds'] as List) '$b'];
    if (tasks && j['tasks'] is List) _tasks = [for (final t in j['tasks'] as List) NurseTask.fromJson(_obj(t))];
    if (j['done'] is Map) _done = {for (final e in _obj(j['done']).entries) e.key: '${e.value}'};
    if (j['handovers'] is List) _handovers = [for (final h in j['handovers'] as List) Handover.fromJson(_obj(h))];
    return true;
  }

  CarePatient? byId(String id) => _patients.where((p) => p.id == id).firstOrNull;

  // ---------------------------------------------------------------- notes

  List<ClinicalNote> notesFor(String patientId) => _notes.where((n) => n.patientId == patientId).toList()..sort((a, b) => b.at.compareTo(a.at));

  Future<void> addNote(String patientId, String kind, String text) => _send((a) => a.post('/care/notes', {'patient_id': patientId, 'kind': kind, 'text': text.trim()}));

  /// Saves a prescription as a note and, when the patient has an account, adds
  /// the medicine to their own medicine list. Returns true when it was added to
  /// the patient's own list.
  Future<bool> prescribe(CarePatient p, Medication m, {String days = ''}) async {
    final ok = await _send((a) => a.post('/care/prescribe', {'patient_id': p.id, 'medication': m.toJson(), 'days': days.trim()}));
    return ok && p.hasStore && p.source != PatientSource.example;
  }

  // ---------------------------------------------------------------- visits

  /// All visits on [day] from the loaded window (yesterday to two weeks ahead):
  /// example visits, visits the doctor booked, and visits patients booked.
  List<Visit> visitsOn(DateTime day) => [...?_visits[dayKey(day)]]..sort((a, b) => a.at.compareTo(b.at));

  List<Visit> upcomingFor(String patientId) {
    final now = DateTime.now();
    return [for (var i = 0; i < 14; i++) ...visitsOn(now.add(Duration(days: i)))].where((v) => v.patientId == patientId && v.status == VisitStatus.upcoming && v.at.isAfter(now.subtract(const Duration(hours: 1)))).toList();
  }

  Future<void> setVisitStatus(Visit v, VisitStatus s, {String note = ''}) async {
    final was = v.status;
    v.status = s;
    _notify();
    final ok = await _send((a) => a.post('/care/visits/${Uri.encodeComponent(v.id)}/status', {'status': s.name, 'note': note.trim()}));
    if (!ok && v.status == s) {
      v.status = was;
      _notify();
    }
  }

  Future<void> book(CarePatient p, DateTime at, String reason, {required bool video}) =>
      _send((a) => a.post('/care/visits', {'patient_id': p.id, 'at': at.toUtc().toIso8601String(), 'reason': reason.trim().isEmpty ? 'Follow-up' : reason.trim(), 'video': video}));

  /// The days the booking sheet offers (the next week, without Sundays), as
  /// calendar days in the phone's time zone.
  List<DateTime> bookingDays() {
    final out = <DateTime>[];
    for (final k in _slots.keys) {
      final d = _parseDay(k);
      if (d != null) out.add(d);
    }
    return out..sort();
  }

  /// Free times on [day] for a new visit, sorted. Times that have since come
  /// within 15 minutes of now are left out, as the service does when it answers.
  List<DateTime> bookingSlots(DateTime day) {
    final soonest = DateTime.now().add(const Duration(minutes: 15));
    return [
      for (final s in _slots[dayKey(day)] ?? const <DateTime>[])
        if (s.isAfter(soonest)) s,
    ]..sort();
  }

  static DateTime? _parseDay(String k) {
    final p = k.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
    return y == null || m == null || d == null ? null : DateTime(y, m, d);
  }

  // ---------------------------------------------------------------- nursing

  static String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Timer? _debounce;
  List<String>? _waiting;

  /// The shift's tasks, built by the service from the ward's beds. When
  /// [bedNames] is not the list the tasks were built for, the state is read
  /// again (after a short pause, since this is called while building the page)
  /// and the tasks we have are returned meanwhile.
  List<NurseTask> tasksFor(List<String> bedNames) {
    if (listEquals(bedNames, _asked) || listEquals(bedNames, _beds)) {
      _debounce?.cancel();
      _waiting = null;
    } else if (!listEquals(bedNames, _waiting)) {
      _debounce?.cancel();
      _waiting = List.of(bedNames);
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (_disposed) return;
        _asked = _waiting ?? bedNames;
        _waiting = null;
        refreshPatients();
      });
    }
    return _tasks;
  }

  String? doneBy(String taskId, [DateTime? day]) => day != null && dayKey(day) != dayKey(DateTime.now()) ? null : _done[taskId];

  Future<void> toggleTask(String taskId) => _send((a) => a.post('/care/tasks/${Uri.encodeComponent(taskId)}/toggle'));

  Future<void> addHandover(String text) => _send((a) => a.post('/care/handovers', {'text': text.trim()}));
}
