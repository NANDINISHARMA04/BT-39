import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../l10n/l10n.dart';
import 'pulse_api.dart';

enum Role { patient, doctor, nurse }

/// demo: a Demo Mode visit on the service, no account. cloud: a Supabase account.
enum AuthMode { demo, cloud }

const roleLabel = {Role.patient: 'Patient', Role.doctor: 'Doctor', Role.nurse: 'Nurse'};

/// Accounts that exist on the service for everyone, so anyone can try each role.
const demoAccounts = {
  Role.patient: ('patient@pulseos.app', 'patient123', 'Jai'),
  Role.doctor: ('doctor@pulseos.app', 'doctor123', 'Dr. Kavya Rao'),
  Role.nurse: ('nurse@pulseos.app', 'nurse123', 'Nurse Anjali Singh'),
};

/// Who is signed in, and how.
///
/// Demo Mode needs no account: the service starts a fresh sandbox for the
/// visitor and hands back a short-lived token. Real accounts sign in with
/// Supabase Auth; the service then says whether the account is a patient, a
/// doctor or a nurse (`GET /me`). Nothing about accounts is stored on the device.
class Session extends ChangeNotifier {
  /// [supabase], [httpClient] and [apiBase] are for tests; the app passes none.
  Session({SupabaseClient? supabase, http.Client Function()? httpClient, String? apiBase})
      : _supabase = supabase,
        _httpClient = httpClient,
        _apiBase = apiBase;

  final SupabaseClient? _supabase;
  final http.Client Function()? _httpClient;
  final String? _apiBase;

  Role? role;
  String name = '';
  String email = '';
  AuthMode mode = AuthMode.demo;
  String? wardId;

  /// Extra sign-up details: age, sex and phone for patients; registration
  /// number, speciality, hospital, ward or shift for staff.
  Map<String, String> details = {};

  bool get demo => mode == AuthMode.demo;
  bool restoring = true;

  /// Set when the person asked for the guided demo; the patient app starts it.
  bool pendingTour = false;

  /// Set when someone leaves the demo to log in; the welcome page opens that
  /// role's log-in (or sign-up) form straight away.
  ({Role role, bool signUp})? pendingAuth;

  /// The role whose Demo Mode is being started. Set while the service answers
  /// (it can take a minute when it was asleep), so the page can show a spinner.
  Role? starting;

  /// Set when the service ended the Demo Mode visit (it idles out after 30
  /// minutes); the welcome page shows it and the app is signed out.
  String? expiredMessage;

  String? _demoToken;
  String? _userId;
  bool _disposed = false;

  // A reply can arrive after the app has gone (a call that was still out).
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> leaveDemoToLogIn(Role r, {bool signUp = false}) async {
    pendingAuth = (role: r, signUp: signUp);
    await signOut();
  }

  bool get signedIn => role != null;
  bool get isStaff => role == Role.doctor || role == Role.nurse;
  String get accountId => switch (mode) {
        AuthMode.demo => 'demo-${role?.name}',
        AuthMode.cloud => _userId ?? _sb?.auth.currentUser?.id ?? 'cloud',
      };

  /// Every call to the PulseOS service goes through this.
  late final PulseApi api = PulseApi(token: accessToken, base: _apiBase, client: _httpClient, onDemoExpired: _demoExpired);

