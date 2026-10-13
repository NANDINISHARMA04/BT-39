import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/patient_models.dart';
import 'pulse_api.dart';

/// The doctors a patient can book. The list lives on the service (`GET /doctors`)
/// and is filled by [PatientStore.load]; every doctor is fictional.
final doctorCatalog = <Doctor>[];

/// The doctor with [id], or the first one if there is none with that id.
Doctor doctorById(String id) {
  for (final d in doctorCatalog) {
    if (d.id == id) return d;
  }
  if (doctorCatalog.isNotEmpty) return doctorCatalog.first;
  return Doctor(id: id, name: '', specialty: '', hospital: '', city: '', years: 0, rating: 0, reviews: 0, fee: 0, languages: const [], nextFreeDays: 0, about: '');
}

/// The specialities offered in the doctor sign-up form.
const specialties = ['Cardiologist', 'General Physician', 'Pulmonologist', 'Endocrinologist', 'Neurologist', 'Orthopedic', 'Pediatrician', 'Gynecologist', 'Psychiatrist', 'Dermatologist'];

/// One emergency contact on an SOS: when the message reached them and when they
/// opened it, in milliseconds after the SOS started.
typedef SosContact = ({String id, String name, int deliveredMs, int seenMs});

/// What the service did for an SOS: who it told and the location it sent.
class SosPlan {
  const SosPlan(this.id, this.contacts, this.location);
  final String id;
  final List<SosContact> contacts;
  final String location;

  factory SosPlan.fromJson(Map<String, dynamic> j) => SosPlan(
        '${j['id']}',
        [
          for (final c in (j['contacts'] as List? ?? const []))
            (
              id: '${(c as Map)['id']}',
              name: '${c['name'] ?? ''}',
              deliveredMs: (c['delivered_ms'] as num?)?.round() ?? 0,
              seenMs: (c['seen_ms'] as num?)?.round() ?? 0,
            ),
        ],
        '${j['location'] ?? ''}',
      );
}

/// Everything the patient app shows about the person: profile, family,
/// appointments, records, insurance and preferences.
///
/// The document lives on the PulseOS service, one per account. A change shows
/// at once on screen, is sent to the service, and the whole document the
/// service answers with replaces the local copy. If the service refuses, the
/// document is read again and [error] says why.
class PatientStore extends ChangeNotifier {
  PulseApi? api;
  String _account = '';

  /// Counts loads. A reply that belongs to an earlier load is dropped, so a
  /// slow answer for the last account cannot land in the next one.
  int _gen = 0;
  bool _disposed = false;

  UserProfile profile = UserProfile(name: '');
  List<FamilyMember> family = [];
  List<Appointment> appointments = [];
  List<MedicalRecord> records = [];
  List<InsurancePolicy> policies = [];
  List<Claim> claims = [];
  Preferences prefs = Preferences();
  bool loaded = false;

  /// The service's sentence for the last request that failed, until one succeeds.
  String? error;

