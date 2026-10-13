import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/services/session.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/recorded_service.dart';

// Accounts live on the service now (sign-up is POST /signup, sign-in is Supabase Auth and then GET /me), so these
// tests run on the recorded service with its fake sign-in. Demo Mode is covered by the other files.

Future<void> settle(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

/// Types into the field next to [label] on a role form.
Future<void> type(WidgetTester t, String label, String text) async {
  final field = find.descendant(of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first, matching: find.byType(TextFormField));
  await t.ensureVisible(field.first);
  await t.enterText(field.first, text);
}

/// Opens the welcome page on a phone and the sign-up (or log-in) form of the role card at [index]
/// (0 patient, 1 doctor, 2 nurse).
Future<RecordedService> openForm(WidgetTester t, int index, {required bool signUp, RecordedService? svc}) async {
  t.view.physicalSize = const Size(1179, 2556);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final s = await openApp(t, svc: svc, withAccounts: true);
  await settle(t, 3);
  // The welcome page is a lazy list: scroll until the nurse card (the third) is built.
  await t.scrollUntilVisible(find.text('Nurse').first, 200, scrollable: find.byType(Scrollable).first);
  await settle(t, 2);
  final button = find.text(signUp ? 'Sign up' : 'Log in').at(index);
  await t.ensureVisible(button);
  await settle(t, 2);
  await t.tap(button);
  await settle(t);
  return s;
}

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    appLang.value = 'en';
  });
  tearDown(() => appLang.value = 'en');

  test('accounts: sign up, wrong role, wrong password, log in again', () async {
    final svc = RecordedService();
    final s = svc.session(withAccounts: true);
    addTearDown(s.dispose);
    await s.restore();
    expect(await s.signUp(role: Role.nurse, name: 'Priya Das', email: 'Priya@Ward.in', password: 'secret123', details: {'ward': 'ICU'}), isNull);
    expect(s.role, Role.nurse);
    expect(s.mode, AuthMode.cloud);
    expect(s.details['ward'], 'ICU');
    final sp = await SharedPreferences.getInstance();
    expect([for (final k in sp.getKeys()) '${sp.get(k)}'].any((v) => v.contains('secret123')), isFalse, reason: 'the password is not kept on the device');
    expect(svc.to('POST /signup').single.map['password'], 'secret123', reason: 'it goes to the service');

    await s.signOut();
    expect(await s.signIn('priya@ward.in', 'wrong', as: Role.nurse), 'That email and password don\'t match an account.');
    expect(await s.signIn('priya@ward.in', 'secret123', as: Role.doctor), contains('nurse account'));
    expect(s.signedIn, isFalse);
    expect(await s.signIn('priya@ward.in', 'secret123', as: Role.nurse), isNull);
    expect(await s.signUp(role: Role.patient, name: 'X', email: 'priya@ward.in', password: 'whatever1'), contains('already exists'));

    // Restores after a restart: a new Session on the same stored sign-in.
    final again = svc.session(withAccounts: true);
    addTearDown(again.dispose);
    await again.restore();
    expect(again.signedIn, isTrue);
    expect(again.name, 'Priya Das');
  });

  testWidgets('doctor signs up through the form and lands on the ward', (t) async {
    final svc = await openForm(t, 1, signUp: true); // the second role card is Doctor
    expect(find.text('Create your Doctor account'), findsOneWidget);
    await type(t, 'Full name', 'Meenal Shah');
    await type(t, 'Medical reg. no.', 'DMC/R/9981');
    await type(t, 'Hospital', 'AIIMS');
    await type(t, 'Email', 'meenal@aiims.in');
    await type(t, 'Password', 'Heart2026!');
    await type(t, 'Confirm', 'Heart2026!');
    final submit = find.widgetWithText(CupertinoButton, 'Create Doctor account');
    await t.ensureVisible(submit);
    await t.tap(submit);
    await settle(t, 12);
    expect(find.text('Today'), findsWidgets);
    expect(find.textContaining('Dr. Meenal Shah'), findsWidgets);
    expect(svc.to('POST /signup').single.map, {
      'role': 'doctor',
      'name': 'Meenal Shah',
      'email': 'meenal@aiims.in',
      'password': 'Heart2026!',
      'details': {'registration': 'DMC/R/9981', 'specialty': 'Cardiologist', 'hospital': 'AIIMS'},
      'consent': false,
    });
    expect(svc.to('GET /me').single.headers['Authorization'], 'Bearer ${RecordedService.jwt}');

    // The ward is the one the service streams to staff accounts (GET /v1/live).
    await t.tap(find.text('Ward').last);
    await settle(t);
    expect(svc.to('GET /v1/live'), isNotEmpty);
    expect(find.text('Sunita Deshmukh'), findsOneWidget);
  });

  testWidgets('the log-in form says why it refused: wrong password, then wrong role', (t) async {
    final svc = RecordedService()..addAccount('nurse', 'Priya Das', 'priya@ward.in', 'secret123');
    await openForm(t, 1, signUp: false, svc: svc); // Doctor
    expect(find.text('Welcome back'), findsOneWidget);
    final login = find.widgetWithText(CupertinoButton, 'Log in as Doctor');
    await type(t, 'Email', 'priya@ward.in');
    await type(t, 'Password', 'wrong-password');
    await t.ensureVisible(login);
    await t.tap(login);
    await settle(t);
    expect(find.text('That email and password don\'t match an account.'), findsOneWidget);

    await type(t, 'Password', 'secret123');
    await t.ensureVisible(login);
    await t.tap(login);
    await settle(t);
    expect(find.text('This is a nurse account. Go back and choose Nurse.'), findsOneWidget);
    expect(find.text('That email and password don\'t match an account.'), findsNothing, reason: 'the old message is replaced');
    expect(find.textContaining('Dr. '), findsNothing, reason: 'still on the form, not signed in');
  });
}
