import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../engine/adapt_alert.dart';
import '../../models/patient_models.dart';
import '../../services/monitor.dart';
import '../../services/patient_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import 'alert_detail_screen.dart';
import 'appointment_editor.dart';
import 'how_it_works_screen.dart';
import 'patient_shell.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'open';

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MonitorController>();
    final e = m.engine;
    final list = _filter == 'open' ? e.alerts.where((a) => a.patientFeedback == null).toList() : e.alerts;
    return LargeTitlePage(
      title: 'Alerts',
      subtitle: 'Explained, and learning from your answers',
      children: [
        const FadeIn(child: AdaptAlertHero()),
        const SizedBox(height: 14),
        CupertinoSlidingSegmentedControl<String>(
          groupValue: _filter,
          children: {
            'open': Text('Needs reply${m.needsReply > 0 ? ' (${m.needsReply})' : ''}'),
            'all': const Text('All'),
            'held': const Text('Held back'),
          },
          onValueChanged: (v) => setState(() => _filter = v ?? 'open'),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Column(
            key: ValueKey('$_filter-${list.length}-${e.held.length}'),
            children: _filter == 'held'
                ? (e.held.isEmpty
                    ? [const EmptyState(icon: CupertinoIcons.checkmark_circle, title: 'Nothing held back yet', message: 'When AdaptAlert learns a pattern is harmless for you, those alerts show up here instead of buzzing your phone.')]
                    : [for (final (i, h) in e.held.indexed) FadeIn(delay: i * 40, child: _HeldCard(h: h))])
                : (list.isEmpty
                    ? [
                        EmptyState(
                          icon: CupertinoIcons.checkmark_circle,
                          title: 'You\'re all caught up',
                          message: 'No alerts need your reply. Try “Heart racing at rest” or “Coffee or stress” from the simulator.',
                          action: 'Open simulator',
                          onAction: () => showSimulator(context),
                        ),
                      ]
                    : [for (final (i, a) in list.indexed) FadeIn(delay: i * 40, child: AlertCard(a: a))]),
          ),
        ),
      ],
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.a, this.staffMode = false, this.reviewer = 'Dr. Kavya Rao'});
  final HealthAlert a;

  /// Doctors and nurses see the patient's answer and review buttons instead of
  /// the patient's own feedback buttons.
  final bool staffMode;
  final String reviewer;

  static const feedbackOptions = [
    (PatientFeedback.active, '🏃', 'I was active'),
    (PatientFeedback.loose, '⌚', 'Sensor was loose'),
    (PatientFeedback.unwell, '🤒', 'I feel unwell'),
    (PatientFeedback.notSure, '❓', 'Not sure'),
  ];
  static const fbText = {
    PatientFeedback.active: 'You said you were active',
    PatientFeedback.loose: 'You said the sensor was loose',
    PatientFeedback.unwell: 'You said you feel unwell',
    PatientFeedback.notSure: 'You weren\'t sure',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final col = levelColor(context, a.level);
    final ai = a.safety
        ? 'Safety floor. Sent without asking the model, whatever the feedback history.'
        : '${a.path.join(' → ')}. Model says ${pct(a.pg)}${a.n > 0 ? ', your history (${a.n.toStringAsFixed(1)} labels) says ${pct(a.pu)}, weighted ${pct(a.w)}' : ', no personal history for this pattern yet'}.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(color: c.card, border: Border(left: BorderSide(color: col, width: 4))),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(a.levelLabel.toUpperCase(), style: T.caption.copyWith(color: col, fontWeight: FontWeight.w800, letterSpacing: .6)),
              if (a.safety) ...[const SizedBox(width: 8), Flexible(child: Pill('Safety floor', color: c.red))],
              const Spacer(),
              Text(hhmm(a.t), style: T.caption.copyWith(color: c.label2, fontFeatures: T.num)),
            ]),
            const SizedBox(height: 6),
            Text(a.title, style: T.headline.copyWith(color: c.label)),
            const SizedBox(height: 8),
            for (final r in a.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 7, right: 8), decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                  Expanded(child: Text(r, style: T.sub.copyWith(color: c.label, height: 1.35))),
                ]),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.card2, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Likely real', style: T.caption.copyWith(color: c.label2)),
                  const Spacer(),
                  Flexible(child: Text('${pct(a.p)} · sends at ${pct(a.tau)}', textAlign: TextAlign.right, style: T.caption.copyWith(color: c.label, fontWeight: FontWeight.w700, fontFeatures: T.num))),
                ]),
                const SizedBox(height: 6),
                ProbabilityBar(p: a.p, tau: a.tau, color: col),
                const SizedBox(height: 8),
                Text(ai, style: T.caption.copyWith(color: c.label2, height: 1.4)),
              ]),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in a.escalation)
                Pill('${s.who} · ${s.what}', color: switch (s.who) { 'Doctor' => c.blue, 'Caregiver' => c.orange, 'SOS' => c.red, _ => null }),
            ]),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => openAlertDetail(context, a, staffMode: staffMode, reviewer: reviewer),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(CupertinoIcons.sparkles, size: 16, color: c.indigo),
                  const SizedBox(width: 6),
                  Text('See how AdaptAlert decided', style: T.footnote.copyWith(color: c.indigo, fontWeight: FontWeight.w600)),
                  Icon(CupertinoIcons.chevron_forward, size: 14, color: c.indigo),
                ]),
              ),
            ),
            AlertActions(a: a, staffMode: staffMode, reviewer: reviewer),
          ]),
        ),
      ),
    );
  }
}

