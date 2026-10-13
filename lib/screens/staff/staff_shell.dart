import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../engine/news2.dart';
import '../../engine/adapt_alert.dart';
import '../../l10n/l10n.dart';
import '../../services/bt39_client.dart';
import '../../services/monitor.dart';
import '../../services/session.dart';
import '../../services/staff_controller.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/vitals.dart';
import '../../widgets/demo_banner.dart';
import '../../widgets/lang_switch.dart';
import '../../widgets/shell_navigator.dart';
import '../patient/accessibility_screen.dart';
import '../patient/patient_shell.dart' show isWide, showSimulator;
import 'bed_screen.dart';
import 'home_patients_screen.dart';
import 'patients_screen.dart';
import 'schedule_screen.dart';
import 'staff_today_screen.dart';

Color bandColor(BuildContext context, String? band) {
  final c = context.ios;
  return switch (band) { 'high' => c.red, 'medium' => c.orange, 'low_medium' => c.yellow, 'low' => c.green, _ => c.gray };
}

Color severityColor(BuildContext context, String s) {
  final c = context.ios;
  return switch (s) { 'high' => c.red, 'medium' => c.orange, _ => c.yellow };
}

/// The doctor and nurse app's sections. Phones show five of them in a tab
/// bar and open the rest as pages; laptops list them all in a sidebar.
enum StaffSec { today, patients, schedule, ward, alerts, review, rules, me }

final staffSec = ValueNotifier<int>(0);
final staffNavKey = GlobalKey<NavigatorState>();

List<StaffSec> staffSections(Role? r) => r == Role.nurse
    ? const [StaffSec.today, StaffSec.ward, StaffSec.patients, StaffSec.alerts, StaffSec.review, StaffSec.rules, StaffSec.me]
    : const [StaffSec.today, StaffSec.patients, StaffSec.schedule, StaffSec.ward, StaffSec.alerts, StaffSec.review, StaffSec.rules, StaffSec.me];

List<StaffSec> _tabSections(Role? r) => r == Role.nurse
    ? const [StaffSec.today, StaffSec.ward, StaffSec.patients, StaffSec.alerts, StaffSec.review]
    : const [StaffSec.today, StaffSec.patients, StaffSec.schedule, StaffSec.ward, StaffSec.alerts];

(IconData, IconData, String) _secItem(StaffSec s, Role? r) => switch (s) {
      StaffSec.today => r == Role.nurse ? (CupertinoIcons.checkmark_square, CupertinoIcons.checkmark_square_fill, tr('Shift')) : (CupertinoIcons.sun_max, CupertinoIcons.sun_max_fill, tr('Today')),
      StaffSec.patients => (CupertinoIcons.person_2, CupertinoIcons.person_2_fill, tr('Patients')),
      StaffSec.schedule => (CupertinoIcons.calendar, CupertinoIcons.calendar_today, tr('Schedule')),
      StaffSec.ward => (CupertinoIcons.square_grid_2x2, CupertinoIcons.square_grid_2x2_fill, tr('Ward')),
      StaffSec.alerts => (CupertinoIcons.bell, CupertinoIcons.bell_fill, tr('Alerts')),
      StaffSec.review => (CupertinoIcons.waveform_path_ecg, CupertinoIcons.waveform_path_ecg, r == Role.nurse ? tr('Home band') : tr('AdaptAlert review')),
      StaffSec.rules => (CupertinoIcons.sparkles, CupertinoIcons.sparkles, tr('Ward rules')),
      StaffSec.me => (CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill, tr('Me')),
    };

Widget _secPage(StaffSec s) => switch (s) {
      StaffSec.today => const StaffTodayScreen(),
      StaffSec.patients => const PatientsScreen(),
      StaffSec.schedule => const ScheduleScreen(),
      StaffSec.ward => const WardScreen(),
      StaffSec.alerts => const StaffAlertsScreen(),
      StaffSec.review => const HomePatientsScreen(),
      StaffSec.rules => const LearningScreen(),
      StaffSec.me => const StaffMeScreen(),
    };

/// Opens a section: as a tab when it has one (or on a laptop), else as a page.
void openStaffSection(BuildContext context, StaffSec s) {
  final role = context.read<Session>().role;
  if (isWide(context) || _tabSections(role).contains(s)) {
    staffNavKey.currentState?.popUntil((r) => r.isFirst);
    staffSec.value = s.index;
  } else {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => _secPage(s)));
  }
}

