import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../services/session.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import 'sign_in_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final s = context.read<Session>();
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, _) => CustomPaint(painter: _Orbs(_a.value, [c.pink, c.blue, c.teal, c.indigo], c.bg)),
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                children: [
                  FadeIn(child: Center(child: _AppIcon(size: 84))),
                  const SizedBox(height: 18),
                  FadeIn(delay: 80, child: Text('AdaptAlert', textAlign: TextAlign.center, style: T.largeTitle.copyWith(color: c.label, fontSize: 40))),
                  const SizedBox(height: 8),
                  FadeIn(
                    delay: 140,
                    child: Text('Smart health monitoring that learns your normal, explains every alert and gets quieter when you tell it a false alarm.',
                        textAlign: TextAlign.center, style: T.callout.copyWith(color: c.label2, height: 1.4)),
                  ),
                  const SizedBox(height: 26),
                  FadeIn(
                    delay: 200,
                    child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                      for (final (i, t, col) in [
                        (CupertinoIcons.waveform_path_ecg, 'Live vitals', c.pink),
                        (CupertinoIcons.sparkles, 'Self-learning alerts', c.indigo),
                        (CupertinoIcons.calendar, 'Appointments', c.blue),
                        (CupertinoIcons.doc_text_fill, 'Records vault', c.teal),
                        (CupertinoIcons.shield_lefthalf_fill, 'Insurance', c.green),
                        (CupertinoIcons.exclamationmark_octagon_fill, 'SOS', c.red),
                      ])
                        Pill(t, icon: i, color: col),
                    ]),
                  ),
                  const SizedBox(height: 26),
                  FadeIn(
                    delay: 260,
                    child: _BigButton(
                      label: 'Try the patient demo',
                      icon: CupertinoIcons.heart_fill,
                      onTap: () => s.startDemo(Role.patient),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeIn(
                    delay: 300,
                    child: Row(children: [
                      Expanded(child: _BigButton(label: 'Doctor', icon: CupertinoIcons.person_crop_circle_fill_badge_checkmark, tinted: true, onTap: () => s.startDemo(Role.doctor))),
                      const SizedBox(width: 10),
                      Expanded(child: _BigButton(label: 'Nurse', icon: CupertinoIcons.bandage_fill, tinted: true, onTap: () => s.startDemo(Role.nurse))),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  FadeIn(
                    delay: 340,
                    child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SignInScreen())),
                        child: const Text('Sign in'),
                      ),
                      Text('·', style: TextStyle(color: c.label3)),
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SignInScreen(createAccount: true))),
                        child: const Text('Create account'),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppConfig.supabaseEnabled
                        ? 'Demo Mode keeps everything on this device. Accounts use Supabase sign-in.'
                        : 'Demo Mode keeps everything on this device. This build has no Supabase key, so only Demo Mode is available.',
                    textAlign: TextAlign.center,
                    style: T.caption.copyWith(color: c.label2),
                  ),
                  const SizedBox(height: 4),
                  Text('Student research prototype. Not a medical device.', textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
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
        boxShadow: [BoxShadow(color: c.pink.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Icon(CupertinoIcons.waveform_path_ecg, color: Colors.white, size: size * .55),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.icon, required this.onTap, this.tinted = false});
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
        height: 54,
        decoration: BoxDecoration(
          color: tinted ? c.blue.withValues(alpha: .14) : c.blue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: tinted ? c.blue : Colors.white),
          const SizedBox(width: 8),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.headline.copyWith(color: tinted ? c.blue : Colors.white))),
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
        Paint()
          ..shader = RadialGradient(colors: [colors[i].withValues(alpha: .30), colors[i].withValues(alpha: 0)]).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_Orbs o) => o.t != t || o.bg != bg;
}