/// Feedback and review controls for one alert, shared by the alert card and
/// the alert detail page.
class AlertActions extends StatelessWidget {
  const AlertActions({super.key, required this.a, this.staffMode = false, this.reviewer = 'Dr. Kavya Rao'});
  final HealthAlert a;
  final bool staffMode;
  final String reviewer;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final m = context.watch<MonitorController>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 12),
            if (staffMode)
              Text(a.patientFeedback == null ? 'The patient hasn\'t answered yet.' : AlertCard.fbText[a.patientFeedback]!.replaceFirst('You said you were', 'Patient said they were').replaceFirst('You said you', 'Patient said they').replaceFirst('You said the', 'Patient said the').replaceFirst('You weren\'t', 'Patient wasn\'t'), style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600))
            else if (a.patientFeedback == null) ...[
              Text('What was happening?', style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.4,
                children: [
                  for (final (k, emoji, label) in AlertCard.feedbackOptions)
                    Pressable(
                      scale: .93,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        m.feedback(a, k);
                        toast(context, 'Thanks for the feedback', switch (k) {
                          PatientFeedback.unwell => 'Your doctor has been told you feel unwell.',
                          PatientFeedback.notSure => 'Your doctor will review it.',
                          _ => 'AdaptAlert will learn from this.',
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Text(emoji, style: const TextStyle(fontSize: 17)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(label, style: T.footnote.copyWith(color: c.label, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ),
                ],
              ),
            ] else
              Text(AlertCard.fbText[a.patientFeedback]!, style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600)),
            if (a.level >= 2 && !staffMode) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.tinted(
                  sizeStyle: CupertinoButtonSize.medium,
                  onPressed: () => Navigator.of(context).push(CupertinoPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => AppointmentEditor(
                      initial: Appointment(id: context.read<PatientStore>().newId(), doctorId: 'd1', forMember: 'self', at: DateTime.now(), mode: ApptMode.video, reason: 'Follow-up after alert: ${a.title}', fromAlert: '${a.id}'),
                      isNew: true,
                    ),
                  )),
                  child: const Text('Book a follow-up'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: c.sep),
            const SizedBox(height: 10),
            Row(children: [
              Text('Doctor review', style: T.footnote.copyWith(color: c.label2)),
              const Spacer(),
              switch (a.doctor) {
                DoctorLabel.confirmed => Flexible(child: Pill('Confirmed real${a.reviewedBy == null ? '' : ' · ${a.reviewedBy}'}', color: c.red)),
                DoctorLabel.rejected => Flexible(child: Pill('False alarm${a.reviewedBy == null ? '' : ' · ${a.reviewedBy}'}', color: c.green)),
                DoctorLabel.pending => Pill('Pending', color: c.gray),
              },
            ]),
            if (a.doctor == DoctorLabel.pending) ...[
              const SizedBox(height: 8),
              Text(staffMode ? 'Your review teaches AdaptAlert about this patient.' : 'Demo control: answer as $reviewer', style: T.caption.copyWith(color: c.label3)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: CupertinoButton.tinted(sizeStyle: CupertinoButtonSize.small, color: c.red, onPressed: () => _label(context, m, true), child: Text('Confirm real', style: TextStyle(color: c.red)))),
                const SizedBox(width: 8),
                Expanded(child: CupertinoButton.tinted(sizeStyle: CupertinoButtonSize.small, color: c.green, onPressed: () => _label(context, m, false), child: Text('False alarm', style: TextStyle(color: c.green)))),
              ]),
            ],
    ]);
  }

  void _label(BuildContext context, MonitorController m, bool real) {
    HapticFeedback.mediumImpact();
    m.doctorLabel(a, real, by: reviewer);
    toast(context, real ? 'Confirmed as real' : 'Marked as a false alarm', real ? 'Similar patterns will alert sooner.' : 'Similar patterns will be held back. Safety limits still apply.');
  }
}