/// Counts shown as badges next to sections.
int _badge(BuildContext context, StaffSec s) => switch (s) {
      StaffSec.review => context.watch<MonitorController>().engine.alerts.where((a) => a.doctor == DoctorLabel.pending).length,
      StaffSec.alerts => context.watch<StaffController>().openUnacked,
      _ => 0,
    };

/// The staff app: a navigator under the staff providers, so back closes the
/// open page first, plus a sidebar on laptops.
class StaffRoot extends StatefulWidget {
  const StaffRoot({super.key});
  @override
  State<StaffRoot> createState() => _StaffRootState();
}

class _StaffRootState extends State<StaffRoot> {
  @override
  void initState() {
    super.initState();
    staffSec.value = StaffSec.today.index;
  }

  @override
  Widget build(BuildContext context) {
    final navigator = ShellNavigator(navKey: staffNavKey, tab: staffSec, homeTab: StaffSec.today.index, home: const StaffShell(), labelOf: (t) => _secItem(StaffSec.values[t], context.read<Session>().role).$3);
    if (!isWide(context)) return navigator;
    return ColoredBox(
      color: context.ios.bg,
      child: Row(children: [
        const StaffSidebar(),
        Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1040), child: navigator))),
      ]),
    );
  }
}

class StaffSidebar extends StatelessWidget {
  const StaffSidebar({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final s = context.watch<Session>();
    return Material(
      color: c.card,
      child: Container(
        width: 260,
        decoration: BoxDecoration(color: c.card, border: Border(right: BorderSide(color: c.sep, width: .5))),
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
            child: ValueListenableBuilder<int>(
              valueListenable: staffSec,
              builder: (context, cur, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: LinearGradient(colors: [c.pink, c.red])),
                    child: const Icon(CupertinoIcons.waveform_path_ecg, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('PulseOS', style: T.headline.copyWith(color: c.label)),
                      Text('${s.name} · ${s.role == null ? '' : tr(roleLabel[s.role]!)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: c.label2)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 24),
                for (final sec in staffSections(s.role))
                  Builder(builder: (context) {
                    final on = cur == sec.index;
                    final (icon, active, label) = _secItem(sec, s.role);
                    final n = _badge(context, sec);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: on ? c.blue.withValues(alpha: .12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => openStaffSection(context, sec),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(children: [
                              Icon(on ? active : icon, size: 21, color: on ? c.blue : c.label2),
                              const SizedBox(width: 12),
                              Expanded(child: Text(label, style: T.callout.copyWith(color: on ? c.blue : c.label, fontWeight: on ? FontWeight.w600 : FontWeight.w400))),
                              if (n > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                  decoration: BoxDecoration(color: c.red, borderRadius: BorderRadius.circular(9)),
                                  child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }),
                const Spacer(),
                CupertinoButton.tinted(sizeStyle: CupertinoButtonSize.medium, onPressed: () => showSimulator(staffNavKey.currentContext!), child: Text(tr('Simulate home patient'))),
                const SizedBox(height: 10),
                Text(tr('Research prototype. Not a medical device.'), textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class StaffShell extends StatelessWidget {
  const StaffShell({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final role = context.watch<Session>().role;
    final all = staffSections(role);
    final tabs = _tabSections(role);
    final wide = isWide(context);
    return ValueListenableBuilder<int>(
      valueListenable: staffSec,
      builder: (context, cur, _) {
        final idx = all.indexWhere((x) => x.index == cur);
        return Scaffold(
          backgroundColor: c.bg,
          body: IndexedStack(index: idx < 0 ? 0 : idx, children: [for (final sec in all) _secPage(sec)]),
          bottomNavigationBar: wide
              ? null
              : CupertinoTabBar(
                  currentIndex: tabs.indexWhere((x) => x.index == cur).clamp(0, tabs.length - 1),
                  backgroundColor: c.material,
                  activeColor: c.blue,
                  onTap: (i) {
                    HapticFeedback.selectionClick();
                    staffSec.value = tabs[i].index;
                  },
                  items: [
                    for (final sec in tabs)
                      BottomNavigationBarItem(
                        icon: Badge(isLabelVisible: _badge(context, sec) > 0, label: Text('${_badge(context, sec)}'), child: Icon(_secItem(sec, role).$1)),
                        activeIcon: Badge(isLabelVisible: _badge(context, sec) > 0, label: Text('${_badge(context, sec)}'), child: Icon(_secItem(sec, role).$2)),
                        label: _secItem(sec, role).$3,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final (label, col) = switch (status) { 'live' => (tr('Live'), c.green), 'stale' => (tr('Stale'), c.orange), 'offline' => (tr('Offline'), c.red), _ => (tr('Connecting…'), c.gray) };
    return Pill(label, color: col, icon: status == 'live' ? CupertinoIcons.dot_radiowaves_left_right : null);
  }
}

class WardScreen extends StatelessWidget {
  const WardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final sc = context.watch<StaffController>();
    final s = context.watch<Session>();
    const rank = {'high': 0, 'medium': 1, 'low_medium': 2, 'low': 3};
    final beds = [...sc.beds]..sort((a, b) {
        if (a.empty != b.empty) return a.empty ? 1 : -1;
        final r = (rank[a.band] ?? 4).compareTo(rank[b.band] ?? 4);
        return r != 0 ? r : a.bed.compareTo(b.bed);
      });
    final width = MediaQuery.of(context).size.width;
    final cols = width > 1100 ? 4 : width > 760 ? 3 : 2;
    return LargeTitlePage(
      title: tr('Ward A'),
      subtitle: '${s.name} · ${s.role == Role.doctor ? tr('Doctor') : tr('Nurse')}${s.demo ? ' · ${tr('Demo ward')}' : ''}',
      trailing: StatusPill(status: sc.status),
      children: [
        if (sc.status == 'connecting')
          IOSCard(child: Text(tr('Connecting to the BT39 service. On the free plan it can take about a minute to wake up.'), style: T.footnote.copyWith(color: c.label2))),
        if (sc.beds.isNotEmpty) ...[
          Row(children: [
            for (final (band, label) in [('high', 'High'), ('medium', 'Medium'), ('low_medium', 'Low–med'), ('low', 'Low')])
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: bandColor(context, band).withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    Text('${sc.beds.where((b) => b.band == band).length}', style: T.title2.copyWith(color: bandColor(context, band))),
                    Text(tr(label), style: T.caption.copyWith(color: c.label2)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: beds.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .86),
            itemBuilder: (_, i) => FadeIn(delay: i * 25, child: BedTile(b: beds[i])),
          ),
        ],
        const SizedBox(height: 10),
        Text(tr('Fictional patients. NEWS2 scoring per Royal College of Physicians (2017).'), textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
      ],
    );
  }
}

class BedTile extends StatelessWidget {
  const BedTile({super.key, required this.b});
  final LiveBed b;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final sc = context.read<StaffController>();
    if (b.empty) {
      return Container(
        decoration: BoxDecoration(color: c.card.withValues(alpha: .5), borderRadius: BorderRadius.circular(18), border: Border.all(color: c.sep)),
        alignment: Alignment.center,
        child: Text('${b.bed}\n${tr('Empty')}', textAlign: TextAlign.center, style: T.footnote.copyWith(color: c.label3)),
      );
    }
    final col = bandColor(context, b.band);
    final emergency = b.band == 'high' && b.openAlerts.any((a) => !a.acknowledged);
    Widget v(String label, String? value, String vital, num? x) {
      final pts = b.points[vital] ?? 0; // NEWS2 points, scored by the service
      final vc = pts >= 3 ? c.red : pts == 2 ? c.orange : pts == 1 ? c.yellow : c.label;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: T.caption.copyWith(color: c.label2, fontSize: 10.5)),
        Text(value ?? '—', style: T.headline.copyWith(color: vc, fontFeatures: T.num)),
      ]);
    }

    return _Pulse(
      on: emergency,
      color: c.red,
      child: IOSCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ChangeNotifierProvider.value(value: sc, child: BedScreen(bed: b.bed)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(b.bed, style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(99)),
              child: Text('NEWS2 ${b.news2 ?? '—'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(b.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.headline.copyWith(color: c.label)),
          Text('${b.age}${b.sex}${b.onOxygen == true ? ' · O₂' : ''}', style: T.caption.copyWith(color: c.label2)),
          const Spacer(),
          if (b.stale)
            Text(tr('No signal'), style: T.sub.copyWith(color: c.gray, fontWeight: FontWeight.w600))
          else
            Row(children: [
              Expanded(child: v('HR', b.hr?.toString(), 'hr', b.hr)),
              Expanded(child: v('SpO₂', b.spo2?.toString(), 'spo2', b.spo2)),
              Expanded(child: v('RR', b.rr?.toString(), 'rr', b.rr)),
            ]),
          const SizedBox(height: 6),
          Row(children: [
            Sparkline(sc.hrHistory[b.bed]?.toList() ?? const [], color: col, width: 70, height: 22),
            const Spacer(),
            if (b.openAlerts.isNotEmpty) Pill('${b.openAlerts.length}', icon: CupertinoIcons.bell_fill, color: severityColor(context, b.openAlerts.first.severity)),
          ]),
        ]),
      ),
    );
  }
}

/// Pulses a red border on an unacknowledged emergency (BT39 design rule).
class _Pulse extends StatefulWidget {
  const _Pulse({required this.on, required this.color, required this.child});
  final bool on;
  final Color color;
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on || MediaQuery.disableAnimationsOf(context)) {
      return widget.on ? DecoratedBox(position: DecorationPosition.foreground, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.color, width: 2)), child: widget.child) : widget.child;
    }
    return AnimatedBuilder(
      animation: _a,
      builder: (_, ch) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.color.withValues(alpha: .3 + .7 * _a.value), width: 2.5)),
        child: ch,
      ),
      child: widget.child,
    );
  }
}

class StaffAlertsScreen extends StatefulWidget {
  const StaffAlertsScreen({super.key});
  @override
  State<StaffAlertsScreen> createState() => _StaffAlertsScreenState();
}

class _StaffAlertsScreenState extends State<StaffAlertsScreen> {
  bool _openOnly = true;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final sc = context.watch<StaffController>();
    final list = sc.sortedAlerts.where((a) => !_openOnly || a.open).toList();
    return LargeTitlePage(
      title: tr('Alerts'),
      subtitle: tr('Worst first · tap Acknowledge to stop paging'),
      trailing: StatusPill(status: sc.status),
      children: [
        CupertinoSlidingSegmentedControl<bool>(
          groupValue: _openOnly,
          children: {true: Text(tr('Open ({n})', {'n': sc.alerts.where((a) => a.open).length})), false: Text(tr('All'))},
          onValueChanged: (v) => setState(() => _openOnly = v ?? true),
        ),
        const SizedBox(height: 12),
        if (sc.error != null) IOSCard(child: Text(sc.error!, style: T.footnote.copyWith(color: c.red))),
        if (list.isEmpty) EmptyState(icon: CupertinoIcons.checkmark_seal, title: tr('No open alerts'), message: tr('New alerts appear here the moment the service opens them.')),
        for (final a in list) StaffAlertCard(a: a),
      ],
    );
  }
}

class StaffAlertCard extends StatelessWidget {
  const StaffAlertCard({super.key, required this.a, this.showPatient = true});
  final StaffAlert a;
  final bool showPatient;

  Future<void> _resolve(BuildContext context) async {
    final sc = context.read<StaffController>();
    final note = TextEditingController();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(tr('Resolve alert')),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(controller: note, placeholder: a.severity == 'low' ? tr('Note (optional)') : tr('What was done? (required)'), maxLines: 3, maxLength: 500),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel'))),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Resolve'))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final err = await sc.resolve(a, note.text);
      if (context.mounted) toast(context, err == null ? tr('Alert resolved') : tr('Not resolved'), err);
    }
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final sc = context.watch<StaffController>();
    final col = severityColor(context, a.severity);
    final label = sc.labels[a.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(color: c.card, border: Border(left: BorderSide(color: a.open ? col : c.gray, width: 4))),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(tr(severityLabel[a.severity]!).toUpperCase(), style: T.caption.copyWith(color: col, fontWeight: FontWeight.w800, letterSpacing: .5)),
              const SizedBox(width: 8),
              Pill(trData(a.kindName)),
              const Spacer(),
              Text(DateFormat('h:mm:ss a').format(a.startedAt), style: T.caption.copyWith(color: c.label2)),
            ]),
            const SizedBox(height: 6),
            if (showPatient) Text('${a.bed} · ${a.patientName}', style: T.headline.copyWith(color: c.label)),
            Text(trData(a.message), style: T.footnote.copyWith(color: c.label2)),
            const SizedBox(height: 10),
            if (a.open)
              Row(children: [
                Expanded(
                  child: CupertinoButton.filled(
                    sizeStyle: CupertinoButtonSize.small,
                    onPressed: a.ackAt != null
                        ? null
                        : () async {
                            HapticFeedback.mediumImpact();
                            final err = await sc.ack(a);
                            if (context.mounted && err != null) toast(context, tr('Acknowledge'), err);
                          },
                    child: Text(a.ackAt != null ? tr('Acknowledged') : tr('Acknowledge')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: CupertinoButton.tinted(sizeStyle: CupertinoButtonSize.small, onPressed: () => _resolve(context), child: Text(tr('Resolve')))),
              ])
            else
              Text('${tr('Resolved')} · ${a.resolution == 'auto' ? tr('automatically after 10 quiet minutes') : a.resolution == 'resolved' ? tr('resolved') : a.resolution ?? ''}', style: T.caption.copyWith(color: c.label2)),
            if (a.ackAt != null && a.open) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr('Acknowledged by {who} at {time}', {'who': a.ackBy ?? tr('staff'), 'time': DateFormat('h:mm a').format(a.ackAt!)}), style: T.caption.copyWith(color: c.label2))),
            const SizedBox(height: 10),
            Row(children: [
              Icon(CupertinoIcons.sparkles, size: 14, color: c.indigo),
              const SizedBox(width: 4),
              Text(tr('Was this clinically real?'), style: T.caption.copyWith(color: c.label2)),
              const Spacer(),
              _LabelBtn(text: tr('Real'), on: label == true, color: c.red, onTap: () => sc.label(a, true)),
              const SizedBox(width: 6),
              _LabelBtn(text: tr('False alarm'), on: label == false, color: c.green, onTap: () => sc.label(a, false)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _LabelBtn extends StatelessWidget {
  const _LabelBtn({required this.text, required this.on, required this.color, required this.onTap});
  final String text;
  final bool on;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: on ? color : color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
          child: Text(text, style: T.caption.copyWith(color: on ? Colors.white : color, fontWeight: FontWeight.w700)),
        ),
      );
}

/// What staff labels say about each alert rule: the data AdaptAlert needs
/// to tune a ward's rules, the same way it tunes a home patient's alerts.
class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final sc = context.watch<StaffController>();
    final p = sc.precisionByKind;
    final total = p.values.fold(0, (a, v) => a + v.total), real = p.values.fold(0, (a, v) => a + v.real);
    return LargeTitlePage(
      title: 'AdaptAlert',
      subtitle: tr('How often each ward rule is right'),
      children: [
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('BT39 alerts on fixed NEWS2 and trend rules. Every “Real” or “False alarm” label here is feedback for AdaptAlert: rules that are mostly false alarms for this ward are the ones to tune first.'), style: T.footnote.copyWith(color: c.label, height: 1.4)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Big('$total', tr('labelled'), c.blue)),
              Expanded(child: _Big(total == 0 ? '—' : '${(100 * real / total).round()}%', tr('real'), c.red)),
              Expanded(child: _Big(total == 0 ? '—' : '${(100 * (total - real) / total).round()}%', tr('false alarms'), c.green)),
            ]),
          ]),
        ),
        SectionHeader(tr('By rule')),
        if (p.isEmpty)
          EmptyState(icon: CupertinoIcons.tag, title: tr('No labels yet'), message: tr('Label alerts as Real or False alarm in the Alerts tab.'))
        else
          IOSCard(
            child: Column(children: [
              for (final e in p.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(trData(e.key), style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w600))),
                      Text(tr('{real} of {total} real', {'real': e.value.real, 'total': e.value.total}), style: T.caption.copyWith(color: c.label2)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: e.value.real / e.value.total, minHeight: 8, color: c.red, backgroundColor: c.green.withValues(alpha: .35)),
                    ),
                  ]),
                ),
            ]),
          ),
      ],
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.v, this.l, this.col);
  final String v, l;
  final Color col;
  @override
  Widget build(BuildContext context) => Column(children: [Text(v, style: T.title1.copyWith(color: col)), Text(l, style: T.caption.copyWith(color: context.ios.label2))]);
}

