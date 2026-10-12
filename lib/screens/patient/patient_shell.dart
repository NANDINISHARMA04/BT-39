import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../engine/adapt_alert.dart';
import '../../engine/simulator.dart';
import '../../l10n/l10n.dart';
import '../../services/accessibility.dart';
import '../../services/monitor.dart';
import '../../services/patient_store.dart';
import '../../services/session.dart';
import '../../services/speech.dart';
import '../../services/tour.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import '../auth/login_now_screen.dart';
import 'alerts_screen.dart';
import 'assistant_screen.dart';
import 'care_screen.dart';
import 'easy_home_screen.dart';
import 'insights_screen.dart';
import 'me_screen.dart';
import 'sos_screen.dart';
import 'today_screen.dart';

/// Lets any screen switch tabs (e.g. Reply to alerts on Today).
class TabSwitcher extends InheritedWidget {
  const TabSwitcher({super.key, required this.go, required super.child});
  final void Function(int index) go;
  static void of(BuildContext context, int index) => context.dependOnInheritedWidgetOfExactType<TabSwitcher>()?.go(index);
  @override
  bool updateShouldNotify(TabSwitcher old) => false;
}

class PatientTab {
  static const today = 0, alerts = 1, insights = 2, care = 3, me = 4;
}

/// The selected patient tab. Shared by the bottom tab bar (phones) and the
/// sidebar (laptops), so both always agree.
final patientTab = ValueNotifier<int>(0);

/// Laptop and tablet-landscape widths get a sidebar instead of a tab bar.
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

const _tabItems = [
  (CupertinoIcons.heart, CupertinoIcons.heart_fill, 'Today'),
  (CupertinoIcons.bell, CupertinoIcons.bell_fill, 'Alerts'),
  (CupertinoIcons.chart_bar_alt_fill, CupertinoIcons.chart_bar_alt_fill, 'Insights'),
  (CupertinoIcons.calendar, CupertinoIcons.calendar_today, 'Care'),
  (CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill, 'Me'),
];

