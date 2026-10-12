import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/adapt_alert.dart';
import '../../l10n/l10n.dart';
import '../../services/monitor.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import '../research/research_lab_screen.dart';
import 'insights_screen.dart';

/// The project's core idea at a glance: what a fixed-threshold monitor would
/// have done today against what AdaptAlert did.
class AdaptAlertHero extends StatelessWidget {
  const AdaptAlertHero({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final e = context.watch<MonitorController>().engine;
    final fixed = e.fixedCount, sent = e.sentCount, held = e.held.length;
    final top = max(1, max(fixed, sent));
    final cut = fixed == 0 ? 0 : ((1 - sent / fixed) * 100).round();
    Widget bar(String label, int v, Color col) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 108, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
            Expanded(
              child: LayoutBuilder(
                builder: (_, box) => Stack(children: [
                  Container(height: 22, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(7))),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: v / top),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, _) => Container(
                      width: max(22, box.maxWidth * t),
                      height: 22,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(7)),
                      child: Text('$v', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, fontFeatures: T.num)),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [c.indigo, c.purple], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: c.indigo.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('AdaptAlert', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.3)),
          const Spacer(),
          Text(tr('today'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
        const SizedBox(height: 4),
        Text(tr('Alerts that learn what matters for this person, and explain themselves.'), style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
        const SizedBox(height: 16),
        bar(tr('Fixed monitor'), fixed, Colors.white.withValues(alpha: .45)),
        bar(tr('AdaptAlert sent'), sent, c.green),
        bar(tr('Held back'), held, c.teal),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Chip(fixed == 0 ? tr('No fixed alarms yet') : tr('{cut}% fewer alarms', {'cut': cut})),
          _Chip(tr('{n} feedback answers', {'n': e.labels})),
          _Chip('τ ${pct(e.tau)}'),
          _Chip(tr('{n} learned patterns', {'n': e.buckets.length})),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            borderRadius: BorderRadius.circular(14),
            onPressed: () => Navigator.of(context).push(CupertinoPageRoute(
              builder: (_) => ChangeNotifierProvider.value(value: context.read<MonitorController>(), child: const HowItWorksScreen()),
            )),
            child: Text(tr('See how AdaptAlert works'), style: TextStyle(color: c.indigo, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: T.num)),
      );
}

/// The core idea explained, with the live pipeline underneath.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final m = context.watch<MonitorController>();
    final e = m.engine;
    return LargeTitlePage(
      title: tr('How it works'),
      previousTitle: tr('Alerts'),
      subtitle: tr('AdaptAlert, the core of this project'),
      children: [
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('The problem'), style: T.headline.copyWith(color: c.label)),
            const SizedBox(height: 6),
            Text(
              tr('Most monitors alarm on fixed numbers, like "heart rate above 100". They alarm when you climb stairs, drink coffee or the sensor slips. After enough false alarms, patients and nurses stop trusting them, and a real emergency can be missed. This is called alarm fatigue.'),
              style: T.sub.copyWith(color: c.label, height: 1.45),
            ),
            const SizedBox(height: 14),
            Text(tr('The idea'), style: T.headline.copyWith(color: c.label)),
            const SizedBox(height: 6),
            Text(
              tr('AdaptAlert learns each person\'s normal, checks whether the data can be trusted, explains every alert, and asks "what was happening?". Answers from the patient and the doctor teach it which patterns are harmless for this person, so it gets quieter without going blind.'),
              style: T.sub.copyWith(color: c.label, height: 1.45),
            ),
          ]),
        ),
        SectionHeader(tr('Every minute, seven stages'), trailing: tr('live')),
        PipelineList(pipe: e.pipe),
        SectionHeader(tr('The learning rule')),
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.card2, borderRadius: BorderRadius.circular(12)),
              child: Text('P(real) = (1 − w) · P_model + w · P_you\nw = n / (n + 4)\nalert if P(real) ≥ τ', style: T.sub.copyWith(color: c.label, fontFamily: 'monospace', height: 1.6, fontFamilyFallback: const ['Menlo', 'Courier'])),
            ),
            const SizedBox(height: 10),
            Text(
              tr('P_model comes from a small, readable decision tree. P_you comes from this person\'s answers for the same kind of event. With no answers yet, the model decides; as answers build up, the person\'s own history counts more. τ is their personal threshold, now {tau}.', {'tau': pct(e.tau)}),
              style: T.footnote.copyWith(color: c.label2, height: 1.45),
            ),
          ]),
        ),
        SectionHeader(tr('Three safeguards')),
        GroupedList(children: [
          IOSRow(icon: CupertinoIcons.shield_lefthalf_fill, iconColor: c.red, title: tr('Safety floor'), subtitle: tr('SpO₂ ≤ 91%, resting HR ≥ 131 or ≤ 40, temp ≥ 39.1 °C always alert. Learning can\'t touch them.'), chevron: false),
          IOSRow(icon: CupertinoIcons.slider_horizontal_3, iconColor: c.orange, title: tr('Bounded threshold'), subtitle: tr('τ stays between 30% and 75% and moves at most 10 points a week.'), chevron: false),
          IOSRow(icon: CupertinoIcons.hand_raised_fill, iconColor: c.teal, title: tr('One-way patient answers'), subtitle: tr('"I feel unwell" and "Not sure" can only make AdaptAlert more careful, never less.'), chevron: false),
        ]),
        SectionHeader(tr('What it has learned'), trailing: tr('from feedback')),
        IOSCard(
          padding: const EdgeInsets.all(14),
          child: e.buckets.isEmpty
              ? Text(tr('No feedback yet. Answer an alert to teach it.'), style: T.sub.copyWith(color: c.label2))
              : Column(children: [
                  for (final k in e.buckets.keys)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Icon(e.bucketP(k) >= e.tau ? CupertinoIcons.bell_fill : CupertinoIcons.bell_slash_fill, color: e.bucketP(k) >= e.tau ? c.red : c.indigo, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(bucketLabel(k), style: T.footnote.copyWith(color: c.label))),
                        Text('${pct(e.bucketP(k))} → ${tr(e.bucketP(k) >= e.tau ? 'alerts' : 'held')}', style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ]),
        ),
        const SizedBox(height: 16),
        CupertinoButton.tinted(
          onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ResearchLabScreen())),
          child: Text(tr('See the evidence in the Research Lab')),
        ),
      ],
    );
  }
}
