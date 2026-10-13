import 'dart:async';

import 'package:bt39_care/l10n/l10n.dart';
import 'package:bt39_care/services/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'helpers.dart';

const jwt = 'header.payload.signature';

/// Supabase's reply to a good sign-in.
Map<String, dynamic> authReply({String id = 'u-1', String email = 'a@b.in', String token = jwt}) => {
      'access_token': token,
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'refresh',
      'user': {'id': id, 'aud': 'authenticated', 'email': email, 'created_at': '2026-10-01T00:00:00Z', 'app_metadata': <String, dynamic>{}, 'user_metadata': <String, dynamic>{}},
    };

Map<String, dynamic> meReply({String role = 'patient', String name = 'Meera Nair', String email = 'a@b.in', Map<String, dynamic>? details, String? ward}) =>
    {'role': role, 'name': name, 'email': email, 'details': details ?? {'age': '31', 'sex': 'F'}, 'ward_id': ward, 'demo': false};

/// One fake backend for both Supabase Auth and the PulseOS service.
class Backend {
  Backend() {
    svc.on('POST /auth/v1/token', authReply());
    svc.routes['POST /auth/v1/logout'] = (_) => http.Response('', 204);
    svc.on('GET /me', meReply());
    svc.on('POST /signup', {'ok': true});
    svc.on('POST /demo/start', {'token': 'pd1.abc.def', 'role': 'patient', 'name': 'Jai', 'email': 'patient@pulseos.app', 'expires_in': 1800});
    svc.on('POST /demo/end', {'ok': true});
  }
  final svc = FakeService();

  /// Supabase on the same fake. The implicit flow needs no stored code verifier.
  late final SupabaseClient supabase = () {
    final c = SupabaseClient('https://proj.supabase.co', 'sb_publishable_test', httpClient: svc.client(), authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit));
    addTearDown(c.dispose);
    return c;
  }();

  /// A new Session on the same stored login, as if the app were opened again.
  Session session() => Session(supabase: supabase, httpClient: svc.client);
}

