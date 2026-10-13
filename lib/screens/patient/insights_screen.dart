import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/adapt_alert.dart';
import '../../engine/study.dart';
import '../../l10n/l10n.dart';
import '../../services/monitor.dart';
import '../../services/pulse_api.dart';
import '../../services/session.dart';
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
    _loadStudy();
  }

  @override
  void dispose() {
    insightsVital.removeListener(_onVital);
    super.dispose();
  }

  void _onVital() => setState(() {});

  int _seed = 7;
  StudyResult? _study;
  String? _studyError;
  bool _studyLoading = false;

  /// The 30-day study runs on the BT39 service, with the same decision code as the live engine.
  Future<void> _loadStudy() async {
    _studyLoading = true;
    _studyError = null;
    try {
      final r = await runStudy(context.read<Session>().api, seed: _seed);
      if (mounted) setState(() => _study = r);
    } catch (e) {
      if (mounted) setState(() => _studyError = (e is ApiException ? e.message : null) ?? tr('The service could not be reached. It may be waking up. Try again in a minute.'));
    }
    if (mounted) setState(() => _studyLoading = false);
  }

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
      title: tr('Insights'),
      subtitle: tr('Health analytics and the AI behind your alerts'),
      children: [
        CupertinoSlidingSegmentedControl<String>(
          groupValue: _vital,
          children: {'hr': Text(tr('Heart rate')), 'spo2': Text(tr('Oxygen')), 'temp': Text(tr('Temperature'))},
          onValueChanged: (v) => insightsVital.value = v ?? 'hr',
        ),
        const SizedBox(height: 12),
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${tr('Last {h} hours', {'h': (e.history.length / 60).toStringAsFixed(1)})} · $unit', style: T.sub.copyWith(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TrendChart(history: e.history, vital: _vital, color: color),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 6, children: [
              _Legend(color: c.blue.withValues(alpha: .25), label: tr('Your normal (±2 SD)')),
              _Legend(color: c.fill2, label: tr('Unreliable data')),
              _Legend(color: c.red, label: tr('Alert'), round: true),
              _Legend(color: c.indigo, label: tr('Held back'), round: true, hollow: true),
            ]),
            const SizedBox(height: 12),
            if (vals.isNotEmpty)
              Row(children: [
                _MiniStat(tr('Low'), vals.reduce(min).toStringAsFixed(dec)),
                const SizedBox(width: 8),
                _MiniStat(tr('Average'), (vals.reduce((a, b) => a + b) / vals.length).toStringAsFixed(dec)),
                const SizedBox(width: 8),
                _MiniStat(tr('High'), vals.reduce(max).toStringAsFixed(dec)),
              ]),
          ]),
        ),
        SectionHeader(tr('Your personal normal'), trailing: tr('learned, not fixed')),
        GroupedList(
          footer: tr('Updated slowly from good-quality readings only. Readings during an alert never count, so a problem can\'t become your new normal.'),
          children: [
            for (final (k, name, col, icon) in [
              ('rest', tr('Resting'), c.green, CupertinoIcons.bed_double_fill),
              ('light', tr('Light activity'), c.teal, CupertinoIcons.person_fill),
              ('active', tr('Active'), c.blue, CupertinoIcons.flame_fill),
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
        SectionHeader(tr('Alert load today'), trailing: tr('per hour')),
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AlertLoadChart(history: e.history),
            const SizedBox(height: 8),
            Wrap(spacing: 12, children: [_Legend(color: c.gray, label: tr('Fixed-threshold alarms')), _Legend(color: c.green, label: tr('AdaptAlert alerts'))]),
          ]),
        ),
        SectionHeader(tr('AI engine, live'), trailing: tr('every minute')),
        PipelineList(pipe: e.pipe),
        SectionHeader(tr('Your sensitivity')),
        IOSCard(
          child: Column(children: [
            Row(children: [
              TauGauge(tau: e.tau, min: tauMin, max: tauMax),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Alert threshold τ'), style: T.footnote.copyWith(color: c.label2)),
                  AnimatedNumber(e.tau * 100, style: T.title1.copyWith(color: c.label)),
                  const SizedBox(height: 6),
                  Text(tr('Feedback answers'), style: T.footnote.copyWith(color: c.label2)),
                  Text('${e.labels}', style: T.title2.copyWith(color: c.label, fontFeatures: T.num)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Text(tr('An alert is sent when the AI is at least τ sure it is real. τ stays between 30% and 75% (shaded) and moves at most 10 points a week. Safety-floor alerts ignore τ.'), style: T.footnote.copyWith(color: c.label2)),
          ]),
        ),
        SectionHeader(tr('What it has learned'), trailing: e.buckets.isEmpty ? null : e.buckets.length == 1 ? tr('1 pattern') : tr('{n} patterns', {'n': e.buckets.length})),
        IOSCard(
          padding: EdgeInsets.zero,
          child: e.buckets.isEmpty
              ? Padding(padding: const EdgeInsets.all(16), child: Text(tr('No feedback yet. Answer an alert to teach AdaptAlert.'), style: T.sub.copyWith(color: c.label2)))
              : Column(children: [
                  for (final (i, k) in e.buckets.keys.indexed) ...[
                    if (i > 0) const Hairline(indent: 14),
                    _BucketRow(k: k, engine: e),
                  ],
                ]),
        ),
        SectionHeader(tr('30-day study'), trailing: tr('simulated')),
        IOSCard(
          padding: EdgeInsets.zero,
          child: IOSRow(
            icon: CupertinoIcons.lab_flask_solid,
            iconColor: c.indigo,
            title: tr('Open the Research Lab'),
            subtitle: tr('Run your own experiments: 5 systems, ablation, alarm fatigue, federated cold start, 95% CIs.'),
            onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ResearchLabScreen())),
          ),
        ),
        const SizedBox(height: 12),
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('False alarms per patient per day'), style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_study case final study?) ...[
              StudyChart(result: study),
              const SizedBox(height: 8),
              Wrap(spacing: 12, children: [_Legend(color: c.gray, label: tr('Fixed threshold')), _Legend(color: c.blue, label: tr('Personal normal only')), _Legend(color: c.green, label: 'AdaptAlert')]),
              const SizedBox(height: 12),
              _StudyTable(r: study),
              const SizedBox(height: 10),
              Text(
                tr('{patients} virtual patients over {days} days, {events} real events. In week 5 AdaptAlert sent {cut}% fewer false alarms than the fixed-threshold monitor and caught {caught} of real events. Simulated data, using the same decision code as the live app.', {
                  'patients': study.patients,
                  'days': study.days,
                  'events': study.realEvents,
                  'cut': (100 * (1 - study.metrics['C']!.falsePerDayWeek5 / study.metrics['A']!.falsePerDayWeek5)).round(),
                  'caught': pct(study.metrics['C']!.sensitivity),
                }),
                style: T.footnote.copyWith(color: c.label2),
              ),
            ] else if (_studyError != null)
              Text(_studyError!, style: T.footnote.copyWith(color: c.red))
            else
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CupertinoActivityIndicator())),
            const SizedBox(height: 12),
            AppButton(
              tr('Run again with new patients'),
              kind: ButtonKind.tinted,
              size: ButtonSize.medium,
              expand: true,
              busy: _studyLoading && _study != null,
              onTap: _studyLoading
                  ? null
                  : () {
                      setState(() => _seed = Random().nextInt(1 << 20));
                      _loadStudy();
                    },
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
        decoration: BoxDecoration(color: c.card2, borderRadius: BorderRadius.circular(R.sm)),
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
            StageState.ok => (c.tint(c.green), c.green),
            StageState.watch || StageState.warn => (c.tint(c.orange), c.orange),
            StageState.send => (c.red, Colors.white),
            StageState.crit => (c.red, Colors.white),
            StageState.hold => (c.tint(c.indigo), c.indigo),
            StageState.bad => (c.gray, Colors.white),
            StageState.idle => (c.fill, c.label2),
          };
          return IOSRow(
            leading: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
              child: Text(k, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            ),
            title: tr(names[k]!),
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
    final send = b.send; // the service's decision for this pattern at today's threshold
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(bucketLabel(k), style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w500))),
          Text(tr('{r} real · {f} false', {'r': b.r.toStringAsFixed(1), 'f': b.f.toStringAsFixed(1)}), style: T.caption.copyWith(color: c.label2)),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (_, box) => Stack(children: [
            ProgressBar(value: p, height: 8, color: send ? c.red : c.indigo),
            Positioned(left: box.maxWidth * engine.tau - 1, child: Container(width: 2, height: 8, color: c.label)),
          ]),
        ),
        const SizedBox(height: 6),
        Text.rich(TextSpan(style: T.caption.copyWith(color: c.label2), children: [
          TextSpan(text: tr('Now {pct} likely real → ', {'pct': pct(p)})),
          TextSpan(text: tr(send ? 'alerts' : 'held back'), style: TextStyle(color: c.label, fontWeight: FontWeight.w700)),
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
          Text(tr('System'), style: h),
          Text(tr('False/day\nweek 1'), style: h, textAlign: TextAlign.right),
          Text(tr('False/day\nweek 5'), style: h, textAlign: TextAlign.right),
          Text(tr('Caught'), style: h, textAlign: TextAlign.right),
          Text(tr('Real when\nalerted'), style: h, textAlign: TextAlign.right),
        ]),
        for (final (k, name, col) in [('A', 'Fixed', c.gray), ('B', 'Personal', c.blue), ('C', 'AdaptAlert', c.green)])
          TableRow(children: [
            Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)), const SizedBox(width: 6), Flexible(child: cell(tr(name), bold: k == 'C', align: TextAlign.left))]),
            cell(r.metrics[k]!.falsePerDayWeek1.toStringAsFixed(2), bold: k == 'C'),
            cell(r.metrics[k]!.falsePerDayWeek5.toStringAsFixed(2), bold: k == 'C'),
            cell(pct(r.metrics[k]!.sensitivity), bold: k == 'C'),
            cell(pct(r.metrics[k]!.ppv), bold: k == 'C'),
          ]),
      ],
    );
  }
}