class ProbabilityBar extends StatelessWidget {
  const ProbabilityBar({super.key, required this.p, required this.tau, required this.color});
  final double p, tau;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return LayoutBuilder(builder: (_, box) {
      return SizedBox(
        height: 14,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 0, right: 0, top: 3, child: Container(height: 8, decoration: BoxDecoration(color: c.fill2, borderRadius: BorderRadius.circular(4)))),
          Positioned(
            left: 0,
            top: 3,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: p),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Container(width: box.maxWidth * v, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            ),
          ),
          Positioned(left: box.maxWidth * tau - 1, top: 0, bottom: 0, child: Container(width: 2, decoration: BoxDecoration(color: c.label, borderRadius: BorderRadius.circular(1)))),
        ]),
      );
    });
  }
}

class _HeldCard extends StatelessWidget {
  const _HeldCard({required this.h});
  final HeldEvent h;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(color: c.card, border: Border(left: BorderSide(color: c.indigo, width: 4))),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('HELD BACK', style: T.caption.copyWith(color: c.indigo, fontWeight: FontWeight.w800, letterSpacing: .6)),
              const Spacer(),
              Text(hhmm(h.t), style: T.caption.copyWith(color: c.label2)),
            ]),
            const SizedBox(height: 6),
            Text(bucketLabel(h.key), style: T.headline.copyWith(color: c.label)),
            const SizedBox(height: 6),
            Text('Heart rate ${h.rec.r.hr} bpm, oxygen ${h.rec.r.spo2}%, temperature ${h.rec.r.temp.toStringAsFixed(1)} °C. Model said ${pct(h.pg)}; your history (${h.n.toStringAsFixed(1)} labels) said ${pct(h.pu)}.', style: T.footnote.copyWith(color: c.label2, height: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              Text('Likely real', style: T.caption.copyWith(color: c.label2)),
              const Spacer(),
              Flexible(child: Text('${pct(h.p)} · needs ${pct(h.tau)}', textAlign: TextAlign.right, style: T.caption.copyWith(color: c.label, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 6),
            ProbabilityBar(p: h.p, tau: h.tau, color: c.indigo),
            const SizedBox(height: 8),
            Text('Not sent. If this gets worse, or hits a safety limit, AdaptAlert alerts right away.', style: T.caption.copyWith(color: c.label2)),
          ]),
        ),
      ),
    );
  }
}
