import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../engine/news2.dart';
import '../../engine/adapt_alert.dart';
import '../../services/bt39_client.dart';
import '../../services/monitor.dart';
import '../../services/session.dart';
import '../../services/staff_controller.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/vitals.dart';
import 'bed_screen.dart';
import 'home_patients_screen.dart';

Color bandColor(BuildContext context, String? band) {
  final c = context.ios;
  return switch (band) { 'high' => c.red, 'medium' => c.orange, 'low_medium' => c.yellow, 'low' => c.green, _ => c.gray };
}

Color severityColor(BuildContext context, String s) {
  final c = context.ios;
  return switch (s) { 'high' => c.red, 'medium' => c.orange, _ => c.yellow };
}

class StaffShell extends StatefulWidget {
  const StaffShell({super.key});
  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final sc = context.watch<StaffController>();
    final home = context.watch<MonitorController>();
    final toReview = home.engine.alerts.where((a) => a.doctor == DoctorLabel.pending).length;
    final pages = const [WardScreen(), HomePatientsScreen(), StaffAlertsScreen(), LearningScreen(), StaffMeScreen()];
    return Scaffold(
      backgroundColor: c.bg,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _tab,
        backgroundColor: c.material,
        activeColor: c.blue,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _tab = i);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.square_grid_2x2), activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill), label: 'Ward'),
          BottomNavigationBarItem(
            icon: Badge(isLabelVisible: toReview > 0, label: Text('$toReview'), child: const Icon(CupertinoIcons.house)),
            activeIcon: Badge(isLabelVisible: toReview > 0, label: Text('$toReview'), child: const Icon(CupertinoIcons.house_fill)),
            label: 'Home patients',
          ),
          BottomNavigationBarItem(
            icon: Badge(isLabelVisible: sc.openUnacked > 0, label: Text('${sc.openUnacked}'), child: const Icon(CupertinoIcons.bell)),
            activeIcon: Badge(isLabelVisible: sc.openUnacked > 0, label: Text('${sc.openUnacked}'), child: const Icon(CupertinoIcons.bell_fill)),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.sparkles), label: 'AdaptAlert'),
          const BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_crop_circle), activeIcon: Icon(CupertinoIcons.person_crop_circle_fill), label: 'Me'),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final (label, col) = switch (status) { 'live' => ('Live', c.green), 'stale' => ('Stale', c.orange), 'offline' => ('Offline', c.red), _ => ('Connecting…', c.gray) };
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
      title: 'Ward A',
      subtitle: '${s.name} · ${s.role == Role.doctor ? 'Doctor' : 'Nurse'}${s.onDevice ? ' · Demo ward' : ''}',
      trailing: StatusPill(status: sc.status),
      children: [
        if (sc.status == 'connecting' && !s.onDevice)
          IOSCard(child: Text('Connecting to the BT39 service. On the free plan it can take about a minute to wake up.', style: T.footnote.copyWith(color: c.label2))),
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
                    Text(label, style: T.caption.copyWith(color: c.label2)),
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
        Text('Fictional patients. NEWS2 scoring per Royal College of Physicians (2017).', textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
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
        child: Text('${b.bed}\nEmpty', textAlign: TextAlign.center, style: T.footnote.copyWith(color: c.label3)),
      );
    }
    final col = bandColor(context, b.band);
    final emergency = b.band == 'high' && b.openAlerts.any((a) => !a.acknowledged);
    Widget v(String label, String? value, String vital, num? x) {
      final pts = news2Points(vital, x, onOxygen: b.onOxygen ?? false) ?? 0;
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
            Text('No signal', style: T.sub.copyWith(color: c.gray, fontWeight: FontWeight.w600))
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
      title: 'Alerts',
      subtitle: 'Worst first · tap Acknowledge to stop paging',
      trailing: StatusPill(status: sc.status),
      children: [
        CupertinoSlidingSegmentedControl<bool>(
          groupValue: _openOnly,
          children: {true: Text('Open (${sc.alerts.where((a) => a.open).length})'), false: const Text('All')},
          onValueChanged: (v) => setState(() => _openOnly = v ?? true),
        ),
        const SizedBox(height: 12),
        if (sc.error != null) IOSCard(child: Text(sc.error!, style: T.footnote.copyWith(color: c.red))),
        if (list.isEmpty) const EmptyState(icon: CupertinoIcons.checkmark_seal, title: 'No open alerts', message: 'New alerts appear here the moment the service opens them.'),
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
        title: const Text('Resolve alert'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(controller: note, placeholder: a.severity == 'low' ? 'Note (optional)' : 'What was done? (required)', maxLines: 3, maxLength: 500),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('Resolve')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final err = await sc.resolve(a, note.text);
      if (context.mounted) toast(context, err == null ? 'Alert resolved' : 'Not resolved', err);
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
              Text(severityLabel[a.severity]!.toUpperCase(), style: T.caption.copyWith(color: col, fontWeight: FontWeight.w800, letterSpacing: .5)),
              const SizedBox(width: 8),
              Pill(a.kindName),
              const Spacer(),
              Text(DateFormat('h:mm:ss a').format(a.startedAt), style: T.caption.copyWith(color: c.label2)),
            ]),
            const SizedBox(height: 6),
            if (showPatient) Text('${a.bed} · ${a.patientName}', style: T.headline.copyWith(color: c.label)),
            Text(a.message, style: T.footnote.copyWith(color: c.label2)),
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
                            if (context.mounted && err != null) toast(context, 'Acknowledge', err);
                          },
                    child: Text(a.ackAt != null ? 'Acknowledged' : 'Acknowledge'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: CupertinoButton.tinted(sizeStyle: CupertinoButtonSize.small, onPressed: () => _resolve(context), child: const Text('Resolve'))),
              ])
            else
              Text('Resolved · ${a.resolution == 'auto' ? 'automatically after 10 quiet minutes' : a.resolution ?? ''}', style: T.caption.copyWith(color: c.label2)),
            if (a.ackAt != null && a.open) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Acknowledged by ${a.ackBy ?? 'staff'} at ${DateFormat('h:mm a').format(a.ackAt!)}', style: T.caption.copyWith(color: c.label2))),
            const SizedBox(height: 10),
            Row(children: [
              Icon(CupertinoIcons.sparkles, size: 14, color: c.indigo),
              const SizedBox(width: 4),
              Text('Was this clinically real?', style: T.caption.copyWith(color: c.label2)),
              const Spacer(),
              _LabelBtn(text: 'Real', on: label == true, color: c.red, onTap: () => sc.label(a, true)),
              const SizedBox(width: 6),
              _LabelBtn(text: 'False alarm', on: label == false, color: c.green, onTap: () => sc.label(a, false)),
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
      subtitle: 'How often each ward rule is right',
      children: [
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BT39 alerts on fixed NEWS2 and trend rules. Every “Real” or “False alarm” label here is feedback for AdaptAlert: rules that are mostly false alarms for this ward are the ones to tune first.', style: T.footnote.copyWith(color: c.label, height: 1.4)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Big('$total', 'labelled', c.blue)),
              Expanded(child: _Big(total == 0 ? '—' : '${(100 * real / total).round()}%', 'real', c.red)),
              Expanded(child: _Big(total == 0 ? '—' : '${(100 * (total - real) / total).round()}%', 'false alarms', c.green)),
            ]),
          ]),
        ),
        const SectionHeader('By rule'),
        if (p.isEmpty)
          const EmptyState(icon: CupertinoIcons.tag, title: 'No labels yet', message: 'Label alerts as Real or False alarm in the Alerts tab.')
        else
          IOSCard(
            child: Column(children: [
              for (final e in p.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(e.key, style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w600))),
                      Text('${e.value.real} of ${e.value.total} real', style: T.caption.copyWith(color: c.label2)),
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
      title: 'Me',
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
                Wrap(spacing: 6, children: [Pill(s.role == Role.doctor ? 'Doctor' : 'Nurse', color: c.blue), Pill(s.onDevice ? 'Demo ward' : 'Ward A', color: s.onDevice ? c.orange : c.green)]),
              ]),
            ),
          ]),
        ),
        FormGroup(header: 'Connection', children: [
          IOSRow(icon: CupertinoIcons.antenna_radiowaves_left_right, iconColor: c.green, title: 'Live stream', trailing: StatusPill(status: sc.status), chevron: false),
          IOSRow(icon: CupertinoIcons.cloud_fill, iconColor: c.blue, title: 'Source', subtitle: s.onDevice ? 'On-device demo ward (12 beds, NEWS2 every second)' : 'BT39 monitor service + Supabase', chevron: false),
        ]),
        const SizedBox(height: 20),
        GroupedList(children: [
          IOSRow(
            title: s.demo ? 'Leave Demo Mode' : 'Sign out',
            destructive: true,
            chevron: false,
            onTap: () async {
              if (await confirm(context, title: s.demo ? 'Leave Demo Mode?' : 'Sign out?', message: 'The live stream will close.', action: s.demo ? 'Leave' : 'Sign out')) await s.signOut();
            },
          ),
        ]),
      ],
    );
  }
}