/// Left-hand navigation for wide screens.
class PatientSidebar extends StatelessWidget {
  const PatientSidebar({super.key, required this.onSelect, required this.onSos, required this.onSimulate});
  final void Function(int tab) onSelect;
  final VoidCallback onSos, onSimulate;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final m = context.watch<MonitorController>();
    final store = context.watch<PatientStore>();
    return Material(
      color: c.card,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: c.card,
          border: Border(right: BorderSide(color: c.sep, width: .5)),
        ),
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
            child: ValueListenableBuilder<int>(
              valueListenable: patientTab,
              builder: (context, tab, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(colors: [c.pink, c.red]),
                        ),
                        child: const Icon(CupertinoIcons.waveform_path_ecg, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PulseOS', style: T.headline.copyWith(color: c.label)),
                            Text(
                              store.profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.caption.copyWith(color: c.label2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  for (var i = 0; i < _tabItems.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: i == tab ? c.blue.withValues(alpha: .12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelect(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(i == tab ? _tabItems[i].$2 : _tabItems[i].$1, size: 21, color: i == tab ? c.blue : c.label2),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tr(_tabItems[i].$3),
                                    style: T.callout.copyWith(color: i == tab ? c.blue : c.label, fontWeight: i == tab ? FontWeight.w600 : FontWeight.w400),
                                  ),
                                ),
                                if (i == PatientTab.alerts && m.needsReply > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                    decoration: BoxDecoration(color: c.red, borderRadius: BorderRadius.circular(9)),
                                    child: Text(
                                      '${m.needsReply}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  CupertinoButton.tinted(sizeStyle: CupertinoButtonSize.medium, onPressed: onSimulate, child: Text(tr('Simulate a scenario'))),
                  const SizedBox(height: 8),
                  Semantics(
                    label: tr('Emergency SOS'),
                    button: true,
                    excludeSemantics: true,
                    child: CupertinoButton.filled(
                      sizeStyle: CupertinoButtonSize.medium,
                      color: c.red,
                      onPressed: onSos,
                      child: const Text('SOS', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr('Research prototype. Not a medical device.'),
                    textAlign: TextAlign.center,
                    style: T.caption.copyWith(color: c.label3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});
  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int get _tab => patientTab.value;
  HealthAlert? _banner;
  Timer? _bannerTimer;

  /// The red/orange screen border shown for a new alert (flash alerts).
  Color? _flash;
  Timer? _flashTimer;
  late final MonitorController _m = context.read<MonitorController>();

  @override
  void initState() {
    super.initState();
    patientTab.addListener(_onTab);
    _tour = context.read<TourController>()..addListener(_onTour);
    // Start the guided demo if the person asked for it on the welcome screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<Session>();
      if (s.pendingTour) {
        s.pendingTour = false;
        Future.delayed(const Duration(milliseconds: 800), () => mounted ? context.read<TourController>().start() : null);
      }
    });
    _m.alertEvents.addListener(_onAlert);
    _m.heldEvents.addListener(_onHeld);
    _m.badSignal.addListener(_onBad);
    _m.scenarioEnded.addListener(_onScenarioEnded);
  }

  @override
  void dispose() {
    patientTab.removeListener(_onTab);
    _tour.removeListener(_onTour);
    _m.alertEvents.removeListener(_onAlert);
    _m.heldEvents.removeListener(_onHeld);
    _m.badSignal.removeListener(_onBad);
    _m.scenarioEnded.removeListener(_onScenarioEnded);
    _bannerTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _onTab() => setState(() {});

  late final TourController _tour;
  bool _loginShown = false;

  /// The demo is over: ask the person to log in straight away.
  void _onTour() {
    if (!_tour.ended || _loginShown || !mounted) return;
    _loginShown = true;
    _tour.finish();
    showLoginNow(context);
  }

  void _onAlert() {
    final a = _m.alertEvents.value;
    if (a == null || !mounted) return;
    HapticFeedback.heavyImpact();
    final a11y = context.read<AccessibilitySettings>();
    final touring = context.read<TourController>().running;
    setState(() => _banner = a);
    _bannerTimer?.cancel();
    if (a11y.flashAlerts) {
      // For deaf or hard-of-hearing people: flash the screen edge, vibrate,
      // and keep the banner until it is tapped.
      HapticFeedback.vibrate();
      setState(() => _flash = a.level >= 3 ? context.ios.red : context.ios.orange);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(seconds: 4), () => mounted ? setState(() => _flash = null) : null);
    } else {
      _bannerTimer = Timer(const Duration(seconds: 6), () => mounted ? setState(() => _banner = null) : null);
    }
    // For blind or low-vision people. Not during the guided demo, which has
    // its own voice.
    if (a11y.speakAlerts && !touring) {
      Speech.instance.speak(tr('Alert: {title}. {reason}', {'title': a.title, 'reason': a.reasons.isEmpty ? '' : a.reasons.first}));
    }
    final store = context.read<PatientStore>();
    if (a.level >= 4 && store.prefs.autoSos && !context.read<TourController>().running) {
      Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => SosScreen(trigger: a)));
    }
  }

  void _onHeld() {
    final h = _m.heldEvents.value;
    if (h == null || !mounted) return;
    toast(context, tr('Alert held back'), tr('Looks like a pattern you and your doctor marked harmless ({pct} likely real).', {'pct': pct(h.p)}));
  }

  void _onBad() {
    if (mounted) toast(context, tr('Please adjust your band'), tr('Readings were unreliable for 4 minutes, so no alerts were sent.'));
  }

  void _onScenarioEnded() {
    if (mounted && _m.scenarioEnded.value != null) toast(context, tr('Back to resting'), tr('The scenario finished.'));
  }

  void go(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    patientTab.value = i;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final m = context.watch<MonitorController>();
    final a11y = context.watch<AccessibilitySettings>();
    final tour = context.watch<TourController>();
    final pages = [a11y.easyHome ? const EasyHomeScreen() : const TodayScreen(), const AlertsScreen(), const InsightsScreen(), const CareScreen(), const MeScreen()];
    final items = [
      (CupertinoIcons.heart, CupertinoIcons.heart_fill, tr('Today'), 0),
      (CupertinoIcons.bell, CupertinoIcons.bell_fill, tr('Alerts'), m.needsReply),
      (CupertinoIcons.chart_bar_alt_fill, CupertinoIcons.chart_bar_alt_fill, tr('Insights'), 0),
      (CupertinoIcons.calendar, CupertinoIcons.calendar_today, tr('Care'), 0),
      (CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill, tr('Me'), 0),
    ];
    final bottom = MediaQuery.of(context).padding.bottom;
    return TabSwitcher(
      go: go,
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            for (var i = 0; i < pages.length; i++) _TabPage(active: i == _tab, child: pages[i]),
            if (!isWide(context))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Glass(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.sep, width: .5)),
                    ),
                    padding: EdgeInsets.only(top: 6, bottom: bottom > 0 ? bottom : 10),
                    child: Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: Semantics(
                              selected: i == _tab,
                              button: true,
                              label: items[i].$3,
                              child: Pressable(
                                scale: .86,
                                onTap: () => go(i),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 250),
                                          transitionBuilder: (ch, a) => ScaleTransition(scale: a, child: ch),
                                          child: Icon(i == _tab ? items[i].$2 : items[i].$1, key: ValueKey(i == _tab), size: 26, color: i == _tab ? c.blue : c.gray),
                                        ),
                                        if (items[i].$4 > 0)
                                          Positioned(
                                            right: -10,
                                            top: -4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              constraints: const BoxConstraints(minWidth: 18),
                                              decoration: BoxDecoration(color: c.red, borderRadius: BorderRadius.circular(9)),
                                              child: Text(
                                                '${items[i].$4}',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      items[i].$3,
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: i == _tab ? c.blue : c.gray),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!tour.running && tour.step == null) _HelpButton(above: isWide(context) ? 24 : (bottom > 0 ? bottom : 10) + 6 + 28 + MediaQuery.textScalerOf(context).scale(10.5) * 1.3 + 16),
            if (_flash != null) Positioned.fill(child: _FlashBorder(color: _flash!)),
            _AlertBanner(
              alert: _banner,
              big: a11y.flashAlerts,
              onTap: () {
                _bannerTimer?.cancel();
                setState(() {
                  _banner = null;
                  _flash = null;
                });
                go(PatientTab.alerts);
              },
            ),
            const TourOverlay(),
          ],
        ),
      ),
    );
  }
}

