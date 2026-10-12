import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

enum Role { patient, doctor, nurse }

/// demo: no account. local: an account stored on this device. cloud: Supabase.
enum AuthMode { demo, local, cloud }

const roleLabel = {Role.patient: 'Patient', Role.doctor: 'Doctor', Role.nurse: 'Nurse'};

/// Accounts that exist on every device, so anyone can try each role.
const demoAccounts = {
  Role.patient: ('patient@adaptalert.app', 'patient123', 'Aarav Mehta'),
  Role.doctor: ('doctor@adaptalert.app', 'doctor123', 'Dr. Kavya Rao'),
  Role.nurse: ('nurse@adaptalert.app', 'nurse123', 'Nurse Anjali Singh'),
};

/// Who is signed in, and how.
///
/// Demo Mode needs no account. Without a Supabase key, accounts live on this
/// device: passwords are stored only as salted SHA-256 hashes. With a key,
/// accounts use Supabase Auth; doctors and nurses then need a row in the BT39
/// `staff` table.
class Session extends ChangeNotifier {
  Role? role;
  String name = '';
  String email = '';
  AuthMode mode = AuthMode.demo;
  String? wardId;

  /// Extra sign-up details: age, sex and phone for patients; registration
  /// number, speciality, hospital, ward or shift for staff.
  Map<String, String> details = {};

  bool get demo => mode == AuthMode.demo;

  /// True when nothing is sent to a server (Demo Mode or a device account).
  bool get onDevice => mode != AuthMode.cloud;
  bool restoring = true;

  /// Set when the person asked for the guided demo; the patient app starts it.
  bool pendingTour = false;

  bool get signedIn => role != null;
  bool get isStaff => role == Role.doctor || role == Role.nurse;
  String get accountId => switch (mode) {
        AuthMode.demo => 'demo-${role?.name}',
        AuthMode.local => 'local-${email.toLowerCase()}',
        AuthMode.cloud => _sb?.auth.currentUser?.id ?? 'local',
      };

  SupabaseClient? get _sb => AppConfig.supabaseEnabled ? Supabase.instance.client : null;

  Future<void> restore() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final demoRole = sp.getString('bt39.demoRole');
      final localUser = sp.getString('bt39.localUser');
      if (demoRole != null) {
        _setDemo(Role.values.byName(demoRole));
      } else if (localUser != null && (await _accounts())[localUser] != null) {
        _setLocal(localUser, (await _accounts())[localUser]!);
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
    mode = AuthMode.demo;
    details = {};
    wardId = null;
    name = switch (r) { Role.patient => 'Aarav Mehta', Role.doctor => 'Dr. Kavya Rao', Role.nurse => 'Nurse Anjali Singh' };
    email = switch (r) { Role.patient => 'aarav.demo@bt39.app', Role.doctor => 'demo.doctor@example.com', Role.nurse => 'demo.nurse@example.com' };
  }

  Future<void> startDemo(Role r, {bool tour = false}) async {
    _setDemo(r);
    pendingTour = tour;
    try {
      (await SharedPreferences.getInstance()).setString('bt39.demoRole', r.name);
    } catch (_) {}
    notifyListeners();
  }

  /// Reads the signed-in user's role: a `staff` row makes them a doctor or nurse.
  Future<void> _loadAccount() async {
    final sb = _sb!;
    final user = sb.auth.currentUser!;
    mode = AuthMode.cloud;
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

  // ---------------------------------------------------------------- device accounts

  static String _hash(String salt, String password) => sha256.convert(utf8.encode('$salt:$password')).toString();

  Future<Map<String, Map<String, dynamic>>> _accounts() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('bt39.accounts');
    final out = <String, Map<String, dynamic>>{};
    if (raw != null) {
      try {
        (jsonDecode(raw) as Map).forEach((k, v) => out[k as String] = Map<String, dynamic>.from(v as Map));
      } catch (_) {}
    }
    // The three demo accounts always exist.
    for (final e in demoAccounts.entries) {
      final (mail, pw, nm) = e.value;
      out.putIfAbsent(mail, () => {'role': e.key.name, 'name': nm, 'salt': 'demo', 'hash': _hash('demo', pw), 'details': <String, String>{}});
    }
    return out;
  }

  Future<void> _saveAccounts(Map<String, Map<String, dynamic>> a) async => (await SharedPreferences.getInstance()).setString('bt39.accounts', jsonEncode(a));

  void _setLocal(String mail, Map<String, dynamic> acc) {
    mode = AuthMode.local;
    email = mail;
    role = Role.values.byName(acc['role'] as String);
    name = acc['name'] as String;
    wardId = null;
    details = Map<String, String>.from((acc['details'] as Map?) ?? {});
  }

  /// Signs in with a device account. [as] is the role the person chose; a
  /// matching account of another role is refused with a clear message.
  Future<String?> localSignIn(String email, String password, {required Role as}) async {
    final mail = email.trim().toLowerCase();
    final acc = (await _accounts())[mail];
    if (acc == null || _hash(acc['salt'] as String, password) != acc['hash']) return 'That email and password don\'t match an account on this device.';
    final r = Role.values.byName(acc['role'] as String);
    if (r != as) return 'This is a ${roleLabel[r]!.toLowerCase()} account. Go back and choose ${roleLabel[r]}.';
    _setLocal(mail, acc);
    try {
      (await SharedPreferences.getInstance()).setString('bt39.localUser', mail);
    } catch (_) {}
    notifyListeners();
    return null;
  }

  Future<String?> localSignUp({required Role role, required String name, required String email, required String password, Map<String, String> details = const {}}) async {
    final mail = email.trim().toLowerCase();
    final all = await _accounts();
    if (all.containsKey(mail)) return 'An account with this email already exists on this device. Log in instead.';
    final rnd = Random.secure();
    final salt = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    all[mail] = {'role': role.name, 'name': name.trim(), 'salt': salt, 'hash': _hash(salt, password), 'details': details};
    try {
      await _saveAccounts(all);
    } catch (_) {
      return 'This browser is blocking storage, so the account can\'t be saved. Use the demo account instead.';
    }
    return localSignIn(mail, password, as: role);
  }

  Future<String?> accessToken() async => _sb?.auth.currentSession?.accessToken;

  Future<void> signOut() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove('bt39.demoRole');
      await sp.remove('bt39.localUser');
    } catch (_) {}
    if (mode == AuthMode.cloud) {
      try {
        await _sb?.auth.signOut();
      } catch (_) {}
    }
    role = null;
    wardId = null;
    mode = AuthMode.demo;
    details = {};
    notifyListeners();
  }
}
