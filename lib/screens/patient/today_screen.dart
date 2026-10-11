import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../engine/adapt_alert.dart';
import '../../models/patient_models.dart';
import '../../services/monitor.dart';
import '../../services/patient_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/vitals.dart';
import 'assistant_screen.dart';
import 'family_screen.dart';
import 'insurance_screen.dart';
import 'patient_shell.dart';
import 'records_screen.dart';
import 'sos_screen.dart';

String fmtTemp(double c, bool f, {bool unit = true}) => f ? '${(c * 9 / 5 + 32).toStringAsFixed(1)}${unit ? ' °F' : ''}' : '${c.toStringAsFixed(1)}${unit ? ' °C' : ''}';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final m = context.watch<MonitorController>();
    final store = context.watch<PatientStore>();
    final r = m.last;
    final e = m.engine;
    return LargeTitlePage(
      title: 'Today',
      subtitle: '${DateFormat('EEEE, d MMMM').format(DateTime.now())} · ${store.profile.name}',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _NavIcon(icon: CupertinoIcons.slider_horizontal_3, label: 'Simulate', onTap: () => showSimulator(context)),
        const SizedBox(width: 8),
        Pressable(
          onTap: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const SosScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: c.red, borderRadius: BorderRadius.circular(99)),
            child: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: .5)),
          ),
        ),
      ]),
      children: [
        FadeIn(child: _Hero(status: e.status, r: r, tau: e.tau)),
        const SizedBox(height: 12),
        if (r != null) ...[
          FadeIn(delay: 60, child: _HeartCard(r: r, paused: m.paused, loose: m.scenarioId == 'loose')),
          const SizedBox(height: 12),
          FadeIn(
            delay: 110,
            child: Row(children: [
              Expanded(child: _SpO2Card(r: r)),
              const SizedBox(width: 12),
              Expanded(child: _TempCard(r: r, fahrenheit: store.prefs.fahrenheit)),
            ]),
          ),
          const SizedBox(height: 12),
          FadeIn(
            delay: 160,
            child: Row(children: [
              Expanded(child: _BarsCard(title: 'Activity', icon: CupertinoIcons.flame_fill, color: c.green, value: r.act, bars: e.history.reversed.take(12).toList().reversed.map((h) => h.r.motion / .8).toList(), colorFor: (i, v) => v >= .56 ? c.green : v >= .19 ? c.green.withValues(alpha: .55) : c.fill2)),
              const SizedBox(width: 12),
              Expanded(
                child: _BarsCard(
                  title: 'Signal',
                  icon: CupertinoIcons.waveform,
                  color: c.teal,
                  value: r.good ? (r.sqi >= .85 ? 'Excellent' : 'Good') : 'Poor',
                  bars: e.history.reversed.take(12).toList().reversed.map((h) => h.sqi).toList(),
                  colorFor: (i, v) => v >= e.sqiMin ? c.teal : c.gray,
                ),
              ),
            ]),
          ),
        ],
        FadeIn(delay: 200, child: const _AssistantCard()),
        SectionHeader('Latest alert', trailing: e.alerts.isEmpty ? null : 'See all', onTrailing: () => TabSwitcher.of(context, PatientTab.alerts)),
        FadeIn(
          delay: 240,
          child: e.alerts.isEmpty
              ? IOSCard(child: Text('No alerts today.', style: T.sub.copyWith(color: c.label2)))
              : IOSCard(
                  padding: EdgeInsets.zero,
                  child: IOSRow(
                    icon: CupertinoIcons.exclamationmark_triangle_fill,
                    iconColor: levelColor(context, e.alerts.first.level),
                    title: e.alerts.first.title,
                    subtitle: '${hhmm(e.alerts.first.t)} · ${alertStatusText(e.alerts.first)}',
                    onTap: () => TabSwitcher.of(context, PatientTab.alerts),
                  ),
                ),
        ),
        SectionHeader('Next appointment', trailing: 'Care', onTrailing: () => TabSwitcher.of(context, PatientTab.care)),
        FadeIn(delay: 280, child: _NextAppt(appt: store.upcoming.firstOrNull)),
        const SectionHeader('Quick actions'),
        FadeIn(
          delay: 320,
          child: Row(children: [
            _Quick(icon: CupertinoIcons.calendar_badge_plus, label: 'Book', color: c.blue, onTap: () => TabSwitcher.of(context, PatientTab.care)),
            _Quick(icon: CupertinoIcons.doc_text_fill, label: 'Records', color: c.teal, onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const RecordsScreen()))),
            _Quick(icon: CupertinoIcons.shield_lefthalf_fill, label: 'Insurance', color: c.green, onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const InsuranceScreen()))),
            _Quick(icon: CupertinoIcons.person_3_fill, label: 'Family', color: c.orange, onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const FamilyScreen()))),
          ]),
        ),
        if (store.profile.medications.isNotEmpty) ...[
          SectionHeader('Medicines', trailing: '${store.profile.medications.length}'),
          GroupedList(children: [
            for (final med in store.profile.medications) IOSRow(icon: CupertinoIcons.capsule_fill, iconColor: c.purple, title: '${med.name} ${med.dose}', subtitle: med.schedule, chevron: false),
          ]),
        ],
        const SizedBox(height: 16),
        Text('Vitals come from a simulated band in this build. Student research prototype, not a medical device.', textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
      ],
    );
  }
}

