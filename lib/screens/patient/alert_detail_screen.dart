import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/adapt_alert.dart';
import '../../l10n/l10n.dart';
import '../../services/monitor.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/vitals.dart';
import 'alerts_screen.dart';
import 'patient_shell.dart';

/// Opens the full explanation of one alert. Works from the patient app and the
/// staff app, so it carries the monitor along to the new page.
void openAlertDetail(BuildContext context, HealthAlert a, {bool staffMode = false, String reviewer = 'Dr. Kavya Rao'}) {
  final m = context.read<MonitorController>();
  Navigator.of(context).push(CupertinoPageRoute(
    builder: (_) => ChangeNotifierProvider.value(value: m, child: AlertDetailScreen(alert: a, staffMode: staffMode, reviewer: reviewer)),
  ));
}

const _unit = {'hr': 'bpm', 'spo2': '%', 'temp': '°C'};
// English names, shown through tr().
const _label = {'hr': 'Heart rate', 'spo2': 'Oxygen', 'temp': 'Temperature'};

/// The heart of the project on one page: what the band saw, which signals
/// drove the alert, how the model and the person's history were combined,
/// and what would have changed the decision.
class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key, required this.alert, this.staffMode = false, this.reviewer = 'Dr. Kavya Rao'});
  final HealthAlert alert;
  final bool staffMode;
  final String reviewer;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final m = context.watch<MonitorController>();
    final e = m.engine;
    final a = alert;
    final rec = e.history.where((h) => h.t == a.t).firstOrNull;
    final col = levelColor(context, a.level);
    final primary = _primaryVital(a, rec);
    final window = e.history.where((h) => h.t >= a.t - 30 && h.t <= a.t + 15).toList();

    return PlainPage(
      title: tr('Why this alert'),
      previousTitle: tr('Alerts'),
      children: [
        FadeIn(child: _Header(a: a, color: col)),
        if (window.length > 3) ...[
          SectionHeader(tr('What the band saw'), trailing: '${tr(_label[primary]!)} · ${_unit[primary]}'),
          FadeIn(
            delay: 60,
            child: IOSCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TrendChart(history: window, vital: primary, color: col),
                const SizedBox(height: 6),
                Text(tr('Shaded: this person\'s normal range for the activity at the time. Red dot: the minute the alert was sent.'), style: T.caption.copyWith(color: c.label2)),
              ]),
            ),
          ),
        ],
        if (rec != null) ...[
          SectionHeader(tr('Which signals drove it')),
          FadeIn(delay: 100, child: _Contributions(rec: rec)),
        ],
        SectionHeader(tr('How AdaptAlert decided')),
        FadeIn(delay: 140, child: _Decision(a: a, engine: e)),
        SectionHeader(tr('What would have changed it')),
        FadeIn(delay: 180, child: _Counterfactual(a: a, rec: rec, engine: e, primary: primary)),
        SectionHeader(tr('Who was told')),
        FadeIn(delay: 220, child: _Timeline(a: a)),
        SectionHeader(staffMode ? tr('Your review') : tr('Your answer')),
        IOSCard(child: AlertActions(a: a, staffMode: staffMode, reviewer: reviewer)),
        const SizedBox(height: 12),
        Text(tr('Explanations are generated from the same numbers the engine used. Research prototype, not a diagnosis.'), textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
      ],
    );
  }
}

String _primaryVital(HealthAlert a, WindowRecord? rec) {
  final parts = a.key.split('|');
  if (parts.first == 'SAFETY') return parts[1];
  if (parts[1] != 'multi') return parts[1];
  if (rec == null) return 'hr';
  final dev = {'hr': rec.z['hr']!, 'spo2': -rec.z['spo2']!, 'temp': rec.z['temp']!};
  return dev.entries.reduce((x, y) => x.value >= y.value ? x : y).key;
}

