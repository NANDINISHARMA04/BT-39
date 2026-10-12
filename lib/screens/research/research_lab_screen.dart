import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/adapt_alert.dart';
import '../../engine/study.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';

/// Reproducible experiments behind AdaptAlert, for the project report and paper.
class ResearchLabScreen extends StatefulWidget {
  const ResearchLabScreen({super.key});
  @override
  State<ResearchLabScreen> createState() => _ResearchLabScreenState();
}

class _ResearchLabScreenState extends State<ResearchLabScreen> {
  StudyConfig _cfg = const StudyConfig();
  ExperimentResult? _r;
  List<NoisePoint>? _noise;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _set(StudyConfig c) => setState(() => _cfg = c);

  Future<void> _run() async {
    setState(() => _running = true);
    // Let the spinner paint before the (synchronous) simulation runs.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final r = runExperiment(_cfg);
    final noise = noiseSweep(_cfg.copyWith(patients: (_cfg.patients * .6).round().clamp(10, 60)), seeds: 3);
    if (!mounted) return;
    setState(() {
      _r = r;
      _noise = noise;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final r = _r;
    return LargeTitlePage(
      title: 'Research Lab',
      previousTitle: 'Back',
      subtitle: 'Reproducible experiments behind AdaptAlert',
      children: [
        const _Contributions(),
        const SectionHeader('Experiment setup'),
        IOSCard(
          child: Column(children: [
            _Slider('Virtual patients', '${_cfg.patients}', _cfg.patients.toDouble(), 10, 100, 9, (v) => _set(_cfg.copyWith(patients: v.round()))),
            _Slider('Days followed', '${_cfg.days}', _cfg.days.toDouble(), 14, 60, 46, (v) => _set(_cfg.copyWith(days: v.round()))),
            _Slider('Alerts a clinician labels', pct(_cfg.labelRate), _cfg.labelRate, .3, 1, 14, (v) => _set(_cfg.copyWith(labelRate: v))),
            _Slider('Wrong labels (random)', pct(_cfg.labelNoise), _cfg.labelNoise, 0, .3, 6, (v) => _set(_cfg.copyWith(labelNoise: v))),
            _Slider('Real alerts dismissed (alarm fatigue)', pct(_cfg.dismissRate), _cfg.dismissRate, 0, .5, 10, (v) => _set(_cfg.copyWith(dismissRate: v))),
            _Slider('Personal weight k  (w = n / (n + k))', _cfg.k.toStringAsFixed(0), _cfg.k, 1, 10, 9, (v) => _set(_cfg.copyWith(k: v.roundToDouble()))),
            const SizedBox(height: 6),
            Row(children: [
              Text('Seed ${_cfg.seed}', style: T.footnote.copyWith(color: c.label2, fontFeatures: T.num)),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _running ? null : () => setState(() => _cfg = _cfg.copyWith(seed: DateTime.now().millisecondsSinceEpoch % 100000)),
                child: const Text('New seed'),
              ),
              const SizedBox(width: 16),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _running ? null : () => setState(() => _cfg = const StudyConfig()),
                child: const Text('Defaults'),
              ),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _running ? null : _run,
                child: _running ? const CupertinoActivityIndicator(color: Colors.white) : const Text('Run experiment'),
              ),
            ),
          ]),
        ),
        if (r != null) ...[
          const SectionHeader('Headline results'),
          AnimatedOpacity(
            opacity: _running ? .4 : 1,
            duration: const Duration(milliseconds: 250),
            child: Column(children: [
              Row(children: [
                _Kpi(pct(r.reduction('C')), 'fewer false alarms than fixed thresholds (last week)', c.green),
                const SizedBox(width: 10),
                _Kpi(pct(r.metrics['C']!.sensitivity), 'of real events caught by AdaptAlert', c.blue),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _Kpi('${(r.metrics['C']!.ppv / r.metrics['A']!.ppv).toStringAsFixed(0)}×', 'more alerts are real (PPV ${pct(r.metrics['C']!.ppv)} vs ${pct(r.metrics['A']!.ppv)})', c.indigo),
                const SizedBox(width: 10),
                _Kpi(
                  r.metrics['C']!.falsePerDayWeek1 == 0 ? '—' : pct(1 - r.metrics['E']!.falsePerDayWeek1 / r.metrics['C']!.falsePerDayWeek1),
                  'fewer week-1 false alarms with the federated prior (cold start)',
                  c.purple,
                ),
              ]),
            ]),
          ),
          const SectionHeader('Learning curves', trailing: 'false alarms per patient per day'),
          IOSCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              StudyChart(result: r, systems: const ['A', 'B', 'C', 'D', 'E']),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 6, children: [
                for (final s in systemNames.keys)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: systemColor(context, s), borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 5),
                    Text(systemNames[s]!, style: T.caption.copyWith(color: c.label2)),
                  ]),
              ]),
            ]),
          ),
          const SectionHeader('All systems', trailing: '95% bootstrap CI'),
          IOSCard(padding: const EdgeInsets.all(12), child: _ResultsTable(r: r)),
          if (_noise != null) ...[
            const SectionHeader('Alarm fatigue', trailing: 'mean of 3 seeds'),
            IOSCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('What if patients dismiss real alerts as false alarms?', style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('X axis: share of real alerts dismissed. Solid lines: all real events caught. Dashed: critical events caught.', style: T.caption.copyWith(color: c.label2)),
                const SizedBox(height: 12),
                FatigueChart(points: _noise!),
                const SizedBox(height: 8),
                Wrap(spacing: 12, children: [
                  _Dot(c.green, 'AdaptAlert (guarded)'),
                  _Dot(c.orange, 'Unguarded learning'),
                ]),
                const SizedBox(height: 10),
                Text(
                  'At ${pct(_noise!.last.noise)} dismissal, AdaptAlert still caught ${pct(_noise!.last.critC)} of critical events and ${pct(_noise!.last.sensC)} of all real events. Dismissals cost sensitivity on milder events; this trade-off is reported as a limitation.',
                  style: T.footnote.copyWith(color: c.label),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          CupertinoButton.tinted(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: resultsMarkdown(r, noise: _noise)));
              if (context.mounted) toast(context, 'Results copied', 'Paste the Markdown tables into your report or paper.');
            },
            child: const Text('Copy results as Markdown'),
          ),
          const SectionHeader('Assumptions'),
          IOSCard(
            child: Text(
              'Each virtual patient has, per day: about 2 exercise episodes, 1.5 loose-sensor episodes, 1.2 coffee/stress heart-rate rises, a 50% chance of a mild oxygen dip during sleep, and a ${pct(_cfg.realEventRate)} chance of a real deterioration '
              '(30% heart rate with falling oxygen, 25% fever, 20% critical oxygen drop, 25% subtle oxygen fall). Clinicians label a share of sent alerts. Systems see identical events. '
              'These rates are modelling assumptions, not clinical data; validate on real recordings (for example PhysioNet) before drawing clinical conclusions.',
              style: T.footnote.copyWith(color: c.label2, height: 1.45),
            ),
          ),
        ],
      ],
    );
  }
}

