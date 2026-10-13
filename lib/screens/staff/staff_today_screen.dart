import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../engine/adapt_alert.dart';
import '../../l10n/l10n.dart';
import '../../services/clinical_store.dart';
import '../../services/monitor.dart';
import '../../services/session.dart';
import '../../services/staff_controller.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/demo_banner.dart';
import '../patient/alert_detail_screen.dart';
import '../patient/how_it_works_screen.dart';
import 'bed_screen.dart';
import 'patients_screen.dart';
import 'schedule_screen.dart';
import 'staff_shell.dart';

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? tr('Good morning') : h < 17 ? tr('Good afternoon') : tr('Good evening');
}

/// The first page staff see: a doctor's day, or a nurse's shift.
class StaffTodayScreen extends StatelessWidget {
  const StaffTodayScreen({super.key});
  @override
  Widget build(BuildContext context) => context.watch<Session>().role == Role.nurse ? const _NurseShift() : const _DoctorToday();
}

Widget _meButton(BuildContext context) {
  final s = context.watch<Session>();
  final c = context.ios;
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Semantics(
      button: true,
      label: tr('Ask'),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: () => openStaffSection(context, StaffSec.ask),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [c.teal, c.indigo])),
          child: const Icon(CupertinoIcons.chat_bubble_2_fill, size: 17, color: Colors.white),
        ),
      ),
    ),
    const SizedBox(width: 6),
    CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => openStaffSection(context, StaffSec.me),
      child: Avatar(s.name, size: 32, colors: [c.teal, c.blue]),
    ),
  ]);
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.icon, this.color, this.value, this.label, this.onTap);
  final IconData icon;
  final Color color;
  final String value, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return IOSCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [IconSquare(icon, color, size: 28), const Spacer(), Icon(CupertinoIcons.chevron_right, size: 14, color: c.label3)]),
        const SizedBox(height: 10),
        Text(value, style: T.title1.copyWith(color: c.label, fontFeatures: T.num)),
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: c.label2)),
      ]),
    );
  }
}

Widget _kpiGrid(BuildContext context, List<Widget> tiles) {
  final cols = MediaQuery.sizeOf(context).width >= 700 ? 4 : 2;
  return GridView(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 140),
    children: tiles,
  );
}

class _DoctorToday extends StatelessWidget {
  const _DoctorToday();
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final s = context.watch<Session>();
    final m = context.watch<MonitorController>();
    final sc = context.watch<StaffController>();
    final cs = context.watch<ClinicalStore>();
    final now = DateTime.now();
    final pending = m.engine.alerts.where((a) => a.doctor == DoctorLabel.pending).toList();
    final today = cs.visitsOn(now);
    final next = [...today, ...cs.visitsOn(now.add(const Duration(days: 1)))].where((v) => v.status == VisitStatus.upcoming && v.at.isAfter(now.subtract(const Duration(minutes: 30)))).take(3).toList();
    final risky = sc.beds.where((b) => !b.empty && (b.band == 'high' || b.band == 'medium')).toList();
    final live = cs.byId(livePatientId);
    final watching = cs.patients.where((p) => p.status == 'Watching').toList();
    return LargeTitlePage(
      title: tr('Today'),
      subtitle: '${_greeting()}, ${s.name} · ${DateFormat('EEE d MMM').format(now)}',
      trailing: _meButton(context),
      children: [
        if (s.demo) ...[const DemoBanner(), const SizedBox(height: 12)],
        _kpiGrid(context, [
          _Kpi(CupertinoIcons.waveform_path_ecg, c.indigo, '${pending.length}', tr('AdaptAlert alerts to review'), () => openStaffSection(context, StaffSec.review)),
          _Kpi(CupertinoIcons.calendar, c.blue, '${today.where((v) => v.status == VisitStatus.upcoming).length}', tr('appointments left today'), () => openStaffSection(context, StaffSec.schedule)),
          _Kpi(CupertinoIcons.exclamationmark_triangle_fill, c.red, '${risky.length}', tr('ward patients at medium or high risk'), () => openStaffSection(context, StaffSec.ward)),
          _Kpi(CupertinoIcons.bell_fill, c.orange, '${sc.openUnacked}', tr('ward alerts not acknowledged'), () => openStaffSection(context, StaffSec.alerts)),
        ]),
        SectionHeader(tr('Needs you now')),
        if (pending.isEmpty && risky.isEmpty && watching.isEmpty)
          EmptyState(icon: CupertinoIcons.checkmark_seal, title: tr('All clear'), message: tr('Nothing needs you right now.'))
        else
          GroupedList(children: [
            for (final a in pending)
              IOSRow(
                icon: CupertinoIcons.waveform_path_ecg,
                iconColor: a.level >= 3 || a.safety ? c.red : c.indigo,
                title: '${live?.name ?? tr('Home patient')}: ${a.title}',
                subtitle: '${hhmm(a.t)} · ${a.levelLabel} · ${tr('{p} likely real · tap to review', {'p': pct(a.p)})}',
                onTap: () => openAlertDetail(context, a, staffMode: true, reviewer: s.name),
              ),
            for (final b in risky.take(3))
              IOSRow(
                icon: CupertinoIcons.bed_double_fill,
                iconColor: bandColor(context, b.band),
                title: '${b.bed} · ${b.name}',
                subtitle: 'NEWS2 ${b.news2 ?? '—'} · ${b.band == 'high' ? tr('High risk: urgent review') : tr('Medium risk: review within the hour')}',
                onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => BedScreen(bed: b.bed))),
              ),
            for (final p in watching)
              IOSRow(
                leading: Avatar(p.name, size: 30, colors: [c.orange, c.pink]),
                title: p.name,
                subtitle: trData(p.condition),
                onTap: () => openPatient(context, p.id),
              ),
          ]),
        SectionHeader(tr('Next appointments'), trailing: tr('Schedule'), onTrailing: () => openStaffSection(context, StaffSec.schedule)),
        if (next.isEmpty)
          EmptyState(icon: CupertinoIcons.calendar, title: tr('No more appointments'), message: tr('Book a follow-up from a patient\'s page.'))
        else
          GroupedList(children: [for (final v in next) VisitRow(v: v)]),
        SectionHeader(tr('AdaptAlert at home')),
        const AdaptAlertHero(),
      ],
    );
  }
}