  final _rnd = Random();
  String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 20).toRadixString(36)}';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ------------------------------------------------------------------ loading

  String _name = '', _email = '';
  Map<String, String> _details = const {};

  /// Reads the account's document and the doctor directory from the service.
  /// [name], [email] and [details] only fill in the profile until the answer
  /// arrives; the service already has them and seeds a new account itself.
  Future<void> load(PulseApi api, String account, {required String name, String email = '', Map<String, String> details = const {}}) async {
    this.api = api;
    _account = account;
    _name = name;
    _email = email;
    _details = details;
    final gen = ++_gen;
    loaded = false;
    error = null;
    _pending = 0;
    _tail = Future.value();
    _slots.clear();
    _slotsBusy.clear();
    profile = UserProfile(name: name, email: email, phone: details['phone'] ?? '', age: int.tryParse(details['age'] ?? '') ?? 30, sex: details['sex'] ?? 'F');
    family = [];
    appointments = [];
    records = [];
    policies = [];
    claims = [];
    prefs = Preferences();
    // The app starts this from initState. Telling listeners while the page is
    // being built would be an error, so the news waits until the build is over.
    scheduleMicrotask(_notify);
    final got = await Future.wait([api.get('/me/data'), api.get('/doctors')]);
    if (gen != _gen || _disposed) return;
    final me = got[0], docs = got[1];
    if (!me.ok || !docs.ok) {
      error = (!me.ok ? me : docs).message;
      _notify();
      return;
    }
    _fromJson(me.map);
    _setDoctors(docs.map);
    loaded = true;
    _notify();
  }

  /// Tries the last [load] again, e.g. after the service was asleep.
  Future<void> reload() {
    final a = api;
    return a == null ? Future.value() : load(a, _account, name: _name, email: _email, details: _details);
  }

  void _setDoctors(Map<String, dynamic> j) {
    final list = [for (final d in (j['doctors'] as List? ?? const [])) Doctor.fromJson(Map<String, dynamic>.from(d as Map))];
    if (list.isEmpty) return;
    doctorCatalog
      ..clear()
      ..addAll(list);
  }

  /// Takes the service's document. A part it leaves out stays as it is.
  void _fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(Object? e) => Map<String, dynamic>.from(e as Map);
    List<T> list<T>(Object? v, T Function(Map<String, dynamic>) f) => [for (final e in (v as List? ?? const [])) f(m(e))];
    if (j['profile'] is Map) profile = UserProfile.fromJson(m(j['profile']));
    if (j['family'] is List) family = list(j['family'], FamilyMember.fromJson);
    if (j['appointments'] is List) appointments = list(j['appointments'], Appointment.fromJson);
    if (j['records'] is List) records = list(j['records'], MedicalRecord.fromJson);
    if (j['policies'] is List) policies = list(j['policies'], InsurancePolicy.fromJson);
    if (j['claims'] is List) claims = list(j['claims'], Claim.fromJson);
    if (j['prefs'] is Map) prefs = Preferences.fromJson(m(j['prefs']));
  }

  // ------------------------------------------------------------------ writing

  int _pending = 0;
  Future<void> _tail = Future.value();

  /// Sends one change. Changes go to the service one at a time, in order. The
  /// document in the answer to the last one replaces the local copy (an earlier
  /// answer would leave out the changes after it). When the service refuses, the
  /// document is read again so the screen shows what is really saved.
  /// [slots] drops the cached free times, because a booking changes them.
  Future<void> _write(Future<ApiResult> Function(PulseApi api) send, {bool slots = false}) async {
    final api = this.api;
    if (api == null) return;
    final gen = _gen;
    _pending++;
    final before = _tail;
    final turn = Completer<void>();
    _tail = turn.future;
    try {
      await before;
      if (gen != _gen || _disposed) return;
      final r = await send(api);
      if (gen != _gen || _disposed) return;
      if (r.ok) {
        error = null;
        if (_pending == 1 && r.map.containsKey('profile')) _fromJson(r.map);
      } else {
        error = r.message;
        final fresh = await api.get('/me/data');
        if (gen == _gen && !_disposed && fresh.ok) _fromJson(fresh.map);
      }
    } finally {
      if (gen == _gen) {
        _pending--;
        if (slots) _slots.clear();
      }
      turn.complete();
      _notify();
    }
  }

  static String _id(String id) => Uri.encodeComponent(id);

  // ---- profile & prefs
  Future<void> updateProfile(void Function(UserProfile p) f) {
    f(profile);
    _notify();
    return _write((a) => a.put('/me/profile', profile.toJson()));
  }

  Future<void> updatePrefs(void Function(Preferences p) f) {
    f(prefs);
    _notify();
    return _write((a) => a.put('/me/prefs', prefs.toJson()));
  }

  // ---- family
  String memberName(String id) => id == 'self' ? 'You' : family.firstWhere((m) => m.id == id, orElse: () => FamilyMember(id: id, name: 'Removed member', relation: '', age: 0)).name;
  List<FamilyMember> get emergencyContacts => family.where((m) => m.emergencyContact).toList();
  FamilyMember? get caregiver => family.where((m) => m.caregiver).firstOrNull;

  Future<void> upsertMember(FamilyMember m) {
    final i = family.indexWhere((x) => x.id == m.id);
    i < 0 ? family.add(m) : family[i] = m;
    _notify();
    return _write((a) => a.put('/me/family/${_id(m.id)}', m.toJson()));
  }

  Future<void> deleteMember(String id) {
    family.removeWhere((m) => m.id == id);
    for (final a in appointments) {
      if (a.forMember == id) a.status = ApptStatus.cancelled;
    }
    _notify();
    return _write((a) => a.delete('/me/family/${_id(id)}'), slots: true);
  }

  // ---- appointments
  List<Appointment> get upcoming => appointments.where((a) => a.status == ApptStatus.upcoming && a.at.isAfter(DateTime.now().subtract(const Duration(hours: 1)))).toList()..sort((a, b) => a.at.compareTo(b.at));
  List<Appointment> get past => appointments.where((a) => !upcoming.contains(a)).toList()..sort((a, b) => b.at.compareTo(a.at));

  Future<void> upsertAppointment(Appointment a) {
    final i = appointments.indexWhere((x) => x.id == a.id);
    i < 0 ? appointments.add(a) : appointments[i] = a;
    _notify();
    return _write((api) => api.put('/me/appointments/${_id(a.id)}', a.toJson()), slots: true);
  }

  Future<void> cancelAppointment(String id) {
    final a = appointments.where((x) => x.id == id).firstOrNull;
    if (a != null) a.status = ApptStatus.cancelled;
    _notify();
    return _write((api) => api.post('/me/appointments/${_id(id)}/cancel'), slots: true);
  }

  Future<void> deleteAppointment(String id) {
    appointments.removeWhere((a) => a.id == id);
    _notify();
    return _write((api) => api.delete('/me/appointments/${_id(id)}'), slots: true);
  }

  // ---- free times

  /// Free times already fetched, by doctor and the appointment being moved.
  final Map<String, ({Map<String, List<DateTime>> days, DateTime at})> _slots = {};
  final Set<String> _slotsBusy = {};
  static const _slotsTtl = Duration(minutes: 5);

  static String _dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _slotKey(Doctor d, String? except) => '${d.id}|${except ?? ''}';

  /// Free 30-minute times for a doctor on a day. The service works them out
  /// (`GET /doctors/{id}/slots`), minus times anyone has booked. The first call
  /// for a doctor returns an empty list and fetches; the store notifies when
  /// the times arrive. [exceptAppt] keeps that appointment's own time free, for
  /// moving it. Times that have since come within 30 minutes of now are left
  /// out, as the service does when it answers.
  List<DateTime> slotsFor(Doctor d, DateTime date, {String? exceptAppt}) {
    final have = _slots[_slotKey(d, exceptAppt)];
    if (have == null || DateTime.now().difference(have.at) > _slotsTtl) _fetchSlots(d, exceptAppt);
    final soonest = DateTime.now().add(const Duration(minutes: 30));
    return [
      for (final s in have?.days[_dayKey(date)] ?? const <DateTime>[])
        if (!s.isBefore(soonest)) s,
    ];
  }

  /// True until the first answer for this doctor has arrived.
  bool slotsLoading(Doctor d, {String? exceptAppt}) => _slotsBusy.contains(_slotKey(d, exceptAppt)) || !_slots.containsKey(_slotKey(d, exceptAppt));

  Future<void> _fetchSlots(Doctor d, String? except) async {
    final api = this.api;
    final key = _slotKey(d, except);
    if (api == null || !_slotsBusy.add(key)) return;
    final gen = _gen;
    final query = 'from=${_dayKey(DateTime.now())}&days=14${except == null ? '' : '&except=${Uri.encodeQueryComponent(except)}'}';
    final r = await api.get('/doctors/${_id(d.id)}/slots?$query');
    if (gen != _gen || _disposed) return;
    _slotsBusy.remove(key);
    if (r.ok) {
      final days = <String, List<DateTime>>{};
      for (final e in ((r.map['days'] as Map?) ?? const {}).entries) {
        days['${e.key}'] = [for (final s in (e.value as List)) DateTime.parse('$s').toLocal()];
      }
      _slots[key] = (days: days, at: DateTime.now());
    } else {
      // Try again in about 15 seconds, the next time the page asks.
      _slots[key] = (days: const {}, at: DateTime.now().subtract(_slotsTtl - const Duration(seconds: 15)));
    }
    _notify();
  }

  // ---- records
  Future<void> upsertRecord(MedicalRecord r) {
    final i = records.indexWhere((x) => x.id == r.id);
    i < 0 ? records.insert(0, r) : records[i] = r;
    _notify();
    return _write((a) => a.put('/me/records/${_id(r.id)}', r.toJson()));
  }

  Future<void> deleteRecord(String id) {
    records.removeWhere((r) => r.id == id);
    for (final c in claims) {
      c.recordIds.remove(id);
    }
    _notify();
    return _write((a) => a.delete('/me/records/${_id(id)}'));
  }

  // ---- insurance
  Future<void> upsertPolicy(InsurancePolicy p) {
    final i = policies.indexWhere((x) => x.id == p.id);
    i < 0 ? policies.add(p) : policies[i] = p;
    _notify();
    return _write((a) => a.put('/me/policies/${_id(p.id)}', p.toJson()));
  }

  Future<void> deletePolicy(String id) {
    policies.removeWhere((p) => p.id == id);
    claims.removeWhere((c) => c.policyId == id);
    _notify();
    return _write((a) => a.delete('/me/policies/${_id(id)}'));
  }

  int usedOf(InsurancePolicy p) => claims.where((c) => c.policyId == p.id && (c.status == ClaimStatus.approved || c.status == ClaimStatus.paid)).fold(0, (a, c) => a + (c.approved ?? c.amount));

  Future<void> upsertClaim(Claim c) {
    final i = claims.indexWhere((x) => x.id == c.id);
    i < 0 ? claims.insert(0, c) : claims[i] = c;
    _notify();
    return _write((a) => a.put('/me/claims/${_id(c.id)}', c.toJson()));
  }

  Future<void> deleteClaim(String id) {
    claims.removeWhere((c) => c.id == id);
    _notify();
    return _write((a) => a.delete('/me/claims/${_id(id)}'));
  }

  /// Demo only: moves a claim one step along, as the insurer would.
  Future<void> advanceClaim(Claim c) {
    final next = switch (c.status) {
      ClaimStatus.submitted => ClaimStatus.underReview,
      ClaimStatus.underReview => ClaimStatus.approved,
      ClaimStatus.approved => ClaimStatus.paid,
      _ => null,
    };
    if (next == null) return Future.value();
    if (next == ClaimStatus.approved) c.approved ??= (c.amount * .94).round();
    c.timeline.add(ClaimEvent(next, DateTime.now(), next == ClaimStatus.underReview ? 'Documents received' : ''));
    _notify();
    return _write((a) => a.post('/me/claims/${_id(c.id)}/advance'));
  }

  // ---- SOS

  /// Tells the service the person pressed SOS (or that [alertId] triggered it).
  /// It records it and answers with who it told. Null when it could not.
  Future<SosPlan?> startSos({int? alertId}) async {
    final api = this.api;
    if (api == null) return null;
    final r = await api.post('/sos', {'alert_id': alertId});
    if (!r.ok) {
      error = r.message;
      _notify();
      return null;
    }
    return SosPlan.fromJson(r.map);
  }

  /// Records that the SOS [id] is over.
  Future<void> endSos(String id) async {
    await api?.post('/sos/${_id(id)}/end');
  }
}
