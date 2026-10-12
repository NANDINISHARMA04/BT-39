import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../engine/adapt_alert.dart';
import '../../services/monitor.dart';
import '../../services/session.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/vitals.dart';
import '../patient/alert_detail_screen.dart';
import '../patient/alerts_screen.dart';
import '../patient/how_it_works_screen.dart';
import '../patient/patient_shell.dart';

/// Patients monitored at home with AdaptAlert. Staff review their alerts, and
/// each review teaches AdaptAlert about that patient.
class HomePatientsScreen extends StatelessWidget {
  const HomePatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final s = context.watch<Session>();
    final m = context.watch<MonitorController>();
    final e = m.engine;
    final r = m.last;
    final pending = e.alerts.where((a) => a.doctor == DoctorLabel.pending).toList();
    final reviewed = e.alerts.where((a) => a.doctor != DoctorLabel.pending).toList();
    final (statusText, statusColor) = switch (e.status) {
      'alert' => ('Alert', c.red),
      'watch' => ('Watching', c.orange),
      'held' => ('Learned pattern', c.indigo),
      'band' => ('No signal', c.gray),
      _ => ('Stable', c.green),
    };
    return LargeTitlePage(
      title: 'Home patients',
      subtitle: 'Remote monitoring with AdaptAlert · ${pending.length} to review',
      trailing: CupertinoButton(padding: EdgeInsets.zero, onPressed: () => showSimulator(context), child: const Icon(CupertinoIcons.slider_horizontal_3)),
      children: [
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar('Aarav Mehta', size: 48, colors: [c.orange, c.pink]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Aarav Mehta, 58', style: T.headline.copyWith(color: c.label)),
                  Text('Heart bypass (CABG), day 6 at home · band live', style: T.footnote.copyWith(color: c.label2)),
                ]),
              ),
              Pill(statusText, color: statusColor),
            ]),
            if (r != null) ...[
              const SizedBox(height: 14),
              Row(children: [
                _Vital('HR', r.good ? '${r.r.hr}' : '--', 'bpm', c.pink),
                _Vital('SpO₂', r.good ? '${r.r.spo2}' : '--', '%', c.blue),
                _Vital('Temp', r.good ? r.r.temp.toStringAsFixed(1) : '--', '°C', c.orange),
                _Vital('Activity', r.act, '', c.green),
              ]),
              const SizedBox(height: 10),
              Sparkline(e.history.reversed.take(60).toList().reversed.map((h) => h.good ? h.r.hr : null).toList(), color: c.pink, width: double.infinity, height: 40),
            ],
            const SizedBox(height: 10),
            Text('Sensitivity τ ${pct(e.tau)} · ${e.labels} feedback answers · ${e.held.length} alerts held back today', style: T.caption.copyWith(color: c.label2)),
          ]),
        ),
        const SizedBox(height: 12),
        const AdaptAlertHero(),
        SectionHeader('To review', trailing: '${pending.length}'),
        if (pending.isEmpty)
          const EmptyState(icon: CupertinoIcons.checkmark_seal, title: 'Nothing to review', message: 'New AdaptAlert alerts from home patients appear here. Use the sliders icon to simulate one.')
        else
          for (final a in pending) AlertCard(a: a, staffMode: true, reviewer: s.name),
        if (reviewed.isNotEmpty) ...[
          SectionHeader('Reviewed', trailing: '${reviewed.length}'),
          GroupedList(children: [
            for (final a in reviewed)
              IOSRow(
                icon: a.doctor == DoctorLabel.confirmed ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle_fill,
                iconColor: a.doctor == DoctorLabel.confirmed ? c.red : c.green,
                title: a.title,
                subtitle: '${hhmm(a.t)} · ${a.doctor == DoctorLabel.confirmed ? 'Confirmed real' : 'False alarm'}${a.reviewedBy == null ? '' : ' · ${a.reviewedBy}'}',
                onTap: () => openAlertDetail(context, a, staffMode: true, reviewer: s.name),
              ),
          ]),
        ],
        const SectionHeader('Other home patients', trailing: 'examples'),
        GroupedList(children: [
          IOSRow(leading: Avatar('Sunita Verma', size: 36, colors: [c.teal, c.green]), title: 'Sunita Verma, 64', subtitle: 'COPD · SpO₂ 93% · learned: night dips are normal for her', trailing: Pill('Stable', color: c.green), chevron: false),
          IOSRow(leading: Avatar('Rahul Iyer', size: 36, colors: [c.teal, c.green]), title: 'Rahul Iyer, 47', subtitle: 'After appendix surgery · no alerts this week', trailing: Pill('Stable', color: c.green), chevron: false),
        ]),
      ],
    );
  }
}

class _Vital extends StatelessWidget {
  const _Vital(this.label, this.value, this.unit, this.color);
  final String label, value, unit;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: T.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
        Text.rich(TextSpan(children: [
          TextSpan(text: value, style: T.title3.copyWith(color: c.label, fontFeatures: T.num)),
          if (unit.isNotEmpty) TextSpan(text: ' $unit', style: T.caption.copyWith(color: c.label2)),
        ]), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