String alertStatusText(HealthAlert a) {
  if (a.doctor == DoctorLabel.confirmed) return 'Confirmed real by your doctor';
  if (a.doctor == DoctorLabel.rejected) return 'Marked false alarm by your doctor';
  if (a.patientFeedback != null) return 'Waiting for your doctor';
  return 'Waiting for your reply';
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Semantics(
      label: label,
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Container(width: 32, height: 32, decoration: BoxDecoration(color: c.fill, shape: BoxShape.circle), child: Icon(icon, size: 17, color: c.blue)),
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero({required this.status, required this.r, required this.tau});
  final String status;
  final WindowRecord? r;
  final double tau;
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final (cols, tag, title, text) = switch (widget.status) {
      'watch' => ([c.orange, c.yellow, c.pink], 'Live · watching', 'Keeping an eye on it', 'Something is a little off. AdaptAlert waits 3 minutes to see if it lasts before deciding.'),
      'held' => ([c.indigo, c.blue, c.teal], 'Live · learned pattern', 'No alert needed', 'This looks like a pattern you and your doctor marked harmless before. Safety limits still apply.'),
      'alert' => ([c.red, c.orange, c.pink], 'Live · alert sent', 'Alert sent', 'Open Alerts to see why, and tell AdaptAlert how you feel.'),
      'band' => ([c.gray, c.teal, c.indigo], 'Live · signal lost', 'Check your band', 'The sensor isn\'t reading well. These readings are ignored, so they can\'t cause false alarms.'),
      _ => ([c.green, c.teal, c.blue], 'Live · band connected', 'All clear', 'Your vitals are inside your personal normal range.'),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        color: cols[0],
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _a,
              builder: (_, _) => CustomPaint(painter: _HeroOrbs(_a.value, cols[1], cols[2])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _Blink(color: Colors.white),
                const SizedBox(width: 8),
                Text(tag, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (ch, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .2), end: Offset.zero).animate(a), child: ch)),
                child: Text(title, key: ValueKey(title), style: T.title1.copyWith(color: Colors.white)),
              ),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(color: Color(0xEBFFFFFF), fontSize: 14, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (widget.r != null) _GlassChip(hhmm(widget.r!.t)),
                if (widget.r != null) _GlassChip(widget.r!.act),
                _GlassChip('Sensitivity ${pct(widget.tau)}'),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _HeroOrbs extends CustomPainter {
  _HeroOrbs(this.t, this.a, this.b);
  final double t;
  final Color a, b;
  @override
  void paint(Canvas canvas, Size s) {
    void orb(Offset c, double r, Color col) => canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: [col.withValues(alpha: .85), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)));
    orb(Offset(s.width * (.85 - .1 * t), s.height * (.1 + .2 * t)), s.width * .5, a);
    orb(Offset(s.width * (.1 + .15 * t), s.height * (1 - .2 * t)), s.width * .42, b);
  }

  @override
  bool shouldRepaint(_HeroOrbs o) => o.t != t || o.a != a;
}

