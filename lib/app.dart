import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth/welcome_screen.dart';
import 'screens/patient/patient_shell.dart';
import 'screens/patient/sos_screen.dart';
import 'screens/staff/staff_shell.dart';
import 'services/clinical_store.dart';
import 'services/monitor.dart';
import 'services/patient_store.dart';
import 'services/session.dart';
import 'services/staff_controller.dart';
import 'services/tour.dart';
import 'theme/ios_theme.dart';
import 'widgets/shell_navigator.dart';

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
            title: 'PulseOS',
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
      child = MultiProvider(
        key: ValueKey('staff-${s.accountId}'),
        providers: [
          ChangeNotifierProvider(create: (_) => StaffController(demo: s.onDevice, token: s.accessToken, wardId: s.wardId, myName: s.name)..start()),
          // A patient at home on AdaptAlert, whose alerts staff review.
          ChangeNotifierProvider(create: (_) => MonitorController()..start()),
          ChangeNotifierProvider(create: (_) => ClinicalStore(s)..load()),
        ],
        child: const StaffRoot(),
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
  final _nav = GlobalKey<NavigatorState>();
  late final MonitorController _monitor = MonitorController()..start();
  late final TourController _tour = TourController(_monitor, _select);

  @override
  void dispose() {
    _tour.dispose();
    _monitor.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    patientTab.value = PatientTab.today;
    final s = context.read<Session>();
    context.read<PatientStore>().load(s.accountId, name: s.name, email: s.email, details: s.details);
  }

  /// Sidebar tap: close any open page, then show the tab.
  void _select(int tab) {
    _nav.currentState?.popUntil((r) => r.isFirst);
    patientTab.value = tab;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PatientStore>();
    if (!store.loaded) return const _Splash();
    // Pages pushed from the patient app need the monitor too, so they get a
    // navigator that lives under its provider.
    final navigator = ShellNavigator(navKey: _nav, tab: patientTab, homeTab: PatientTab.today, home: const PatientShell(), labelOf: (t) => const ['Today', 'Alerts', 'Insights', 'Care', 'Me'][t]);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _monitor),
        ChangeNotifierProvider.value(value: _tour),
      ],
      child: Builder(builder: (context) {
        if (!isWide(context)) return navigator;
        // Laptop layout: sidebar on the left, content in a readable column.
        return ColoredBox(
          color: context.ios.bg,
          child: Row(children: [
            PatientSidebar(
              onSelect: _select,
              onSos: () => _nav.currentState?.push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const SosScreen())),
              onSimulate: () => showSimulator(_nav.currentContext!),
            ),
            Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: navigator))),
          ]),
        );
      }),
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
