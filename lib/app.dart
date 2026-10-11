import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth/welcome_screen.dart';
import 'screens/patient/patient_shell.dart';
import 'screens/staff/staff_shell.dart';
import 'services/monitor.dart';
import 'services/patient_store.dart';
import 'services/session.dart';
import 'services/staff_controller.dart';
import 'theme/ios_theme.dart';

class BT39App extends StatelessWidget {
  const BT39App({super.key, this.session});
  final Session? session;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => (session ?? Session())..restore()),
        ChangeNotifierProvider(create: (_) => PatientStore()),
      ],
      child: Consumer2<Session, PatientStore>(
        builder: (context, s, store, _) {
          final pref = s.role == Role.patient && store.loaded ? store.prefs.theme : 'system';
          return MaterialApp(
            title: 'AdaptAlert',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(IOS.light),
            darkTheme: buildTheme(IOS.darkTheme),
            themeMode: switch (pref) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system },
            home: const RootGate(),
          );
        },
      ),
    );
  }
}

/// Sends each person to the right app: welcome, patient or staff.
class RootGate extends StatelessWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final Widget child;
    if (s.restoring) {
      child = const _Splash(key: ValueKey('splash'));
    } else if (!s.signedIn) {
      child = const WelcomeScreen(key: ValueKey('welcome'));
    } else if (s.role == Role.patient) {
      child = _PatientRoot(key: ValueKey('patient-${s.accountId}'));
    } else {
      child = ChangeNotifierProvider(
        key: ValueKey('staff-${s.accountId}'),
        create: (_) => StaffController(demo: s.demo, token: s.accessToken, wardId: s.wardId, myName: s.name)..start(),
        child: const StaffShell(),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (ch, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .98, end: 1.0).animate(a), child: ch)),
      child: child,
    );
  }
}

class _PatientRoot extends StatefulWidget {
  const _PatientRoot({super.key});
  @override
  State<_PatientRoot> createState() => _PatientRootState();
}

class _PatientRootState extends State<_PatientRoot> {
  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    context.read<PatientStore>().load(s.accountId, name: s.name, email: s.email);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PatientStore>();
    if (!store.loaded) return const _Splash();
    // Pages pushed from the patient app need the monitor too, so they get a
    // navigator that lives under its provider.
    return ChangeNotifierProvider(
      create: (_) => MonitorController()..start(),
      child: HeroControllerScope(
        controller: MaterialApp.createMaterialHeroController(),
        child: Navigator(onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const PatientShell())),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.ios.bg,
        body: const Center(child: CupertinoActivityIndicator(radius: 14)),
      );
}
