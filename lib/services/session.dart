import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

enum Role { patient, doctor, nurse }

/// Who is signed in, and how.
///
/// Demo Mode needs no network. Real accounts use Supabase Auth: patients sign
/// up with email and password; doctors and nurses sign in with the account the
/// BT39 ward admin created for them (a row in the `staff` table).
class Session extends ChangeNotifier {
  Role? role;
  String name = '';
  String email = '';
  bool demo = true;
  String? wardId;
  bool restoring = true;

  bool get signedIn => role != null;
  bool get isStaff => role == Role.doctor || role == Role.nurse;
  String get accountId => demo ? 'demo-${role?.name}' : (_sb?.auth.currentUser?.id ?? 'local');

  SupabaseClient? get _sb => AppConfig.supabaseEnabled ? Supabase.instance.client : null;

  Future<void> restore() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final demoRole = sp.getString('bt39.demoRole');
      if (demoRole != null) {
        _setDemo(Role.values.byName(demoRole));
      } else if (_sb?.auth.currentSession != null) {
        await _loadAccount();
      }
    } catch (_) {
      role = null;
    }
    restoring = false;
    notifyListeners();
  }

  void _setDemo(Role r) {
    role = r;
    demo = true;
    wardId = null;
    name = switch (r) { Role.patient => 'Aarav Mehta', Role.doctor => 'Dr. Kavya Rao', Role.nurse => 'Nurse Anjali Singh' };
    email = switch (r) { Role.patient => 'aarav.demo@bt39.app', Role.doctor => 'demo.doctor@example.com', Role.nurse => 'demo.nurse@example.com' };
  }

  Future<void> startDemo(Role r) async {
    _setDemo(r);
    try {
      (await SharedPreferences.getInstance()).setString('bt39.demoRole', r.name);
    } catch (_) {}
    notifyListeners();
  }

  /// Reads the signed-in user's role: a `staff` row makes them a doctor or nurse.
  Future<void> _loadAccount() async {
    final sb = _sb!;
    final user = sb.auth.currentUser!;
    demo = false;
    email = user.email ?? '';
    final meta = user.userMetadata ?? {};
    Map<String, dynamic>? staff;
    try {
      staff = await sb.from('staff').select().eq('user_id', user.id).maybeSingle();
    } catch (_) {
      staff = null; // table missing or not readable: treat as a patient account
    }
    if (staff != null) {
      role = staff['role'] == 'doctor' ? Role.doctor : Role.nurse;
      name = (staff['name'] as String?) ?? email;
      wardId = staff['ward_id'] as String?;
    } else {
      role = Role.patient;
      name = (meta['name'] as String?) ?? email.split('@').first;
      wardId = null;
    }
  }

  /// Returns an error sentence, or null on success.
  Future<String?> signIn(String email, String password) async {
    final sb = _sb;
    if (sb == null) return 'Sign-in is not set up in this build. Use Demo Mode, or see the README to add your Supabase key.';
    try {
      await sb.auth.signInWithPassword(email: email.trim(), password: password);
      await _loadAccount();
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the sign-in service. Check your connection and try again.';
    }
  }

  Future<String?> signUp(String name, String email, String password) async {
    final sb = _sb;
    if (sb == null) return 'Sign-up is not set up in this build. Use Demo Mode, or see the README to add your Supabase key.';
    try {
      final r = await sb.auth.signUp(email: email.trim(), password: password, data: {'name': name.trim(), 'role': 'patient'});
      if (r.session == null) return 'CHECK_EMAIL';
      await _loadAccount();
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the sign-in service. Check your connection and try again.';
    }
  }

  Future<String?> resetPassword(String email) async {
    final sb = _sb;
    if (sb == null) return 'Password reset needs Supabase. Use Demo Mode in this build.';
    try {
      await sb.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> accessToken() async => _sb?.auth.currentSession?.accessToken;

  Future<void> signOut() async {
    try {
      (await SharedPreferences.getInstance()).remove('bt39.demoRole');
    } catch (_) {}
    if (!demo) {
      try {
        await _sb?.auth.signOut();
      } catch (_) {}
    }
    role = null;
    wardId = null;
    demo = true;
    notifyListeners();
  }
}
