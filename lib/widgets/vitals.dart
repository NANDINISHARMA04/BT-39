import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../theme/ios_theme.dart';

/// A scrolling pulse (PPG) waveform drawn at 60 fps at the given heart rate.
class PpgWave extends StatefulWidget {
  const PpgWave({super.key, required this.bpm, required this.color, this.noisy = false, this.paused = false});
  final int bpm;
  final Color color;
  final bool noisy, paused;
  @override
  State<PpgWave> createState() => _PpgWaveState();
}

class _PpgWaveState extends State<PpgWave> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<double> _buf = [];
  final _rnd = Random();
  double _phase = 0;
  Duration _last = Duration.zero;

  static double _shape(double x) => exp(-pow((x - .18) / .07, 2)) + .38 * exp(-pow((x - .46) / .09, 2));

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((now) {
      final dt = min(.05, (now - _last).inMicroseconds / 1e6);
      _last = now;
      if (widget.paused) return;
      final hz = widget.bpm.clamp(30, 200) / 60;
      final n = max(1, (dt * 120).round());
      for (var i = 0; i < n; i++) {
        _phase += dt / n * hz;
        _buf.add(widget.noisy ? _rnd.nextDouble() * .9 : _shape(_phase % 1));
      }
      while (_buf.length > 360) {
        _buf.removeAt(0);
      }
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final off = MediaQuery.disableAnimationsOf(context);
    if (off && _ticker.isActive) {
      _ticker.stop();
    } else if (!off && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _WavePainter(_buf, widget.noisy ? context.ios.gray : widget.color), size: Size.infinite);
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.buf, this.color);
  final List<double> buf;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (buf.length < 2) return;
    final step = size.width / 360;
    final off = size.width - buf.length * step;
    final path = Path();
    for (var i = 0; i < buf.length; i++) {
      final x = off + i * step, y = size.height - 4 - buf[i] * (size.height - 10);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(colors: [color.withValues(alpha: 0), color, color], stops: const [0, .35, 1]).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
    final lx = off + (buf.length - 1) * step, ly = size.height - 4 - buf.last * (size.height - 10);
    canvas.drawCircle(Offset(lx, ly), 6, Paint()..color = color.withValues(alpha: .25));
    canvas.drawCircle(Offset(lx, ly), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WavePainter o) => true;
}

/// A heart that beats at [bpm].
class BeatingHeart extends StatefulWidget {
  const BeatingHeart({super.key, required this.bpm, required this.color, this.size = 18});
  final int bpm;
  final Color color;
  final double size;
  @override
  State<BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<BeatingHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: _period)..repeat();
  Duration get _period => Duration(milliseconds: (60000 / widget.bpm.clamp(30, 200)).round());

  @override
  void didUpdateWidget(BeatingHeart old) {
    super.didUpdateWidget(old);
    if (old.bpm != widget.bpm) {
      _a.duration = _period;
      if (_a.isAnimating) _a.repeat();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) _a.stop();
    return AnimatedBuilder(
      animation: _a,
      builder: (_, ch) {
        final t = _a.value;
        final s = t < .12 ? 1 + 2.3 * t : t < .24 ? 1.28 - 2.3 * (t - .12) : t < .36 ? 1 + 1.15 * (t - .24) : t < .48 ? 1.14 - 1.15 * (t - .36) : 1.0;
        return Transform.scale(scale: s, child: ch);
      },
      child: Icon(CupertinoIcons.heart_fill, color: widget.color, size: widget.size),
    );
  }
}

/// An Apple-Watch-style ring.
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, required this.color, this.size = 62, this.stroke = 8});
  final double value;
  final Color color;
  final double size, stroke;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(size: Size.square(size), painter: _RingPainter(v, color, context.ios.fill2, stroke)),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track, this.stroke);
  final double v, stroke;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * pi, false, p..color = track);
    canvas.drawArc(r, -pi / 2, 2 * pi * v, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color;
}

/// Small vertical bars, e.g. motion or signal quality over the last minutes.
class MiniBars extends StatelessWidget {
  const MiniBars({super.key, required this.values, required this.colorFor, this.height = 30});
  final List<double> values;
  final Color Function(int i, double v) colorFor;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutBack,
                  height: height * values[i].clamp(.08, 1),
                  decoration: BoxDecoration(color: colorFor(i, values[i]), borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
        ]),
      );
}

/// A tiny line chart for list rows.
class Sparkline extends StatelessWidget {
  const Sparkline(this.values, {super.key, required this.color, this.width = 64, this.height = 28});
  final List<num?> values;
  final Color color;
  final double width, height;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(width, height), painter: _SparkPainter(values, color));
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);
  final List<num?> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final v = values.whereType<num>().toList();
    if (v.length < 2) return;
    final lo = v.reduce(min).toDouble(), hi = v.reduce(max).toDouble();
    final span = (hi - lo).abs() < 1e-6 ? 1 : hi - lo;
    final path = Path();
    var first = true;
    for (var i = 0; i < values.length; i++) {
      final x = values[i];
      if (x == null) {
        first = true;
        continue;
      }
      final px = 2 + i / (values.length - 1) * (size.width - 4), py = size.height - 3 - (x - lo) / span * (size.height - 6);
      first ? path.moveTo(px, py) : path.lineTo(px, py);
      first = false;
    }
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_SparkPainter o) => true;
}

/// Semicircle gauge for the alert threshold τ, with the allowed band shaded.
class TauGauge extends StatelessWidget {
  const TauGauge({super.key, required this.tau, this.min = .3, this.max = .75});
  final double tau, min, max;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: tau),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (_, v, _) => CustomPaint(size: const Size(150, 86), painter: _GaugePainter(v, min, max, c.fill2, c.teal, c.label)),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.v, this.lo, this.hi, this.track, this.band, this.needle);
  final double v, lo, hi;
  final Color track, band, needle;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 8);
    final r = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: r);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi, false, p..color = track);
    canvas.drawArc(rect, pi + pi * lo, pi * (hi - lo), false, p
      ..color = band.withValues(alpha: .6)
      ..strokeCap = StrokeCap.butt);
    final a = pi + pi * v;
    canvas.drawLine(center, center + Offset(cos(a), sin(a)) * (r - 8), Paint()
      ..color = needle
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(center, 6, Paint()..color = needle);
  }

  @override
  bool shouldRepaint(_GaugePainter o) => o.v != v;
}
