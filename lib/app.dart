import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/l10n.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/patient/patient_shell.dart';
import 'screens/patient/sos_screen.dart';
import 'screens/staff/staff_shell.dart';
import 'services/accessibility.dart';
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
    return LangScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => (session ?? Session())..restore()),
          ChangeNotifierProvider(create: (_) => PatientStore()),
          // Text size, bold text, reduced motion, easy home and alert options.
          ChangeNotifierProvider(create: (_) => AccessibilitySettings()),
        ],
        child: Consumer2<Session, PatientStore>(
          builder: (context, s, store, _) {
            final pref = s.role == Role.patient && store.loaded ? store.prefs.theme : 'system';
            return MaterialApp(
              title: 'PulseOS',
              locale: Locale(appLang.value),
              supportedLocales: const [Locale('en'), Locale('hi')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              debugShowCheckedModeBanner: false,
              theme: buildTheme(IOS.light),
              darkTheme: buildTheme(IOS.darkTheme),
              themeMode: switch (pref) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system },
              // Accessibility options apply to every page, for patients and staff.
              builder: (context, child) => AccessibleMediaQuery(settings: context.read<AccessibilitySettings>(), child: child ?? const SizedBox()),
              home: const RootGate(),
            );
          },
        ),
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
          ChangeNotifierProvider(create: (_) => StaffController(demo: s.demo, token: s.accessToken, wardId: s.wardId, myName: s.name, api: s.api)..start()),
          // A patient at home on AdaptAlert, whose alerts staff review. The band runs on the service.
          ChangeNotifierProvider(create: (_) => MonitorController(api: s.api)..start()),
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
  late final MonitorController _monitor = MonitorController(api: context.read<Session>().api)..start();
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
    context.read<PatientStore>().load(s.api, s.accountId, name: s.name, email: s.email, details: s.details);
  }

  /// Sidebar tap: close any open page, then show the tab.
  void _select(int tab) {
    _nav.currentState?.popUntil((r) => r.isFirst);
    patientTab.value = tab;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PatientStore>();
    // Every screen reads the band, so wait for the service's first snapshot as well as the records.
    if (!store.loaded || !_monitor.ready) {
      return ListenableBuilder(
        listenable: _monitor,
        builder: (context, _) => !store.loaded || !_monitor.ready
            ? _Waking(error: store.error, onRetry: store.error == null ? null : store.reload)
            : _app(context),
      );
    }
    return _app(context);
  }

  Widget _app(BuildContext context) {
    // Pages pushed from the patient app need the monitor too, so they get a
    // navigator that lives under its provider.
    final navigator = ShellNavigator(navKey: _nav, tab: patientTab, homeTab: PatientTab.today, home: const PatientShell(), labelOf: (t) => tr(const ['Today', 'Alerts', 'Insights', 'Care', 'Me'][t]));
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

/// While the patient app waits for the service. On the free plan the service
/// sleeps when nobody uses it, so after a few seconds this says it is waking up;
/// if loading failed it shows why, with a button to try again.
class _Waking extends StatefulWidget {
  const _Waking({this.error, this.onRetry});
  final String? error;
  final VoidCallback? onRetry;
  @override
  State<_Waking> createState() => _WakingState();
}

class _WakingState extends State<_Waking> {
  bool _slow = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () => mounted ? setState(() => _slow = true) : null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final err = widget.error;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (err == null) const CupertinoActivityIndicator(radius: 14) else Icon(CupertinoIcons.wifi_exclamationmark, size: 40, color: c.orange),
            if (err != null || _slow) ...[
              const SizedBox(height: 16),
              Text(err ?? tr('Waking up the server. This can take up to a minute.'), textAlign: TextAlign.center, style: T.sub.copyWith(color: c.label2)),
            ],
            if (err != null && widget.onRetry != null) ...[
              const SizedBox(height: 12),
              CupertinoButton.tinted(sizeStyle: CupertinoButtonSize.medium, onPressed: widget.onRetry, child: Text(tr('Try again'))),
            ],
          ]),
        ),
      ),
    );
  }
}