class _Header extends StatelessWidget {
  const _Header({required this.a, required this.color});
  final HealthAlert a;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return AccentCard(
      color: color,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a.levelLabel.toUpperCase()} · ${hhmm(a.t)}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .6)),
            const SizedBox(height: 6),
            Text(a.title, style: T.title2.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(a.reasons.first, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
          ]),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 86,
          height: 86,
          child: Stack(alignment: Alignment.center, children: [
            Ring(value: a.p, color: Colors.white, size: 86, stroke: 9),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(pct(a.p), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, fontFeatures: T.num)),
              Text(tr('likely real'), style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// How far each vital was from this person's normal, in standard deviations.
class _Contributions extends StatelessWidget {
  const _Contributions({required this.rec});
  final WindowRecord rec;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final dev = {'hr': rec.z['hr']!, 'spo2': -rec.z['spo2']!, 'temp': rec.z['temp']!};
    final top = max(4.0, dev.values.reduce(max));
    final colors = {'hr': c.pink, 'spo2': c.blue, 'temp': c.orange};
    String value(String v) => v == 'temp' ? rec.r.temp.toStringAsFixed(1) : '${v == 'hr' ? rec.r.hr : rec.r.spo2}';
    String usual(String v) => v == 'temp' ? rec.mu[v]!.toStringAsFixed(1) : '${rec.mu[v]!.round()}';
    return IOSCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final v in ['hr', 'spo2', 'temp'])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(tr(_label[v]!), style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(tr('{value} {unit} · usual {usual}', {'value': value(v), 'unit': _unit[v], 'usual': usual(v)}), style: T.caption.copyWith(color: c.label2, fontFeatures: T.num)),
              ]),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (_, box) => Stack(children: [
                  ProgressBar(value: (dev[v]! / top).clamp(0, 1), height: 10, color: dev[v]! >= 1.5 ? colors[v] : c.gray),
                  // The point where a vital starts counting as abnormal (2.5 SD).
                  Positioned(left: box.maxWidth * (2.5 / top) - 1, child: Container(width: 2, height: 10, color: c.label)),
                ]),
              ),
              const SizedBox(height: 4),
              Text(
                dev[v]! < .5
                    ? tr('Normal for you')
                    : '${v == 'spo2' ? tr('{sd} SD below your normal', {'sd': dev[v]!.toStringAsFixed(1)}) : tr('{sd} SD above your normal', {'sd': dev[v]!.toStringAsFixed(1)})}${dev[v]! >= 2.5 ? ' · ${tr('counted as abnormal')}' : ''}',
                style: T.caption.copyWith(color: dev[v]! >= 2.5 ? colors[v] : c.label2, fontWeight: dev[v]! >= 2.5 ? FontWeight.w600 : FontWeight.w400),
              ),
            ]),
          ),
        Text(tr('The black tick marks 2.5 SD, where a reading starts counting as abnormal for this person. Signal quality was {q}, activity: {act}.', {'q': rec.sqi.toStringAsFixed(2), 'act': tr(rec.act).toLowerCase()}), style: T.caption.copyWith(color: c.label2)),
      ]),
    );
  }
}