class _Blink extends StatefulWidget {
  const _Blink({required this.color});
  final Color color;
  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .25, end: 1.0).animate(_a),
        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      );
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFeatures: T.num)),
      );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.icon, this.title, this.color, {this.trailing});
  final Widget icon;
  final String title;
  final Color color;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
        icon,
        const SizedBox(width: 6),
        Text(title, style: T.sub.copyWith(color: color, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (trailing != null) Text(trailing!, style: T.caption.copyWith(color: context.ios.label2)),
      ]);
}

class _HeartCard extends StatelessWidget {
  const _HeartCard({required this.r, required this.paused, required this.loose});
  final WindowRecord r;
  final bool paused, loose;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final ctx = r.ctx == 'rest' ? 'resting' : r.act == 'Cooling down' ? 'cooling down' : r.ctx == 'light' ? 'light activity' : 'active';
    final big = T.largeTitle.copyWith(fontSize: 44, color: c.label, letterSpacing: -1.2);
    return IOSCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardTitle(BeatingHeart(bpm: r.good ? r.r.hr : 70, color: c.pink), 'Heart Rate', c.pink, trailing: 'now'),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          AnimatedNumber(r.good ? r.r.hr.toDouble() : null, style: big),
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text('BPM', style: T.sub.copyWith(color: c.label2, fontWeight: FontWeight.w600))),
          const SizedBox(width: 14),
          Expanded(child: SizedBox(height: 60, child: PpgWave(bpm: r.good ? r.r.hr : 70, color: c.pink, noisy: loose, paused: paused))),
        ]),
        const SizedBox(height: 6),
        Text.rich(TextSpan(style: T.caption.copyWith(color: c.label2), children: [
          TextSpan(text: 'Your normal ($ctx): '),
          TextSpan(text: '${(r.mu['hr']! - 2 * r.sd['hr']!).round()}–${(r.mu['hr']! + 2 * r.sd['hr']!).round()} bpm', style: TextStyle(color: c.label, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }
}

class _SpO2Card extends StatelessWidget {
  const _SpO2Card({required this.r});
  final WindowRecord r;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final low = r.good && r.z['spo2']! <= -2.5;
    return IOSCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardTitle(Icon(CupertinoIcons.drop_fill, size: 17, color: c.blue), 'Oxygen', c.blue),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Flexible(child: AnimatedNumber(r.good ? r.r.spo2.toDouble() : null, style: T.largeTitle.copyWith(color: c.label, letterSpacing: -1))),
              Padding(padding: const EdgeInsets.only(left: 2, bottom: 5), child: Text('%', style: T.sub.copyWith(color: c.label2, fontWeight: FontWeight.w600))),
            ]),
          ),
          Ring(value: r.good ? (r.r.spo2 - 85) / 15 : 0, color: low ? c.red : c.blue, size: 54, stroke: 7),
        ]),
        const SizedBox(height: 6),
        Text('Normal ${min(100, r.mu['spo2']! - 2 * r.sd['spo2']!).round()}–100%', style: T.caption.copyWith(color: c.label2)),
      ]),
    );
  }
}