class _Contributions extends StatelessWidget {
  const _Contributions();
  static const items = [
    ('Personal, feedback-driven alerting', 'Each patient\'s alert threshold and pattern estimates learn from patient context answers and clinician labels.'),
    ('Explanation for every alert', 'Plain-language reasons, the decision path, a counterfactual ("no alert below 84 bpm") and a confidence interval.'),
    ('Guarded learning', 'A safety floor the model can\'t override, τ limited to 30–75% and at most 10 points a week.'),
    ('Quality-aware input', 'Unreliable sensor windows never alert and never change the personal normal.'),
    ('Federated cold start', 'New patients start from pattern statistics pooled across patients; only label counts are shared.'),
  ];
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return IOSCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What this project adds', style: T.headline.copyWith(color: c.label)),
        const SizedBox(height: 10),
        for (final (i, (t, d)) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.indigo.withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
                child: Text('C${i + 1}', style: T.caption.copyWith(color: c.indigo, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w600)),
                  Text(d, style: T.footnote.copyWith(color: c.label2)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider(this.label, this.value, this.v, this.min, this.max, this.divisions, this.onChanged);
  final String label, value;
  final double v, min, max;
  final int divisions;
  final void Function(double) onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: T.footnote.copyWith(color: c.label))),
        Text(value, style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600, fontFeatures: T.num)),
      ]),
      SizedBox(
        width: double.infinity,
        child: CupertinoSlider(value: v.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
      ),
    ]);
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.value, this.label, this.color);
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: T.title1.copyWith(color: color, fontFeatures: T.num)),
          const SizedBox(height: 4),
          Text(label, style: T.caption.copyWith(color: c.label2)),
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: T.caption.copyWith(color: context.ios.label2)),
      ]);
}

class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.r});
  final ExperimentResult r;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final h = T.caption.copyWith(color: c.label2, fontWeight: FontWeight.w600);
    String f2(double x) => x.toStringAsFixed(2);
    Widget cell(String t, {bool bold = false, TextAlign align = TextAlign.right}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(t, textAlign: align, style: T.caption.copyWith(color: c.label, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontFeatures: T.num)),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 560),
        child: Table(
          columnWidths: const {0: FixedColumnWidth(170)},
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(horizontalInside: BorderSide(color: c.sep, width: .5)),
          children: [
            TableRow(children: [
              Padding(padding: const EdgeInsets.all(4), child: Text('System', style: h)),
              for (final t in ['False/day wk 1', 'False/day last wk', 'Sensitivity', 'Critical', 'PPV']) Padding(padding: const EdgeInsets.all(4), child: Text(t, style: h, textAlign: TextAlign.right)),
            ]),
            for (final s in systemNames.keys)
              TableRow(children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: systemColor(context, s), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Flexible(child: cell(systemNames[s]!, bold: s == 'C', align: TextAlign.left)),
                ]),
                cell(f2(r.metrics[s]!.falsePerDayWeek1), bold: s == 'C'),
                cell('${f2(r.metrics[s]!.falsePerDayLastWeek)}\n(${f2(r.metrics[s]!.falseLastWeekCI.lo)}–${f2(r.metrics[s]!.falseLastWeekCI.hi)})', bold: s == 'C'),
                cell('${pct(r.metrics[s]!.sensitivity)}\n(${pct(r.metrics[s]!.sensitivityCI.lo)}–${pct(r.metrics[s]!.sensitivityCI.hi)})', bold: s == 'C'),
                cell(pct(r.metrics[s]!.criticalCaught), bold: s == 'C'),
                cell(pct(r.metrics[s]!.ppv), bold: s == 'C'),
              ]),
          ],
        ),
      ),
    );
  }
}
