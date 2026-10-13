import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../engine/adapt_alert.dart';
import '../../l10n/l10n.dart';
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
      title: tr('Alerts'),
      subtitle: tr('Explained, and learning from your answers'),
      children: [
        const FadeIn(child: AdaptAlertHero()),
        const SizedBox(height: 14),
        CupertinoSlidingSegmentedControl<String>(
          groupValue: _filter,
          children: {
            'open': Text('${tr('Needs reply')}${m.needsReply > 0 ? ' (${m.needsReply})' : ''}'),
            'all': Text(tr('All')),
            'held': Text(tr('Held back')),
          },
          onValueChanged: (v) => setState(() => _filter = v ?? 'open'),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: Motion.base,
          child: Column(
            key: ValueKey('$_filter-${list.length}-${e.held.length}'),
            children: _filter == 'held'
                ? (e.held.isEmpty
                    ? [EmptyState(icon: CupertinoIcons.checkmark_circle, title: tr('Nothing held back yet'), message: tr('When AdaptAlert learns a pattern is harmless for you, those alerts show up here instead of buzzing your phone.'))]
                    : [for (final (i, h) in e.held.indexed) FadeIn(delay: i * 40, child: _HeldCard(h: h))])
                : (list.isEmpty
                    ? [
                        EmptyState(
                          icon: CupertinoIcons.checkmark_circle,
                          title: tr('You\'re all caught up'),
                          message: tr('No alerts need your reply. Try “Heart racing at rest” or “Coffee or stress” from the simulator.'),
                          action: tr('Open simulator'),
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

/// The first lines of an alert card: a coloured symbol, the level, the time
/// and the title. Shared by sent and held-back alerts.
class _AlertHead extends StatelessWidget {
  const _AlertHead({required this.color, required this.icon, required this.level, required this.time, required this.title, this.tag});
  final Color color;
  final IconData icon;
  final String level, time, title;
  final Widget? tag;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      IconSquare(icon, color, size: 34),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(level.toUpperCase(), style: T.overline.copyWith(color: color)),
            if (tag != null) ...[const SizedBox(width: 8), Flexible(child: tag!)],
            const Spacer(),
            Text(time, style: T.caption.copyWith(color: c.label2, fontFeatures: T.num)),
          ]),
          const SizedBox(height: 3),
          Text(title, style: T.headline.copyWith(color: c.label)),
        ]),
      ),
    ]);
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.a, this.staffMode = false, this.reviewer = 'Dr. Kavya Rao'});
  final HealthAlert a;

  /// Doctors and nurses see the patient's answer and review buttons instead of
  /// the patient's own feedback buttons.
  final bool staffMode;
  final String reviewer;

  /// English labels; shown through tr().
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
        ? tr('Safety floor. Sent without asking the model, whatever the feedback history.')
        : '${a.path.join(' → ')}. ${tr('Model says {p}', {'p': pct(a.pg)})}${a.n > 0 ? tr(', your history ({n} labels) says {pu}, weighted {w}', {'n': a.n.toStringAsFixed(1), 'pu': pct(a.pu), 'w': pct(a.w)}) : tr(', no personal history for this pattern yet')}.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IOSCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _AlertHead(color: col, icon: CupertinoIcons.exclamationmark_triangle_fill, level: a.levelLabel, time: hhmm(a.t), title: a.title, tag: a.safety ? Pill(tr('Safety floor'), color: c.red) : null),
          const SizedBox(height: 10),
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
            decoration: BoxDecoration(color: c.card2, borderRadius: BorderRadius.circular(R.sm)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(tr('Likely real'), style: T.caption.copyWith(color: c.label2)),
                const Spacer(),
                Flexible(child: Text(tr('{p} · sends at {tau}', {'p': pct(a.p), 'tau': pct(a.tau)}), textAlign: TextAlign.right, style: T.caption.copyWith(color: c.label, fontWeight: FontWeight.w700, fontFeatures: T.num))),
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
              Pill('${trData(s.who)} · ${s.what}', color: switch (s.who) { 'Doctor' => c.blue, 'Caregiver' => c.orange, 'SOS' => c.red, _ => null }),
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
                Flexible(child: Text(tr('See how AdaptAlert decided'), style: T.footnote.copyWith(color: c.indigo, fontWeight: FontWeight.w600))),
                Icon(CupertinoIcons.chevron_forward, size: 14, color: c.indigo),
              ]),
            ),
          ),
          AlertActions(a: a, staffMode: staffMode, reviewer: reviewer),
        ]),
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
        Text(a.patientFeedback == null ? tr('The patient hasn\'t answered yet.') : tr(AlertCard.fbText[a.patientFeedback]!.replaceFirst('You said you were', 'Patient said they were').replaceFirst('You said you', 'Patient said they').replaceFirst('You said the', 'Patient said the').replaceFirst('You weren\'t', 'Patient wasn\'t')), style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600))
      else if (a.patientFeedback == null) ...[
        Text(tr('What was happening?'), style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600)),
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
                scale: .94,
                onTap: () {
                  HapticFeedback.lightImpact();
                  m.feedback(a, k);
                  toast(context, tr('Thanks for the feedback'), switch (k) {
                    PatientFeedback.unwell => tr('Your doctor has been told you feel unwell.'),
                    PatientFeedback.notSure => tr('Your doctor will review it.'),
                    _ => tr('AdaptAlert will learn from this.'),
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(R.sm)),
                  child: Row(children: [
                    Text(emoji, style: const TextStyle(fontSize: 17)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr(label), maxLines: 2, overflow: TextOverflow.ellipsis, style: T.footnote.copyWith(color: c.label, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ),
          ],
        ),
      ] else
        Text(tr(AlertCard.fbText[a.patientFeedback]!), style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600)),
      if (a.level >= 2 && !staffMode) ...[
        const SizedBox(height: 10),
        AppButton(
          tr('Book a follow-up'),
          kind: ButtonKind.tinted,
          size: ButtonSize.medium,
          expand: true,
          onTap: () => Navigator.of(context).push(CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (_) => AppointmentEditor(
              initial: Appointment(id: context.read<PatientStore>().newId(), doctorId: 'd1', forMember: 'self', at: DateTime.now(), mode: ApptMode.video, reason: tr('Follow-up after alert: {title}', {'title': a.title}), fromAlert: '${a.id}'),
              isNew: true,
            ),
          )),
        ),
      ],
      const SizedBox(height: 12),
      const Hairline(),
      const SizedBox(height: 10),
      Row(children: [
        Text(tr('Doctor review'), style: T.footnote.copyWith(color: c.label2)),
        const Spacer(),
        switch (a.doctor) {
          DoctorLabel.confirmed => Flexible(child: Pill('${tr('Confirmed real')}${a.reviewedBy == null ? '' : ' · ${a.reviewedBy}'}', color: c.red)),
          DoctorLabel.rejected => Flexible(child: Pill('${tr('False alarm')}${a.reviewedBy == null ? '' : ' · ${a.reviewedBy}'}', color: c.green)),
          DoctorLabel.pending => Pill(tr('Pending'), color: c.gray),
        },
      ]),
      if (a.doctor == DoctorLabel.pending) ...[
        const SizedBox(height: 8),
        Text(staffMode ? tr('Your review teaches AdaptAlert about this patient.') : tr('Demo control: answer as {name}', {'name': reviewer}), style: T.caption.copyWith(color: c.label3)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: AppButton(tr('Confirm real'), kind: ButtonKind.tinted, size: ButtonSize.small, color: c.red, onTap: () => _label(context, m, true))),
          const SizedBox(width: 8),
          Expanded(child: AppButton(tr('False alarm'), kind: ButtonKind.tinted, size: ButtonSize.small, color: c.green, onTap: () => _label(context, m, false))),
        ]),
      ],
    ]);
  }

  void _label(BuildContext context, MonitorController m, bool real) {
    HapticFeedback.mediumImpact();
    m.doctorLabel(a, real, by: reviewer);
    toast(context, real ? tr('Confirmed as real') : tr('Marked as a false alarm'), real ? tr('Similar patterns will alert sooner.') : tr('Similar patterns will be held back. Safety limits still apply.'));
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
          Positioned(left: 0, right: 0, top: 3, child: ProgressBar(value: p, height: 8, color: color)),
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
      child: IOSCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _AlertHead(color: c.indigo, icon: CupertinoIcons.bell_slash_fill, level: tr('HELD BACK'), time: hhmm(h.t), title: bucketLabel(h.key)),
          const SizedBox(height: 8),
          Text(tr('Heart rate {hr} bpm, oxygen {spo2}%, temperature {temp} °C. Model said {pg}; your history ({n} labels) said {pu}.', {'hr': h.rec.r.hr, 'spo2': h.rec.r.spo2, 'temp': h.rec.r.temp.toStringAsFixed(1), 'pg': pct(h.pg), 'n': h.n.toStringAsFixed(1), 'pu': pct(h.pu)}), style: T.footnote.copyWith(color: c.label2, height: 1.4)),
          const SizedBox(height: 10),
          Row(children: [
            Text(tr('Likely real'), style: T.caption.copyWith(color: c.label2)),
            const Spacer(),
            Flexible(child: Text(tr('{p} · needs {tau}', {'p': pct(h.p), 'tau': pct(h.tau)}), textAlign: TextAlign.right, style: T.caption.copyWith(color: c.label, fontWeight: FontWeight.w700, fontFeatures: T.num))),
          ]),
          const SizedBox(height: 6),
          ProbabilityBar(p: h.p, tau: h.tau, color: c.indigo),
          const SizedBox(height: 8),
          Text(tr('Not sent. If this gets worse, or hits a safety limit, AdaptAlert alerts right away.'), style: T.caption.copyWith(color: c.label2)),
        ]),
      ),
    );
  }
}
