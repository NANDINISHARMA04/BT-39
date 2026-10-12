import 'package:bt39_care/app.dart';
import 'package:bt39_care/services/session.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  test('device accounts: sign up, wrong role, wrong password, log in again', () async {
    final s = Session();
    await s.restore();
    expect(await s.localSignUp(role: Role.nurse, name: 'Priya Das', email: 'Priya@Ward.in', password: 'secret123', details: {'ward': 'ICU'}), isNull);
    expect(s.role, Role.nurse);
    expect(s.mode, AuthMode.local);
    expect(s.details['ward'], 'ICU');
    final stored = (await SharedPreferences.getInstance()).getString('bt39.accounts')!;
    expect(stored.contains('secret123'), isFalse, reason: 'only a hash is stored');

    await s.signOut();
    expect(await s.localSignIn('priya@ward.in', 'wrong', as: Role.nurse), isNotNull);
    expect(await s.localSignIn('priya@ward.in', 'secret123', as: Role.doctor), contains('nurse account'));
    expect(await s.localSignIn('priya@ward.in', 'secret123', as: Role.nurse), isNull);
    expect(await s.localSignUp(role: Role.patient, name: 'X', email: 'priya@ward.in', password: 'whatever1'), contains('already exists'));

    // Restores after a restart.
    final again = Session();
    await again.restore();
    expect(again.signedIn, isTrue);
    expect(again.name, 'Priya Das');
  });

  testWidgets('doctor signs up through the form and lands on the ward', (t) async {
    t.view.physicalSize = const Size(1179, 2556);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const BT39App());
    await settle(t, 3);
    // The welcome page is a lazy list: scroll until the nurse card (the third) is built.
    await t.scrollUntilVisible(find.text('Nurse').first, 200, scrollable: find.byType(Scrollable).first);
    await settle(t, 2);
    await t.ensureVisible(find.text('Sign up').at(1));
    await settle(t, 2);
    await t.tap(find.text('Sign up').at(1)); // second role card is Doctor
    await settle(t);
    expect(find.text('Create your Doctor account'), findsOneWidget);
    Future<void> type(String label, String text) async {
      final field = find.descendant(of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first, matching: find.byType(TextFormField));
      await t.ensureVisible(field.first);
      await t.enterText(field.first, text);
    }

    await type('Full name', 'Meenal Shah');
    await type('Medical reg. no.', 'DMC/R/9981');
    await type('Hospital', 'AIIMS');
    await type('Email', 'meenal@aiims.in');
    await type('Password', 'Heart2026!');
    await type('Confirm', 'Heart2026!');
    final submit = find.widgetWithText(CupertinoButton, 'Create Doctor account');
    await t.ensureVisible(submit);
    await t.tap(submit);
    await settle(t, 12);
    expect(find.text('Today'), findsWidgets);
    expect(find.textContaining('Dr. Meenal Shah'), findsWidgets);
  });
}
