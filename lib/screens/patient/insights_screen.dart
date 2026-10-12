import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/adapt_alert.dart';
import '../../engine/study.dart';
import '../../services/monitor.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/vitals.dart';
import '../research/research_lab_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

/// Which vital the Insights chart shows. Today's cards set it before switching tabs.
final insightsVital = ValueNotifier<String>('hr');

class _InsightsScreenState extends State<InsightsScreen> {
  String get _vital => insightsVital.value;

  @override
  void initState() {
    super.initState();
    insightsVital.addListener(_onVital);
  }

  @override
  void dispose() {
    insightsVital.removeListener(_onVital);
    super.dispose();
  }

  void _onVital() => setState(() {});

  int _seed = 7;
  late StudyResult _study = runStudy(seed: _seed);

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final m = context.watch<MonitorController>();
    final e = m.engine;
    final good = e.history.where((h) => h.good).toList();
    final vals = good.map((h) => h.value(_vital)).toList();
    final dec = _vital == 'temp' ? 1 : 0;
    final color = switch (_vital) { 'hr' => c.pink, 'spo2' => c.blue, _ => c.orange };
    final unit = switch (_vital) { 'hr' => 'bpm', 'spo2' => '%', _ => '°C' };
    return LargeTitlePage(
      title: 'Insights',
      subtitle: 'Health analytics and the AI behind your alerts',
      children: [
        CupertinoSlidingSegmentedControl<String>(
          groupValue: _vital,
          children: const {'hr': Text('Heart rate'), 'spo2': Text('Oxygen'), 'temp': Text('Temperature')},
          onValueChanged: (v) => insightsVital.value = v ?? 'hr',
        ),
        const SizedBox(height: 12),
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Last ${(e.history.length / 60).toStringAsFixed(1)} hours · $unit', style: T.sub.copyWith(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TrendChart(history: e.history, vital: _vital, color: color),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 6, children: [
              _Legend(color: c.blue.withValues(alpha: .25), label: 'Your normal (±2 SD)'),
              _Legend(color: c.fill2, label: 'Unreliable data'),
              _Legend(color: c.red, label: 'Alert', round: true),
              _Legend(color: c.indigo, label: 'Held back', round: true, hollow: true),
            ]),
            const SizedBox(height: 12),
            if (vals.isNotEmpty)
              Row(children: [
                _MiniStat('Low', vals.reduce(min).toStringAsFixed(dec)),
                const SizedBox(width: 8),
                _MiniStat('Average', (vals.reduce((a, b) => a + b) / vals.length).toStringAsFixed(dec)),
                const SizedBox(width: 8),
                _MiniStat('High', vals.reduce(max).toStringAsFixed(dec)),
              ]),
          ]),
        ),
        const SectionHeader('Your personal normal', trailing: 'learned, not fixed'),
        GroupedList(
          footer: 'Updated slowly from good-quality readings only. Readings during an alert never count, so a problem can\'t become your new normal.',
          children: [
            for (final (k, name, col, icon) in [
              ('rest', 'Resting', c.green, CupertinoIcons.bed_double_fill),
              ('light', 'Light activity', c.teal, CupertinoIcons.person_fill),
              ('active', 'Active', c.blue, CupertinoIcons.flame_fill),
            ])
              IOSRow(
                icon: icon,
                iconColor: col,
                title: name,
                subtitle: 'HR ${e.base[k]!['hr']!.mu.round()} ± ${(2 * e.base[k]!['hr']!.sd).round()} · SpO₂ ${e.base[k]!['spo2']!.mu.toStringAsFixed(1)}% · ${e.base[k]!['temp']!.mu.toStringAsFixed(2)} °C',
                chevron: false,
              ),
          ],
        ),
        const SectionHeader('Alert load today', trailing: 'per hour'),
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AlertLoadChart(history: e.history),
            const SizedBox(height: 8),
            Wrap(spacing: 12, children: [_Legend(color: c.gray, label: 'Fixed-threshold alarms'), _Legend(color: c.green, label: 'AdaptAlert alerts')]),
          ]),
        ),
        const SectionHeader('AI engine, live', trailing: 'every minute'),
        PipelineList(pipe: e.pipe),
        const SectionHeader('Your sensitivity'),
        IOSCard(
          child: Column(children: [
            Row(children: [
              TauGauge(tau: e.tau, min: tauMin, max: tauMax),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Alert threshold τ', style: T.footnote.copyWith(color: c.label2)),
                  AnimatedNumber(e.tau * 100, style: T.title1.copyWith(color: c.label)),
                  const SizedBox(height: 6),
                  Text('Feedback answers', style: T.footnote.copyWith(color: c.label2)),
                  Text('${e.labels}', style: T.title2.copyWith(color: c.label)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Text('An alert is sent when the AI is at least τ sure it is real. τ stays between 30% and 75% (shaded) and moves at most 10 points a week. Safety-floor alerts ignore τ.', style: T.footnote.copyWith(color: c.label2)),
          ]),
        ),
        SectionHeader('What it has learned', trailing: e.buckets.isEmpty ? null : '${e.buckets.length} pattern${e.buckets.length == 1 ? '' : 's'}'),
        IOSCard(
          padding: EdgeInsets.zero,
          child: e.buckets.isEmpty
              ? Padding(padding: const EdgeInsets.all(16), child: Text('No feedback yet. Answer an alert to teach AdaptAlert.', style: T.sub.copyWith(color: c.label2)))
              : Column(children: [
                  for (final (i, k) in e.buckets.keys.indexed) ...[
                    if (i > 0) Divider(height: .5, color: c.sep),
                    _BucketRow(k: k, engine: e),
                  ],
                ]),
        ),
        const SectionHeader('30-day study', trailing: 'simulated'),
        IOSCard(
          onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ResearchLabScreen())),
          color: c.indigo,
          child: Row(children: [
            const Icon(CupertinoIcons.lab_flask_solid, color: Colors.white, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Open the Research Lab', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
                Text('Run your own experiments: 5 systems, ablation, alarm fatigue, federated cold start, 95% CIs.', style: T.footnote.copyWith(color: Colors.white.withValues(alpha: .85))),
              ]),
            ),
            const Icon(CupertinoIcons.chevron_forward, color: Colors.white70, size: 18),
          ]),
        ),
        const SizedBox(height: 12),
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('False alarms per patient per day', style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            StudyChart(result: _study),
            const SizedBox(height: 8),
            Wrap(spacing: 12, children: [_Legend(color: c.gray, label: 'Fixed threshold'), _Legend(color: c.blue, label: 'Personal normal only'), _Legend(color: c.green, label: 'AdaptAlert')]),
            const SizedBox(height: 12),
            _StudyTable(r: _study),
            const SizedBox(height: 10),
            Text(
              '${_study.patients} virtual patients over ${_study.days} days, ${_study.realEvents} real events. In week 5 AdaptAlert sent ${(100 * (1 - _study.metrics['C']!.falsePerDayWeek5 / _study.metrics['A']!.falsePerDayWeek5)).round()}% fewer false alarms than the fixed-threshold monitor and caught ${pct(_study.metrics['C']!.sensitivity)} of real events. Simulated data, using the same decision code as the live app.',
              style: T.footnote.copyWith(color: c.label2),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.tinted(
                sizeStyle: CupertinoButtonSize.medium,
                onPressed: () => setState(() {
                  _seed = Random().nextInt(1 << 20);
                  _study = runStudy(seed: _seed);
                }),
                child: const Text('Run again with new patients'),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.round = false, this.hollow = false});
  final Color color;
  final String label;
  final bool round, hollow;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: hollow ? null : color,
            border: hollow ? Border.all(color: color, width: 2) : null,
            borderRadius: BorderRadius.circular(round ? 5 : 3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: T.caption.copyWith(color: context.ios.label2)),
      ]);
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: c.card2, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: T.caption.copyWith(color: c.label2)),
          Text(value, style: T.title3.copyWith(color: c.label, fontFeatures: T.num)),
        ]),
      ),
    );
  }
}