class _TabPage extends StatelessWidget {
  const _TabPage({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  // The fade must keep running when a tab is left, so only the page's own
  // animations are paused, not the fade itself. Otherwise a page that is
  // left half-faded stays drawn over the tab below it.
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !active,
    child: AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      child: AnimatedSlide(
        offset: active ? Offset.zero : const Offset(.03, 0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: TickerMode(enabled: active, child: ExcludeSemantics(excluding: !active, child: child)),
      ),
    ),
  );
}

/// A Dynamic-Island-style banner that drops in when an alert is sent.
class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.alert, required this.onTap, this.big = false});
  final HealthAlert? alert;
  final VoidCallback onTap;

  /// Larger, and stays until tapped (flash alerts).
  final bool big;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final a = alert;
    final top = MediaQuery.of(context).padding.top;
    final col = a == null ? c.red : levelColor(context, a.level);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutBack,
      left: 10,
      right: 10,
      top: a == null ? (big ? -400 : -140) : top + 6,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Semantics(
            liveRegion: true,
            button: true,
            child: Pressable(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.all(big ? 18 : 14),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 10))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a == null ? '' : '${a.levelLabel} · ${a.title}',
                          maxLines: big ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: big ? 19 : 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a == null || a.reasons.isEmpty ? '' : a.reasons.first,
                          maxLines: big ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: const Color(0xB3FFFFFF), fontSize: big ? 16 : 13),
                        ),
                        if (big) ...[
                          const SizedBox(height: 6),
                          Text(tr('Tap to see the alert'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(tr('now'), style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 12)),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}

/// The round Help button above the tab bar: opens the assistant.
class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.above});

  /// Distance from the bottom of the shell.
  final double above;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Positioned(
      right: 16,
      bottom: above,
      child: Semantics(
        button: true,
        label: tr('Help: ask the assistant'),
        excludeSemantics: true,
        child: Pressable(
          scale: .9,
          onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const AssistantScreen())),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [c.indigo, c.purple], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6))],
            ),
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(CupertinoIcons.question, color: Colors.white, size: 26),
                Text(tr('Help'), maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bright pulsing border around the screen for a new alert, for people
/// who can't hear the alert sound.
class _FlashBorder extends StatefulWidget {
  const _FlashBorder({required this.color});
  final Color color;
  @override
  State<_FlashBorder> createState() => _FlashBorderState();
}

class _FlashBorderState extends State<_FlashBorder> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // With reduced motion the border stays on instead of flashing.
    if (MediaQuery.of(context).disableAnimations) {
      _a.stop();
      _a.value = 1;
    } else if (!_a.isAnimating) {
      _a.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: FadeTransition(
          opacity: Tween(begin: .35, end: 1.0).animate(_a),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: widget.color, width: 14),
              gradient: RadialGradient(radius: 1.2, colors: [widget.color.withValues(alpha: 0), widget.color.withValues(alpha: .28)]),
            ),
          ),
        ),
      );
}

Color levelColor(BuildContext context, int level) {
  final c = context.ios;
  return switch (level) {
    1 => c.teal,
    2 => c.orange,
    _ => c.red,
  };
}

Color scenarioColor(BuildContext context, Scenario s) {
  final c = context.ios;
  return switch (s.color) {
    'green' => c.green,
    'blue' => c.blue,
    'gray' => c.gray,
    'orange' => c.orange,
    'red' => c.red,
    'purple' => c.purple,
    _ => c.pink,
  };
}