class _NurseShift extends StatefulWidget {
  const _NurseShift();
  @override
  State<_NurseShift> createState() => _NurseShiftState();
}

class _NurseShiftState extends State<_NurseShift> {
  final _handover = TextEditingController();

  @override
  void dispose() {
    _handover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final s = context.watch<Session>();
    final sc = context.watch<StaffController>();
    final cs = context.watch<ClinicalStore>();
    final m = context.watch<MonitorController>();
    final beds = sc.beds.where((b) => !b.empty).map((b) => '${b.bed} ${b.name ?? ''}'.trim()).toList();
    final tasks = cs.tasksFor(beds);
    final done = tasks.where((t) => cs.doneBy(t.id) != null).length;
    final hour = DateTime.now().hour;
    final risky = sc.beds.where((b) => !b.empty && b.band == 'high').length;
    return LargeTitlePage(
      title: tr('My shift'),
      subtitle: '${_greeting()}, ${s.name} · ${tr('{shift} shift', {'shift': trData(s.details['shift'] ?? 'Morning')})} · ${trData(s.details['ward'] ?? 'Ward A')}',
      trailing: _meButton(context),
      children: [
        if (s.demo) ...[const DemoBanner(), const SizedBox(height: 12)],
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(tr('{done} of {total}', {'done': done, 'total': tasks.length}), style: T.title1.copyWith(color: c.label, fontFeatures: T.num)),
              const SizedBox(width: 8),
              Text(tr('tasks done'), style: T.footnote.copyWith(color: c.label2)),
              const Spacer(),
              Text(DateFormat('EEE d MMM').format(DateTime.now()), style: T.footnote.copyWith(color: c.label2)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: tasks.isEmpty ? 0 : done / tasks.length, minHeight: 10, color: c.green, backgroundColor: c.fill),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              GestureDetector(onTap: () => openStaffSection(context, StaffSec.alerts), child: Pill(tr('{n} alerts to acknowledge', {'n': sc.openUnacked}), icon: CupertinoIcons.bell_fill, color: sc.openUnacked > 0 ? c.red : c.green)),
              GestureDetector(onTap: () => openStaffSection(context, StaffSec.ward), child: Pill(tr('{n} high-risk beds', {'n': risky}), icon: CupertinoIcons.bed_double_fill, color: risky > 0 ? c.orange : c.green)),
              GestureDetector(
                onTap: () => openStaffSection(context, StaffSec.review),
                child: Pill(tr('Home band: {status}', {'status': m.engine.status == 'alert' ? tr('alert') : m.engine.status == 'band' ? tr('no signal') : tr('stable')}), icon: CupertinoIcons.waveform_path_ecg, color: m.engine.status == 'alert' ? c.red : c.indigo),
              ),
            ]),
          ]),
        ),
        SectionHeader(tr('Tasks')),
        GroupedList(children: [
          for (final t in tasks)
            Builder(builder: (context) {
              final by = cs.doneBy(t.id);
              final late = by == null && t.hour < hour;
              final due = by == null && t.hour == hour;
              return IOSRow(
                leading: Icon(by != null ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle, color: by != null ? c.green : c.label3, size: 26),
                title: '${t.hour.toString().padLeft(2, '0')}:00 · ${t.title}',
                subtitle: by != null ? tr('Done by {by}', {'by': by}) : t.detail,
                trailing: late ? Pill(tr('Overdue'), color: c.red) : due ? Pill(tr('Due now'), color: c.orange) : null,
                chevron: false,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (t.kind == 'check') {
                    openPatient(context, livePatientId);
                  }
                  cs.toggleTask(t.id);
                },
              );
            }),
        ]),
        SectionHeader(tr('Handover')),
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CupertinoTextField(
              controller: _handover,
              placeholder: tr('What should the next shift know? Patients to watch, pending results, family updates…'),
              maxLines: 4,
              minLines: 3,
              padding: const EdgeInsets.all(12),
              style: T.body.copyWith(color: c.label),
              decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 10),
            CupertinoButton.filled(
              sizeStyle: CupertinoButtonSize.medium,
              onPressed: () async {
                if (_handover.text.trim().isEmpty) return;
                await cs.addHandover(_handover.text);
                _handover.clear();
                if (context.mounted) toast(context, tr('Handover saved'), tr('The next shift sees it here.'));
              },
              child: Text(tr('Save handover')),
            ),
          ]),
        ),
        if (cs.handovers.isNotEmpty) ...[
          const SizedBox(height: 12),
          GroupedList(children: [
            for (final h in cs.handovers.take(3))
              IOSRow(
                icon: CupertinoIcons.doc_text_fill,
                iconColor: c.teal,
                title: h.text,
                subtitle: '${h.by} · ${DateFormat('d MMM, h:mm a').format(h.at)}',
                chevron: false,
              ),
          ]),
        ],
      ],
    );
  }
}
