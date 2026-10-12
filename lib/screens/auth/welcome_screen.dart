import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/session.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import '../research/research_lab_screen.dart';
import 'role_auth_screen.dart';

/// The landing page: what AdaptAlert is, a one-tap guided demo, and sign-in
/// for patients, doctors and nurses.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _auth(Role r, {bool signUp = false}) => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => RoleAuthScreen(role: r, signUp: signUp)));

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final s = context.read<Session>();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final hero = Column(crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
      FadeIn(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const _AppIcon(size: 44),
          const SizedBox(width: 10),
          Text('AdaptAlert', style: T.title2.copyWith(color: c.label)),
        ]),
      ),
      const SizedBox(height: 22),
      FadeIn(
        delay: 60,
        child: Text('Health alerts\nthat learn you.', textAlign: wide ? TextAlign.left : TextAlign.center, style: T.largeTitle.copyWith(color: c.label, fontSize: wide ? 56 : 40, height: 1.05, letterSpacing: -1)),
      ),
      const SizedBox(height: 14),
      FadeIn(
        delay: 120,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Fixed-threshold monitors alarm at every walk, coffee and loose sensor, until nobody trusts them. AdaptAlert learns each patient\'s normal, explains every alert, and learns from patient and doctor feedback, while a safety floor keeps critical readings impossible to ignore.',
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: T.callout.copyWith(color: c.label2, height: 1.45),
          ),
        ),
      ),
      const SizedBox(height: 22),
      FadeIn(
        delay: 180,
        child: Wrap(spacing: 10, runSpacing: 10, alignment: wide ? WrapAlignment.start : WrapAlignment.center, children: [
          _CtaButton(label: 'Watch the 90-second demo', icon: CupertinoIcons.play_fill, onTap: () => s.startDemo(Role.patient, tour: true)),
          _CtaButton(label: 'Research Lab', icon: CupertinoIcons.lab_flask_solid, tinted: true, onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ResearchLabScreen()))),
        ]),
      ),
      const SizedBox(height: 16),
      FadeIn(
        delay: 220,
        child: Wrap(spacing: 18, runSpacing: 8, alignment: wide ? WrapAlignment.start : WrapAlignment.center, children: const [
          _Stat('~97%', 'fewer false alarms*'),
          _Stat('100%', 'real events caught*'),
          _Stat('7', 'stage explainable AI'),
        ]),
      ),
    ]);

    final roles = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Sign in as', style: T.title3.copyWith(color: c.label)),
      const SizedBox(height: 12),
      for (final (i, (r, sub)) in [
        (Role.patient, 'Live vitals, explained alerts, appointments, records, SOS'),
        (Role.doctor, 'Review AdaptAlert alerts, the ward on NEWS2, patient chat'),
        (Role.nurse, 'Ward alerts, acknowledge and resolve, home-patient triage'),
      ].indexed)
        FadeIn(delay: 260 + i * 60, child: _RoleCard(role: r, subtitle: sub, onLogin: () => _auth(r), onSignUp: () => _auth(r, signUp: true))),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Just looking? Try without an account:', style: T.footnote.copyWith(color: c.label2)),
        for (final r in Role.values) CupertinoButton(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(30, 30), onPressed: () => s.startDemo(r), child: Text(roleLabel[r]!, style: const TextStyle(fontSize: 14))),
      ]),
    ]);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(children: [
        Positioned.fill(child: AnimatedBuilder(animation: _a, builder: (_, _) => CustomPaint(painter: _Orbs(_a.value, [c.pink, c.blue, c.teal, c.indigo], c.bg)))),
        SafeArea(
          child: ListView(padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20, vertical: wide ? 48 : 24), children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 6, child: Padding(padding: const EdgeInsets.only(top: 24, right: 48), child: hero)),
                        Expanded(flex: 5, child: roles),
                      ])
                    : Column(children: [hero, const SizedBox(height: 32), roles]),
              ),
            ),
            const SizedBox(height: 40),
            Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1120), child: _HowItWorks(wide: wide))),
            const SizedBox(height: 24),
            Text('* In a 30-day simulation of 40 virtual patients, compared with fixed thresholds. See the Research Lab.\nStudent research prototype (B.Tech CSE major project). Not a medical device.',
                textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3, height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.subtitle, required this.onLogin, required this.onSignUp});
  final Role role;
  final String subtitle;
  final VoidCallback onLogin, onSignUp;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final col = roleColor(context, role);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IOSCard(
        onTap: onLogin,
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: col.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)), child: Icon(roleIcon(role), color: col, size: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(roleLabel[role]!, style: T.headline.copyWith(color: c.label)),
              Text(subtitle, style: T.footnote.copyWith(color: c.label2)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(30, 32),
              color: col,
              borderRadius: BorderRadius.circular(99),
              onPressed: onLogin,
              child: const Text('Log in', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            CupertinoButton(padding: EdgeInsets.zero, minimumSize: const Size(30, 28), onPressed: onSignUp, child: Text('Sign up', style: TextStyle(color: col, fontSize: 13))),
          ]),
        ]),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.wide});
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final steps = [
      (CupertinoIcons.person_crop_circle, c.blue, 'Learns your normal', 'Personal ranges per vital and activity, from good-quality readings only.'),
      (CupertinoIcons.text_bubble_fill, c.purple, 'Explains every alert', 'Plain reasons, how sure it is, and what would have changed the decision.'),
      (CupertinoIcons.arrow_2_circlepath, c.green, 'Learns from feedback', 'Patient and doctor answers tune alerts for each person, within safe limits.'),
      (CupertinoIcons.shield_lefthalf_fill, c.red, 'Never ignores danger', 'A safety floor and bounded learning keep critical readings alerting.'),
    ];
    final cards = [
      for (final (i, (icon, col, t, d)) in steps.indexed)
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: col, size: 26),
              const Spacer(),
              Text('${i + 1}', style: T.title2.copyWith(color: c.label3)),
            ]),
            const SizedBox(height: 10),
            Text(t, style: T.headline.copyWith(color: c.label)),
            const SizedBox(height: 4),
            Text(d, style: T.footnote.copyWith(color: c.label2, height: 1.4)),
          ]),
        ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('How AdaptAlert works', style: T.title2.copyWith(color: c.label)),
      const SizedBox(height: 12),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final (i, card) in cards.indexed) Expanded(child: Padding(padding: EdgeInsets.only(right: i < 3 ? 12 : 0), child: card))])
      else
        Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 10), child: card)]),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: T.title2.copyWith(color: c.label, fontFeatures: T.num)),
      Text(label, style: T.caption.copyWith(color: c.label2)),
    ]);
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .23),
        gradient: LinearGradient(colors: [c.pink, c.red], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: c.pink.withValues(alpha: .35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Icon(CupertinoIcons.waveform_path_ecg, color: Colors.white, size: size * .55),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, required this.icon, required this.onTap, this.tinted = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool tinted;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: tinted ? c.blue.withValues(alpha: .14) : c.blue, borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: tinted ? c.blue : Colors.white),
          const SizedBox(width: 8),
          Text(label, style: T.headline.copyWith(color: tinted ? c.blue : Colors.white)),
        ]),
      ),
    );
  }
}

/// Slow-moving blurred colour fields behind the welcome screen.
class _Orbs extends CustomPainter {
  _Orbs(this.t, this.colors, this.bg);
  final double t;
  final List<Color> colors;
  final Color bg;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < colors.length; i++) {
      final a = 2 * pi * (t + i / colors.length);
      final center = Offset(size.width * (.5 + .38 * cos(a + i)), size.height * (.28 + .22 * sin(a * (i.isEven ? 1 : -1))));
      final r = size.shortestSide * (.45 + .08 * i);
      canvas.drawCircle(
        center,
        r,
        Paint()..shader = RadialGradient(colors: [colors[i].withValues(alpha: .26), colors[i].withValues(alpha: 0)]).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_Orbs o) => o.t != t || o.bg != bg;
}