class _TempCard extends StatelessWidget {
  const _TempCard({required this.r, required this.fahrenheit});
  final WindowRecord r;
  final bool fahrenheit;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final v = fahrenheit ? r.r.temp * 9 / 5 + 32 : r.r.temp;
    return IOSCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardTitle(Icon(CupertinoIcons.thermometer, size: 17, color: c.orange), 'Temp', c.orange),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Flexible(child: AnimatedNumber(r.good ? v : null, decimals: 1, style: T.largeTitle.copyWith(color: c.label, letterSpacing: -1))),
              Padding(padding: const EdgeInsets.only(left: 2, bottom: 5), child: Text(fahrenheit ? '°F' : '°C', style: T.sub.copyWith(color: c.label2, fontWeight: FontWeight.w600))),
            ]),
          ),
          Container(
            width: 14,
            height: 54,
            decoration: BoxDecoration(color: c.fill2, borderRadius: BorderRadius.circular(7)),
            alignment: Alignment.bottomCenter,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              heightFactor: r.good ? ((r.r.temp - 35) / 4).clamp(.05, 1) : .05,
              child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), gradient: LinearGradient(colors: [c.orange, c.red], begin: Alignment.bottomCenter, end: Alignment.topCenter))),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Normal ${fmtTemp(r.mu['temp']! - 2 * r.sd['temp']!, fahrenheit, unit: false)}–${fmtTemp(r.mu['temp']! + 2 * r.sd['temp']!, fahrenheit)}', style: T.caption.copyWith(color: c.label2)),
      ]),
    );
  }
}

class _BarsCard extends StatelessWidget {
  const _BarsCard({required this.title, required this.icon, required this.color, required this.value, required this.bars, required this.colorFor});
  final String title, value;
  final IconData icon;
  final Color color;
  final List<double> bars;
  final Color Function(int, double) colorFor;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return IOSCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardTitle(Icon(icon, size: 17, color: color), title, color),
        const SizedBox(height: 8),
        AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Text(value, key: ValueKey(value), style: T.title2.copyWith(color: c.label))),
        const SizedBox(height: 10),
        MiniBars(values: bars, colorFor: colorFor),
      ]),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard();
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    void open([String? q]) => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => AssistantScreen(initial: q)));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: IOSCard(
        onTap: open,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [c.indigo, c.purple, c.pink])),
              child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AI Health Assistant', style: T.headline.copyWith(color: c.label)),
                Text('Ask about your vitals, alerts, medicines or appointments', style: T.footnote.copyWith(color: c.label2)),
              ]),
            ),
            Icon(CupertinoIcons.chevron_forward, size: 16, color: c.label3),
          ]),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final q in const ['How am I doing today?', 'Why did I get my last alert?', 'What has AdaptAlert learned?'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pressable(
                    onTap: () => open(q),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: c.indigo.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
                      child: Text(q, style: T.footnote.copyWith(color: c.indigo, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _NextAppt extends StatelessWidget {
  const _NextAppt({required this.appt});
  final Appointment? appt;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final a = appt;
    if (a == null) return IOSCard(onTap: () => TabSwitcher.of(context, PatientTab.care), child: Text('No upcoming appointments. Tap to book one.', style: T.sub.copyWith(color: c.label2)));
    final d = doctorById(a.doctorId);
    final store = context.read<PatientStore>();
    return IOSCard(
      onTap: () => TabSwitcher.of(context, PatientTab.care),
      child: Row(children: [
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: c.blue.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(DateFormat('MMM').format(a.at).toUpperCase(), style: T.caption.copyWith(color: c.blue, fontWeight: FontWeight.w700)),
            Text(DateFormat('d').format(a.at), style: T.title2.copyWith(color: c.blue)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name, style: T.headline.copyWith(color: c.label)),
            Text('${d.specialty} · ${DateFormat('EEE, h:mm a').format(a.at)}', style: T.footnote.copyWith(color: c.label2)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              Pill(a.mode == ApptMode.video ? 'Video' : 'In clinic', icon: a.mode == ApptMode.video ? CupertinoIcons.video_camera_solid : CupertinoIcons.building_2_fill, color: c.blue),
              if (a.forMember != 'self') Pill('For ${store.memberName(a.forMember).split(' ').first}', color: c.orange),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18), boxShadow: c.dark ? null : const [BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6))]),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: T.caption.copyWith(color: c.label, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