/// The sheet that drives the simulated band.
void showSimulator(BuildContext context) {
  final monitor = context.read<MonitorController>();
  showSheet(context, (ctx) {
    // The sheet can open on a navigator above the provider, so pass it along.
    return ChangeNotifierProvider.value(value: monitor, child: Consumer<MonitorController>(
      builder: (ctx, m, _) {
        final c = ctx.ios;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text(tr('Simulate'), style: T.title2.copyWith(color: c.label)),
            const SizedBox(height: 6),
            Text(tr('Pick what happens next. Each scenario runs for a few simulated minutes (one per second), then returns to resting.'), style: T.footnote.copyWith(color: c.label2)),
            const SizedBox(height: 14),
            GroupedList(
              children: [
                for (final s in scenarios)
                  IOSRow(
                    icon: s.icon,
                    iconColor: scenarioColor(ctx, s),
                    title: tr(s.name),
                    subtitle: m.scenarioId == s.id && s.id != 'rest' ? tr('Running · {n} min left', {'n': m.scenarioMinutesLeft}) : tr(s.desc),
                    trailing: m.scenarioId == s.id ? Pill(tr('Now'), color: c.blue) : null,
                    chevron: m.scenarioId != s.id,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      m.runScenario(s.id);
                      Navigator.pop(ctx);
                      toast(context, tr(s.name), tr(s.desc));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            GroupedList(
              children: [
                IOSRow(
                  icon: CupertinoIcons.pause_fill,
                  iconColor: c.gray,
                  title: tr('Pause the band'),
                  trailing: CupertinoSwitch(value: m.paused, onChanged: m.setPaused),
                  chevron: false,
                ),
                IOSRow(
                  icon: CupertinoIcons.forward_fill,
                  iconColor: c.orange,
                  title: tr('Fast forward'),
                  subtitle: tr('4 simulated minutes per second'),
                  trailing: CupertinoSwitch(value: m.fast, onChanged: m.setFast),
                  chevron: false,
                ),
              ],
            ),
          ],
        );
      },
    ));
  });
}

/// The caption card of the guided demo.
class TourOverlay extends StatelessWidget {
  const TourOverlay({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final tour = context.watch<TourController>();
    final s = tour.step;
    final bottom = isWide(context) ? 24.0 : MediaQuery.of(context).padding.bottom + 74;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      left: 12,
      right: 12,
      bottom: s == null ? -320 : bottom,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: const Color(0xF2111114),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30, offset: Offset(0, 10))],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (ch, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(a), child: ch)),
              child: s == null
                  ? const SizedBox(height: 120)
                  : Column(key: ValueKey(s.title), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: c.red, borderRadius: BorderRadius.circular(6)),
                          child: Text(tr('GUIDED DEMO'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .6)),
                        ),
                        const SizedBox(width: 8),
                        Text(tr('{i} of {n}', {'i': tour.index, 'n': TourController.totalSteps}), style: const TextStyle(color: Colors.white60, fontSize: 12, fontFeatures: T.num)),
                        const Spacer(),
                        Semantics(
                          label: tour.narrator.muted ? tr('Turn the voice guide on') : tr('Mute the voice guide'),
                          button: true,
                          excludeSemantics: true,
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(30, 30),
                            onPressed: tour.toggleMute,
                            child: Icon(tour.narrator.muted ? CupertinoIcons.speaker_slash_fill : CupertinoIcons.speaker_2_fill, color: Colors.white70, size: 20),
                          ),
                        ),
                        if (tour.running)
                          CupertinoButton(padding: EdgeInsets.zero, minimumSize: const Size(30, 30), onPressed: tour.stop, child: Text(tr('Skip'), style: const TextStyle(color: Colors.white70, fontSize: 14)))
                        else
                          CupertinoButton(padding: EdgeInsets.zero, minimumSize: const Size(30, 30), onPressed: tour.finish, child: Text(tr('Done'), style: TextStyle(color: c.blue, fontSize: 15, fontWeight: FontWeight.w700))),
                      ]),
                      const SizedBox(height: 6),
                      Text(tr(s.title), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.3)),
                      const SizedBox(height: 4),
                      Text(tr(s.body, s.args), style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 14, height: 1.4)),
                      if (s.last) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: CupertinoButton.filled(
                              sizeStyle: CupertinoButtonSize.medium,
                              onPressed: () {
                                tour.finish();
                                showLoginNow(context);
                              },
                              child: Text(tr('Log in or sign up'), maxLines: 1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CupertinoButton(
                              sizeStyle: CupertinoButtonSize.medium,
                              onPressed: tour.finish,
                              child: Text(tr('Keep exploring'), maxLines: 1, style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: tour.index / TourController.totalSteps),
                          duration: const Duration(milliseconds: 600),
                          builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: Colors.white12, color: c.green),
                        ),
                      ),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}