/// The decision rule with this alert's numbers filled in.
class _Decision extends StatelessWidget {
  const _Decision({required this.a, required this.engine});
  final HealthAlert a;
  final AdaptAlertEngine engine;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    if (a.safety) {
      return IOSCard(
        color: c.tint(c.red),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(CupertinoIcons.shield_lefthalf_fill, color: c.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${a.path.first}. ${tr('The safety floor sends this alert without asking the model. No amount of feedback can switch it off, so learning can never hide a critical reading.')}',
              style: T.sub.copyWith(color: c.label, height: 1.4),
            ),
          ),
        ]),
      );
    }
    // The 90% interval of the personal estimate, worked out by the service from this alert's own numbers.
    final ci = a.explain?.ci ?? (lo: 0.0, hi: 1.0);
    Widget box(String title, String value, String sub, Color col) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.tint(col), borderRadius: BorderRadius.circular(R.sm)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.caption.copyWith(color: c.label2)),
              Text(value, style: T.title2.copyWith(color: col, fontFeatures: T.num)),
              Text(sub, style: T.caption.copyWith(color: c.label2)),
            ]),
          ),
        );
    return IOSCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          box(tr('General model'), pct(a.pg), a.path.last, c.blue),
          const SizedBox(width: 8),
          box(tr('Your history'), a.n == 0 ? '—' : pct(a.pu), a.n == 0 ? tr('No labels for this pattern yet') : tr('{n} labels · 90% CI {lo}–{hi}', {'n': a.n.toStringAsFixed(1), 'lo': pct(ci.lo), 'hi': pct(ci.hi)}), c.purple),
        ]),
        const SizedBox(height: 12),
        Text(tr('Blend'), style: T.caption.copyWith(color: c.label2)),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(style: T.sub.copyWith(color: c.label, fontFeatures: T.num), children: [
            const TextSpan(text: 'P(real) = '),
            TextSpan(text: '${(1 - a.w).toStringAsFixed(2)} × ${pct(a.pg)}', style: TextStyle(color: c.blue, fontWeight: FontWeight.w700)),
            const TextSpan(text: '  +  '),
            TextSpan(text: '${a.w.toStringAsFixed(2)} × ${pct(a.pu)}', style: TextStyle(color: c.purple, fontWeight: FontWeight.w700)),
            const TextSpan(text: '  =  '),
            TextSpan(text: pct(a.p), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 4),
        Text(tr('Your history counts for w = n / (n + 4) = {w}. The more answers for this pattern, the more it counts.', {'w': pct(a.w)}), style: T.caption.copyWith(color: c.label2)),
        const SizedBox(height: 14),
        Row(children: [
          Text(tr('Likely real'), style: T.caption.copyWith(color: c.label2)),
          const Spacer(),
          Text(tr('{p} ≥ τ {tau} → sent', {'p': pct(a.p), 'tau': pct(a.tau)}), style: T.caption.copyWith(color: c.label, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        ProbabilityBar(p: a.p, tau: a.tau, color: c.green),
        const SizedBox(height: 10),
        Text(tr('τ is this person\'s alert threshold. It is learned from feedback, kept between 30% and 75%, and moves at most 10 points a week. Today it is {tau}.', {'tau': pct(engine.tau)}), style: T.caption.copyWith(color: c.label2)),
      ]),
    );
  }
}

/// Counterfactuals: the smallest change that would have meant no alert, and
/// what the next similar pattern would score after each kind of feedback.
class _Counterfactual extends StatelessWidget {
  const _Counterfactual({required this.a, required this.rec, required this.engine, required this.primary});
  final HealthAlert a;
  final WindowRecord? rec;
  final AdaptAlertEngine engine;
  final String primary;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final lines = <(IconData, Color, String)>[];
    final r = rec;
    if (a.safety) {
      lines.add((CupertinoIcons.lock_fill, c.red, tr('Nothing. A safety-floor reading always alerts.')));
    } else {
      if (r != null) {
        final mu = r.mu[primary]!, sd = r.sd[primary]!;
        final limit = primary == 'spo2' ? mu - 2.5 * sd : mu + 2.5 * sd;
        final shown = primary == 'temp' ? limit.toStringAsFixed(1) : '${limit.round()}';
        final args = {'vital': tr(_label[primary]!).toLowerCase(), 'limit': shown, 'unit': _unit[primary], 'mu': primary == 'temp' ? mu.toStringAsFixed(1) : mu.round()};
        lines.add((
          CupertinoIcons.arrow_turn_down_right,
          c.blue,
          primary == 'spo2'
              ? tr('No alert if {vital} had stayed above {limit} {unit} (2.5 SD from this person\'s usual {mu}).', args)
              : tr('No alert if {vital} had stayed below {limit} {unit} (2.5 SD from this person\'s usual {mu}).', args),
        ));
      }
      final parts = a.key.split('|');
      final ex = a.explain;
      final singleP = ex?.singleP;
      if (parts[1] == 'multi' && r != null && singleP != null) {
        lines.add((CupertinoIcons.square_stack_3d_up, c.purple, tr('If only {vital} had changed, the model would rate it {p} instead of {pg}. Two vitals moving together is what made it more serious.', {'vital': tr(_label[primary]!).toLowerCase(), 'p': pct(singleP), 'pg': pct(a.pg)})));
      }
      if (parts[0] != 'rest') {
        lines.add((CupertinoIcons.person_crop_circle_badge_checkmark, c.green, tr('The movement sensor showed activity, so a higher heart rate was expected and weighed less.')));
      }
      // What the next similar pattern would score after each kind of feedback, as the service works it out from what
      // it has learned so far (it sends these again whenever the learning changes).
      if (ex != null) {
        lines.add((CupertinoIcons.xmark_circle, c.green, ex.ifFalseSends
                ? tr('If a clinician marks it a false alarm, the next similar pattern scores {p} against τ {tau}: still sent.', {'p': pct(ex.ifFalse), 'tau': pct(ex.tauFalse)})
                : tr('If a clinician marks it a false alarm, the next similar pattern scores {p} against τ {tau}: held back.', {'p': pct(ex.ifFalse), 'tau': pct(ex.tauFalse)})));
        lines.add((CupertinoIcons.checkmark_circle, c.red, tr('If it is confirmed real, the next one scores {p} against τ {tau}: sent, and sooner.', {'p': pct(ex.ifReal), 'tau': pct(ex.tauReal)})));
      }
    }
    return IOSCard(
      child: Column(children: [
        for (final (i, (icon, col, text)) in lines.indexed) ...[
          if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Hairline()),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: col, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: T.sub.copyWith(color: c.label, height: 1.4))),
          ]),
        ],
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.a});
  final HealthAlert a;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final steps = [
      ...a.escalation.map((s) => (hhmm(s.t), s.who, s.what)),
      if (a.patientFeedback != null) ('', 'Patient', tr(AlertCard.fbText[a.patientFeedback]!.replaceFirst('You said', 'Said'))),
      if (a.doctor != DoctorLabel.pending) ('', a.reviewedBy ?? 'Doctor', a.doctor == DoctorLabel.confirmed ? tr('Confirmed real') : tr('Marked a false alarm')),
    ];
    final colors = {'You': c.teal, 'Caregiver': c.orange, 'Doctor': c.blue, 'SOS': c.red, 'Patient': c.teal};
    return IOSCard(
      child: Column(children: [
        for (final (i, (t, who, what)) in steps.indexed)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 22,
                child: Column(children: [
                  Container(width: 12, height: 12, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: colors[who] ?? c.indigo, shape: BoxShape.circle)),
                  if (i < steps.length - 1) Expanded(child: Container(width: 2, color: c.sep)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(trData(who), style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w600)),
                    Text(what, style: T.footnote.copyWith(color: c.label2)),
                  ]),
                ),
              ),
              if (t.isNotEmpty) Text(t, style: T.caption.copyWith(color: c.label2, fontFeatures: T.num)),
            ]),
          ),
      ]),
    );
  }
}