class StaffMeScreen extends StatelessWidget {
  const StaffMeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final s = context.watch<Session>();
    final sc = context.watch<StaffController>();
    return LargeTitlePage(
      title: tr('Me'),
      children: [
        IOSCard(
          child: Row(children: [
            Avatar(s.name, size: 60, colors: [c.teal, c.blue]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: T.title2.copyWith(color: c.label)),
                Text(s.email, style: T.footnote.copyWith(color: c.label2)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [Pill(s.role == Role.doctor ? tr('Doctor') : tr('Nurse'), color: c.blue), Pill(s.demo ? tr('Demo ward') : tr('Ward A'), color: s.demo ? c.orange : c.green)]),
              ]),
            ),
          ]),
        ),
        if (s.demo) ...[const SizedBox(height: 12), const DemoBanner()],
        FormGroup(header: tr('Work'), children: [
          IOSRow(icon: CupertinoIcons.number, iconColor: c.indigo, title: tr('Registration no.'), trailing: Text(s.details['registration']?.isNotEmpty == true ? s.details['registration']! : (s.role == Role.doctor ? 'DMC-48213' : 'DNC-20917'), style: T.body.copyWith(color: c.label2)), chevron: false),
          if (s.role == Role.doctor) ...[
            IOSRow(icon: CupertinoIcons.heart_fill, iconColor: c.pink, title: tr('Speciality'), trailing: Text(trData(s.details['specialty'] ?? 'Cardiologist'), style: T.body.copyWith(color: c.label2)), chevron: false),
            IOSRow(icon: CupertinoIcons.building_2_fill, iconColor: c.blue, title: tr('Hospital'), trailing: Text(s.details['hospital']?.isNotEmpty == true ? s.details['hospital']! : 'Fortis Heart Institute', style: T.body.copyWith(color: c.label2)), chevron: false),
          ] else ...[
            IOSRow(icon: CupertinoIcons.bed_double_fill, iconColor: c.teal, title: tr('Ward'), trailing: Text(trData(s.details['ward'] ?? 'Ward A'), style: T.body.copyWith(color: c.label2)), chevron: false),
            IOSRow(icon: CupertinoIcons.clock_fill, iconColor: c.orange, title: tr('Shift'), trailing: Text(trData(s.details['shift'] ?? 'Morning'), style: T.body.copyWith(color: c.label2)), chevron: false),
          ],
          IOSRow(icon: CupertinoIcons.mail_solid, iconColor: c.gray, title: tr('Email'), trailing: Text(s.email, style: T.body.copyWith(color: c.label2)), chevron: false),
        ]),
        FormGroup(header: tr('Connection'), children: [
          IOSRow(icon: CupertinoIcons.antenna_radiowaves_left_right, iconColor: c.green, title: tr('Live stream'), trailing: StatusPill(status: sc.status), chevron: false),
          IOSRow(icon: CupertinoIcons.cloud_fill, iconColor: c.blue, title: tr('Source'), subtitle: s.demo ? tr('BT39 service demo ward (12 beds, NEWS2 every second)') : tr('BT39 monitor service + Supabase'), chevron: false),
        ]),
        const SizedBox(height: 20),
        GroupedList(children: [
          const LanguageRow(),
          IOSRow(icon: CupertinoIcons.person_crop_circle_badge_checkmark, iconColor: c.blue, title: tr('Accessibility'), subtitle: tr('Larger text, bold text, less motion'), onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const AccessibilityScreen()))),
        ]),
        const SizedBox(height: 20),
        GroupedList(children: [
          IOSRow(
            title: s.demo ? tr('Leave Demo Mode') : tr('Sign out'),
            destructive: true,
            chevron: false,
            onTap: () async {
              if (await confirm(context, title: s.demo ? tr('Leave Demo Mode?') : tr('Sign out?'), message: tr('The live stream will close.'), action: s.demo ? tr('Leave') : tr('Sign out'))) await s.signOut();
            },
          ),
        ]),
      ],
    );
  }
}