class PipelineList extends StatelessWidget {
  const PipelineList({super.key, required this.pipe});
  final Map<String, Stage> pipe;
  static const names = {'A': 'Signal quality', 'B': 'Activity', 'C': 'Personal normal', 'D': 'Safety floor', 'E': 'Anomaly check', 'F': 'Decision', 'G': 'Explanation'};
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return GroupedList(children: [
      for (final k in names.keys)
        Builder(builder: (context) {
          final s = pipe[k] ?? const Stage(StageState.idle, '—');
          final (bg, fg) = switch (s.state) {
            StageState.ok => (c.green.withValues(alpha: .18), c.green),
            StageState.watch || StageState.warn => (c.orange.withValues(alpha: .2), c.orange),
            StageState.send => (c.red, Colors.white),
            StageState.crit => (c.red, Colors.white),
            StageState.hold => (c.indigo.withValues(alpha: .2), c.indigo),
            StageState.bad => (c.gray, Colors.white),
            StageState.idle => (c.fill, c.label2),
          };
          return IOSRow(
            leading: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
              child: Text(k, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            ),
            title: names[k]!,
            subtitle: s.text,
            chevron: false,
          );
        }),
    ]);
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.k, required this.engine});
  final String k;
  final AdaptAlertEngine engine;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final b = engine.buckets[k]!;
    final p = engine.bucketP(k);
    final send = p >= engine.tau;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(bucketLabel(k), style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w500))),
          Text('${b.r.toStringAsFixed(1)} real · ${b.f.toStringAsFixed(1)} false', style: T.caption.copyWith(color: c.label2)),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (_, box) => Stack(children: [
            Container(height: 8, decoration: BoxDecoration(color: c.fill2, borderRadius: BorderRadius.circular(4))),
            AnimatedContainer(duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic, width: box.maxWidth * p, height: 8, decoration: BoxDecoration(color: send ? c.red : c.indigo, borderRadius: BorderRadius.circular(4))),
            Positioned(left: box.maxWidth * engine.tau - 1, child: Container(width: 2, height: 8, color: c.label)),
          ]),
        ),
        const SizedBox(height: 6),
        Text.rich(TextSpan(style: T.caption.copyWith(color: c.label2), children: [
          TextSpan(text: 'Now ${pct(p)} likely real → '),
          TextSpan(text: send ? 'alerts' : 'held back', style: TextStyle(color: c.label, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _StudyTable extends StatelessWidget {
  const _StudyTable({required this.r});
  final StudyResult r;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    TextStyle h = T.caption.copyWith(color: c.label2, fontWeight: FontWeight.w600);
    Widget cell(String t, {bool bold = false, TextAlign align = TextAlign.right}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(t, textAlign: align, style: T.footnote.copyWith(color: c.label, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontFeatures: T.num)),
        );
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.6)},
      border: TableBorder(horizontalInside: BorderSide(color: c.sep, width: .5)),
      children: [
        TableRow(children: [
          Text('System', style: h),
          Text('False/day\nweek 1', style: h, textAlign: TextAlign.right),
          Text('False/day\nweek 5', style: h, textAlign: TextAlign.right),
          Text('Caught', style: h, textAlign: TextAlign.right),
          Text('Real when\nalerted', style: h, textAlign: TextAlign.right),
        ]),
        for (final (k, name, col) in [('A', 'Fixed', c.gray), ('B', 'Personal', c.blue), ('C', 'AdaptAlert', c.green)])
          TableRow(children: [
            Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)), const SizedBox(width: 6), Flexible(child: cell(name, bold: k == 'C', align: TextAlign.left))]),
            cell(r.metrics[k]!.falsePerDayWeek1.toStringAsFixed(2), bold: k == 'C'),
            cell(r.metrics[k]!.falsePerDayWeek5.toStringAsFixed(2), bold: k == 'C'),
            cell(pct(r.metrics[k]!.sensitivity), bold: k == 'C'),
            cell(pct(r.metrics[k]!.ppv), bold: k == 'C'),
          ]),
      ],
    );
  }
}