  SupabaseClient? get _sb {
    if (_supabase != null) return _supabase;
    if (!AppConfig.supabaseEnabled) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null; // not initialised, as in a test
    }
  }

  /// The token the service checks: the Demo Mode token, else the account's.
  Future<String?> accessToken() async {
    if (_demoToken != null) return _demoToken;
    try {
      final sb = _sb;
      final s = sb?.auth.currentSession;
      if (sb == null || s == null) return null;
      if (s.isExpired) {
        final fresh = (await sb.auth.refreshSession()).session;
        if (fresh != null) return fresh.accessToken;
      }
      return s.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> restore() async {
    try {
      // Accounts used to live on the device. They live on the service now.
      final sp = await SharedPreferences.getInstance();
      for (final k in const ['bt39.accounts', 'bt39.localUser', 'bt39.demoRole']) {
        if (sp.containsKey(k)) await sp.remove(k);
      }
    } catch (_) {}
    // A Demo Mode visit is not restored: reopening the site starts at the
    // welcome page, so nobody gets stuck in the demo.
    try {
      if (_sb?.auth.currentSession != null) await _loadAccount(keepSessionOnFailure: true);
    } catch (_) {
      role = null;
    }
    restoring = false;
    notifyListeners();
  }

  /// Starts Demo Mode for [r]: the service makes a fresh sandbox for this
  /// visitor. Returns an error sentence, or null when the demo is running.
  Future<String?> startDemo(Role r, {bool tour = false}) async {
    if (starting != null) return null;
    starting = r;
    expiredMessage = null;
    notifyListeners();
    final res = await api.postPublic('/demo/start', {'role': r.name});
    starting = null;
    final j = res.map;
    final token = j['token'];
    if (!res.ok || token is! String || token.isEmpty) {
      notifyListeners();
      return res.ok ? tr('The service is not answering. It may be waking up. Try again in a minute.') : res.message;
    }
    _demoToken = token;
    mode = AuthMode.demo;
    role = Role.values.asNameMap()['${j['role']}'] ?? r;
    name = '${j['name'] ?? demoAccounts[role]!.$3}';
    email = '${j['email'] ?? demoAccounts[role]!.$1}';
    details = {};
    wardId = null;
    _userId = null;
    pendingTour = tour;
    notifyListeners();
    return null;
  }

  /// Reads the account's role, name and ward from the service (`GET /me`) and
  /// signs the person in to the app. Returns an error sentence, or null.
  /// [as] is the role the person chose; a matching account of another role is
  /// refused with a clear message.
  Future<String?> _loadAccount({Role? as, bool keepSessionOnFailure = false}) async {
    final sb = _sb;
    final res = await api.get('/me');
    if (!res.ok) {
      // Only a refused token ends the Supabase session; a service that is
      // asleep or unreachable leaves it for the next try.
      if (!keepSessionOnFailure || res.status == 401 || res.status == 403) await _silentSignOut(sb);
      return res.message;
    }
    final j = res.map;
    final r = Role.values.asNameMap()['${j['role']}'] ?? Role.patient;
    if (as != null && as != r) {
      await _silentSignOut(sb);
      return tr('This is a {role} account. Go back and choose {Role}.', {'role': tr(roleLabel[r]!).toLowerCase(), 'Role': tr(roleLabel[r]!)});
    }
    mode = AuthMode.cloud;
    role = r;
    email = '${j['email'] ?? sb?.auth.currentUser?.email ?? ''}';
    name = '${j['name'] ?? ''}'.isEmpty ? email.split('@').first : '${j['name']}';
    wardId = j['ward_id'] as String?;
    details = {
      for (final e in ((j['details'] as Map?) ?? const {}).entries)
        if (e.value != null) '${e.key}': '${e.value}',
    };
    _userId = sb?.auth.currentUser?.id;
    _demoToken = null;
    return null;
  }

  Future<void> _silentSignOut(SupabaseClient? sb) async {
    try {
      await sb?.auth.signOut();
    } catch (_) {}
  }

  /// Returns an error sentence, or null on success. [as] is the role the
  /// person chose on the welcome page; an account of another role is refused.
  Future<String?> signIn(String email, String password, {Role? as}) async {
    final sb = _sb;
    if (sb == null) return tr('Sign-in is not set up in this build. Use Demo Mode, or see the README to add your Supabase key.');
    try {
      await sb.auth.signInWithPassword(email: email.trim(), password: password);
    } on AuthRetryableFetchException {
      return tr('Could not reach the sign-in service. Check your connection and try again.');
    } on AuthException catch (e) {
      if (e.code == 'invalid_credentials' || e.message.toLowerCase().contains('invalid login credentials')) {
        return tr('That email and password don\'t match an account.');
      }
      return e.message;
    } catch (_) {
      return tr('Could not reach the sign-in service. Check your connection and try again.');
    }
    _demoToken = null; // an account replaces any Demo Mode visit
    final err = await _loadAccount(as: as);
    if (err != null) return err;
    expiredMessage = null;
    notifyListeners();
    return null;
  }

  /// Creates the account on the service, then signs in with it. Returns an
  /// error sentence (an email that is taken comes back as the service's own
  /// sentence), or null on success.
  Future<String?> signUp({required Role role, required String name, required String email, required String password, Map<String, String> details = const {}, bool consent = false}) async {
    final res = await api.postPublic('/signup', {
      'role': role.name,
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'details': details,
      'consent': consent,
    });
    if (!res.ok) return res.message;
    return signIn(email, password, as: role);
  }

  Future<String?> resetPassword(String email) async {
    final sb = _sb;
    if (sb == null) return tr('Password reset needs Supabase. Use Demo Mode in this build.');
    try {
      await sb.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  /// The service ended the Demo Mode visit: back to the welcome page, with a note.
  void _demoExpired() {
    if (_demoToken == null) return;
    _demoToken = null; // nothing left to end on the service
    expiredMessage = tr('Your demo session ended. Start it again to keep exploring.');
    unawaited(signOut());
  }

  Future<void> signOut() async {
    final demoToken = _demoToken;
    if (demoToken != null) {
      // Tell the service so it frees this visitor's sandbox; no need to wait.
      unawaited(PulseApi(token: () async => demoToken, base: _apiBase, client: _httpClient).post('/demo/end'));
    }
    _demoToken = null;
    if (mode == AuthMode.cloud) await _silentSignOut(_sb);
    role = null;
    name = '';
    email = '';
    wardId = null;
    mode = AuthMode.demo;
    details = {};
    _userId = null;
    notifyListeners();
  }
}