void main() {
  setUp(() {
    appLang.value = 'en';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => appLang.value = 'en');

  group('Demo Mode', () {
    test('starts on the service, with no token sent, and then speaks with the demo token', () async {
      final b = Backend();
      final s = b.session();
      addTearDown(s.dispose);
      var notified = 0;
      s.addListener(() => notified++);

      expect(s.signedIn, isFalse);
      expect(await s.startDemo(Role.patient, tour: true), isNull);

      final req = b.svc.to('POST /demo/start').single;
      expect(req.map, {'role': 'patient'});
      expect(req.headers.containsKey('Authorization'), isFalse);
      expect(s.signedIn, isTrue);
      expect(s.role, Role.patient);
      expect(s.mode, AuthMode.demo);
      expect(s.demo, isTrue);
      expect(s.name, 'Jai');
      expect(s.email, 'patient@pulseos.app');
      expect(s.accountId, 'demo-patient');
      expect(s.pendingTour, isTrue);
      expect(s.isStaff, isFalse);
      expect(s.starting, isNull);
      expect(await s.accessToken(), 'pd1.abc.def');
      expect(notified, greaterThanOrEqualTo(2));

      b.svc.on('GET /me/data', {});
      await s.api.get('/me/data');
      expect(b.svc.to('GET /me/data').single.headers['Authorization'], 'Bearer pd1.abc.def');
    });

    test('shows which role is starting while the service answers, and ignores a second tap', () async {
      final b = Backend();
      final gate = Completer<void>();
      b.svc.routes['POST /demo/start'] = (_) async {
        await gate.future;
        return jsonReply({'token': 'pd1.x.y', 'role': 'doctor', 'name': 'Dr. Kavya Rao', 'email': 'doctor@pulseos.app', 'expires_in': 1800});
      };
      final s = b.session();
      addTearDown(s.dispose);
      final f = s.startDemo(Role.doctor);
      expect(s.starting, Role.doctor);
      expect(await s.startDemo(Role.nurse), isNull, reason: 'ignored');
      gate.complete();
      expect(await f, isNull);
      expect(s.starting, isNull);
      expect(b.svc.to('POST /demo/start').length, 1);
      expect(s.role, Role.doctor);
      expect(s.isStaff, isTrue);
      expect(s.accountId, 'demo-doctor');
    });

    test('a service that does not answer gives a sentence and leaves the person signed out', () async {
      final b = Backend();
      b.svc.routes['POST /demo/start'] = (_) => errorReply(503, 'unavailable', 'The service is starting. Try again in a minute.');
      final s = b.session();
      addTearDown(s.dispose);
      expect(await s.startDemo(Role.nurse), 'The service is starting. Try again in a minute.');
      expect(s.signedIn, isFalse);
      expect(s.starting, isNull);
      expect(await s.accessToken(), isNull);
    });

    test('a token-less reply is an error too', () async {
      final b = Backend();
      b.svc.on('POST /demo/start', {'ok': true});
      final s = b.session();
      addTearDown(s.dispose);
      expect(await s.startDemo(Role.patient), 'The service is not answering. It may be waking up. Try again in a minute.');
      expect(s.signedIn, isFalse);
    });

    test('signing out ends the demo on the service and forgets the token', () async {
      final b = Backend();
      final s = b.session();
      addTearDown(s.dispose);
      await s.startDemo(Role.patient);
      await s.signOut();
      await until(() => b.svc.to('POST /demo/end').isNotEmpty);
      expect(b.svc.to('POST /demo/end').single.headers['Authorization'], 'Bearer pd1.abc.def');
      expect(s.signedIn, isFalse);
      expect(s.role, isNull);
      expect(await s.accessToken(), isNull);
    });

    test('leaving the demo to log in remembers where to go', () async {
      final b = Backend();
      final s = b.session();
      addTearDown(s.dispose);
      await s.startDemo(Role.patient);
      await s.leaveDemoToLogIn(Role.doctor, signUp: true);
      expect(s.pendingAuth, (role: Role.doctor, signUp: true));
      expect(s.signedIn, isFalse);
    });

    test('a demo that the service ended sends the person back with a note', () async {
      final b = Backend();
      b.svc.routes['GET /me/data'] = (_) => errorReply(401, 'demo_expired', 'This demo has ended.');
      final s = b.session();
      addTearDown(s.dispose);
      await s.startDemo(Role.patient);
      expect(s.expiredMessage, isNull);

      // Two calls fail at the same time (a stream and a page).
      await Future.wait([s.api.get('/me/data'), s.api.get('/me/data')]);
      await settle();
      expect(s.signedIn, isFalse);
      expect(s.expiredMessage, 'Your demo session ended. Start it again to keep exploring.');
      expect(b.svc.to('POST /demo/end'), isEmpty, reason: 'nothing left to end');
      expect(await s.accessToken(), isNull);

      // Starting again clears the note.
      expect(await s.startDemo(Role.patient), isNull);
      expect(s.expiredMessage, isNull);
    });
  });

  group('accounts', () {
    test('sign-in asks the service who the account is', () async {
      final b = Backend();
      b.svc.on('GET /me', meReply(role: 'nurse', name: 'Priya Das', email: 'priya@ward.in', details: {'ward': 'ICU', 'shift': 'Night'}, ward: 'ward-1'));
      final s = b.session();
      addTearDown(s.dispose);
      expect(await s.signIn('  priya@ward.in ', 'secret123', as: Role.nurse), isNull);

      final auth = b.svc.to('POST /auth/v1/token').single;
      expect(auth.map['email'], 'priya@ward.in');
      expect(auth.map['password'], 'secret123');
      expect(b.svc.to('GET /me').single.headers['Authorization'], 'Bearer $jwt');
      expect(s.mode, AuthMode.cloud);
      expect(s.demo, isFalse);
      expect(s.role, Role.nurse);
      expect(s.isStaff, isTrue);
      expect(s.name, 'Priya Das');
      expect(s.email, 'priya@ward.in');
      expect(s.wardId, 'ward-1');
      expect(s.details, {'ward': 'ICU', 'shift': 'Night'});
      expect(s.accountId, 'u-1');
      expect(await s.accessToken(), jwt);
    });

    test('an account of another role is refused with the old sentence, and signed out', () async {
      final b = Backend();
      b.svc.on('GET /me', meReply(role: 'nurse'));
      final s = b.session();
      addTearDown(s.dispose);
      final err = await s.signIn('a@b.in', 'secret123', as: Role.doctor);
      expect(err, 'This is a nurse account. Go back and choose Nurse.');
      expect(s.signedIn, isFalse);
      expect(s.role, isNull);
      expect(b.supabase.auth.currentSession, isNull);
      expect(b.svc.to('POST /auth/v1/logout').length, 1);
    });

    test('the refusal follows the language', () async {
      final b = Backend();
      b.svc.on('GET /me', meReply(role: 'doctor'));
      final s = b.session();
      addTearDown(s.dispose);
      appLang.value = 'hi';
      expect(await s.signIn('a@b.in', 'x1234567', as: Role.patient), 'यह ${tr('Doctor').toLowerCase()} अकाउंट है। वापस जाकर ${tr('Doctor')} चुनें।');
    });

    test('with no role chosen any account may sign in', () async {
      final b = Backend();
      final s = b.session();
      addTearDown(s.dispose);
      expect(await s.signIn('a@b.in', 'secret123'), isNull);
      expect(s.role, Role.patient);
      expect(s.details['age'], '31');
    });

    test('a wrong password is the plain sentence', () async {
      final b = Backend();
      b.svc.routes['POST /auth/v1/token'] = (_) => jsonReply({'code': 400, 'error_code': 'invalid_credentials', 'msg': 'Invalid login credentials'}, 400);
      final s = b.session();
      addTearDown(s.dispose);
      expect(await s.signIn('a@b.in', 'wrong', as: Role.patient), 'That email and password don\'t match an account.');
      expect(s.signedIn, isFalse);
      expect(b.svc.to('GET /me'), isEmpty);
    });

    test('other sign-in errors show the sign-in service\'s words', () async {
      final b = Backend();
      b.svc.routes['POST /auth/v1/token'] = (_) => jsonReply({'code': 429, 'error_code': 'over_request_rate_limit', 'msg': 'Too many attempts.'}, 429);
      final s = b.session();
      addTearDown(s.dispose);
      expect(await s.signIn('a@b.in', 'x', as: Role.patient), 'Too many attempts.');
    });

    test('a sign-in service that is down gives the connection sentence', () async {
      final b = Backend();
      b.svc.routes['POST /auth/v1/token'] = (_) => errorReply(502, 'bad_gateway', 'Bad gateway');
      final s = b.session();
      addTearDown(s.dispose);
      expect(await s.signIn('a@b.in', 'x', as: Role.patient), 'Could not reach the sign-in service. Check your connection and try again.');
    });

    test('if the PulseOS service cannot say who it is, the person is not left half signed in', () async {
      final b = Backend();
      b.svc.routes['GET /me'] = (_) => errorReply(503, 'unavailable', 'Waking up.');
      final s = b.session();
      addTearDown(s.dispose);
      expect(await s.signIn('a@b.in', 'secret123', as: Role.patient), 'Waking up.');
      expect(s.signedIn, isFalse);
      expect(b.supabase.auth.currentSession, isNull);
    });

    test('sign-up creates the account on the service, then signs in as that role', () async {
      final b = Backend();
      b.svc.on('GET /me', meReply(role: 'doctor', name: 'Dr. Ravi Menon', email: 'ravi@clinic.in', details: {'registration': 'DMC-1', 'specialty': 'Cardiologist'}));
      final s = b.session();
      addTearDown(s.dispose);
      final err = await s.signUp(role: Role.doctor, name: '  Ravi Menon ', email: ' ravi@clinic.in ', password: 'secret123', details: {'registration': 'DMC-1', 'specialty': 'Cardiologist'});
      expect(err, isNull);

      final sent = b.svc.to('POST /signup').single;
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(sent.map, {
        'role': 'doctor',
        'name': 'Ravi Menon',
        'email': 'ravi@clinic.in',
        'password': 'secret123',
        'details': {'registration': 'DMC-1', 'specialty': 'Cardiologist'},
        'consent': false,
      });
      expect(b.svc.to('POST /auth/v1/token').single.map['email'], 'ravi@clinic.in');
      expect(s.role, Role.doctor);
      expect(s.name, 'Dr. Ravi Menon');
      expect(s.details['registration'], 'DMC-1');
    });

    test('a patient\'s consent is passed on', () async {
      final b = Backend();
      final s = b.session();
      addTearDown(s.dispose);
      await s.signUp(role: Role.patient, name: 'Meera', email: 'a@b.in', password: 'secret123', consent: true);
      expect(b.svc.to('POST /signup').single.map['consent'], isTrue);
    });

    test('an email that is taken comes back as the service\'s sentence and nothing else happens', () async {
      final b = Backend();
      b.svc.routes['POST /signup'] = (_) => errorReply(409, 'email_taken', 'An account with this email already exists. Log in instead.');
      final s = b.session();
      addTearDown(s.dispose);
      final err = await s.signUp(role: Role.patient, name: 'X', email: 'a@b.in', password: 'secret123', consent: true);
      expect(err, 'An account with this email already exists. Log in instead.');
      expect(b.svc.to('POST /auth/v1/token'), isEmpty);
      expect(s.signedIn, isFalse);
    });

    test('sign-up as one role into an account that turns out to be another is refused', () async {
      final b = Backend();
      b.svc.on('GET /me', meReply(role: 'patient'));
      final s = b.session();
      addTearDown(s.dispose);
      final err = await s.signUp(role: Role.nurse, name: 'X', email: 'a@b.in', password: 'secret123');
      expect(err, 'This is a patient account. Go back and choose Patient.');
      expect(s.signedIn, isFalse);
    });

    test('signing out of an account signs out of Supabase', () async {
      final b = Backend();
      final s = b.session();
      addTearDown(s.dispose);
      await s.signIn('a@b.in', 'secret123');
      expect(b.supabase.auth.currentSession, isNotNull);
      await s.signOut();
      expect(s.signedIn, isFalse);
      expect(b.supabase.auth.currentSession, isNull);
      expect(await s.accessToken(), isNull);
      expect(b.svc.to('POST /demo/end'), isEmpty, reason: 'it was not a demo');
    });

    test('a password reset goes to Supabase', () async {
      final b = Backend();
      b.svc.on('POST /auth/v1/recover', {});
      final s = b.session();
      addTearDown(s.dispose);
      expect(await s.resetPassword(' a@b.in '), isNull);
      expect(b.svc.to('POST /auth/v1/recover').single.map['email'], 'a@b.in');
    });
  });

  group('opening the app', () {
    test('forgets the accounts that used to be kept on the device', () async {
      SharedPreferences.setMockInitialValues({'bt39.accounts': '{}', 'bt39.localUser': 'x@y.in', 'bt39.demoRole': 'doctor', 'bt39.lang': 'hi', 'other': 'kept'});
      final b = Backend();
      final s = b.session();
      addTearDown(s.dispose);
      expect(s.restoring, isTrue);
      await s.restore();
      final sp = await SharedPreferences.getInstance();
      expect(sp.containsKey('bt39.accounts'), isFalse);
      expect(sp.containsKey('bt39.localUser'), isFalse);
      expect(sp.containsKey('bt39.demoRole'), isFalse);
      expect(sp.getString('bt39.lang'), 'hi', reason: 'the language is not an account');
      expect(sp.getString('other'), 'kept');
      expect(s.restoring, isFalse);
      expect(s.signedIn, isFalse);
    });

    test('a saved account comes back, and a demo does not', () async {
      final b = Backend();
      b.svc.on('GET /me', meReply(role: 'doctor', name: 'Dr. Ravi Menon', ward: 'w1'));
      final first = b.session();
      addTearDown(first.dispose);
      await first.signIn('a@b.in', 'secret123');

      // The app is opened again: a new Session on the same stored Supabase login.
      final again = b.session();
      addTearDown(again.dispose);
      await again.restore();
      expect(again.restoring, isFalse);
      expect(again.signedIn, isTrue);
      expect(again.role, Role.doctor);
      expect(again.name, 'Dr. Ravi Menon');
      expect(again.wardId, 'w1');
      expect(again.mode, AuthMode.cloud);

      final demo = b.session();
      addTearDown(demo.dispose);
      await demo.startDemo(Role.patient);
      final reopened = b.session();
      addTearDown(reopened.dispose);
      await reopened.restore();
      expect(reopened.role, Role.doctor, reason: 'the account, never the demo');
    });

    test('a service that is asleep does not log the person out', () async {
      final b = Backend();
      final first = b.session();
      addTearDown(first.dispose);
      await first.signIn('a@b.in', 'secret123');

      b.svc.routes['GET /me'] = (_) => errorReply(503, 'unavailable', 'Waking up.');
      final again = b.session();
      addTearDown(again.dispose);
      await again.restore();
      expect(again.signedIn, isFalse);
      expect(again.restoring, isFalse);
      expect(b.supabase.auth.currentSession, isNotNull, reason: 'the login is kept for the next try');
    });

    test('a refused token ends the saved login', () async {
      final b = Backend();
      final first = b.session();
      addTearDown(first.dispose);
      await first.signIn('a@b.in', 'secret123');

      b.svc.routes['GET /me'] = (_) => errorReply(401, 'unauthorized', 'Please sign in.');
      final again = b.session();
      addTearDown(again.dispose);
      await again.restore();
      expect(again.signedIn, isFalse);
      expect(b.supabase.auth.currentSession, isNull);
    });
  });

  test('the demo accounts are the same public ones', () {
    expect(demoAccounts[Role.patient], ('patient@pulseos.app', 'patient123', 'Jai'));
    expect(demoAccounts[Role.doctor], ('doctor@pulseos.app', 'doctor123', 'Dr. Kavya Rao'));
    expect(demoAccounts[Role.nurse], ('nurse@pulseos.app', 'nurse123', 'Nurse Anjali Singh'));
    expect(roleLabel[Role.nurse], 'Nurse');
  });
}
