import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/l10n.dart';
import '../../theme/ios_theme.dart';

/// The grey of an incoming iMessage bubble.
Color incomingBubble(IOS c) => c.dark ? const Color(0xFF26262A) : const Color(0xFFE9E9EB);

const _radius = 18.0;

/// How far an iMessage tail reaches past the bubble.
const bubbleTail = 6.0;

/// A chat bubble with the iMessage tail on the last bubble of a group. [mine]
/// puts the tail on the right. The child is padded so text never sits on the tail.
class Bubble extends StatelessWidget {
  const Bubble({super.key, required this.child, required this.color, required this.mine, this.tail = true, this.border});
  final Widget child;
  final Color color;
  final bool mine, tail;
  final Color? border;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BubblePainter(color: color, mine: mine, tail: tail, border: border),
        child: Padding(
          padding: EdgeInsets.only(left: mine ? 0 : bubbleTail, right: mine ? bubbleTail : 0),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), child: child),
        ),
      );
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.color, required this.mine, required this.tail, this.border});
  final Color color;
  final bool mine, tail;
  final Color? border;

  /// The bubble for a tail on the right: body from 0 to w, the tail curling out to w + [bubbleTail] at the bottom.
  static Path shape(double w, double h, bool tail) {
    final r = math.min(_radius, h / 2);
    final body = Path()..addRRect(RRect.fromLTRBR(0, 0, w, h, Radius.circular(r)));
    if (!tail) return body;
    final t = Path()
      ..moveTo(w, h - 20)
      ..quadraticBezierTo(w, h - 2, w + bubbleTail, h)
      ..quadraticBezierTo(w - 5, h + .5, w - 15, h - 4)
      ..lineTo(w - 15, h - 20)
      ..close();
    return Path.combine(PathOperation.union, body, t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - bubbleTail;
    var p = shape(w, size.height, tail);
    if (!mine) {
      // Mirror: the tail goes on the left.
      p = p.transform(Float64List.fromList([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, size.width, 0, 0, 1]));
    }
    canvas.drawPath(p, Paint()..color = color);
    if (border != null) {
      canvas.drawPath(p, Paint()
        ..color = border!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.color != color || old.mine != mine || old.tail != tail || old.border != border;
}

/// The iMessage "typing" bubble: three dots that rise one after another, and
/// the two little thought circles under it. Still dots when motion is reduced.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});
  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _a.stop();
    } else if (!_a.isAnimating) {
      _a.repeat();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final bg = incomingBubble(c);
    const dot = Color(0xFF8E8E93);
    return Semantics(
      label: tr('Typing…'),
      child: SizedBox(
        width: 74,
        height: 46,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 0, bottom: 0, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: bg, shape: BoxShape.circle))),
          Positioned(left: 5, bottom: 6, child: Container(width: 13, height: 13, decoration: BoxDecoration(color: bg, shape: BoxShape.circle))),
          Positioned(
            left: 10,
            top: 0,
            child: AnimatedBuilder(
              animation: _a,
              builder: (_, _) => Container(
                width: 60,
                height: 36,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 3; i++) _dot(i, dot),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dot(int i, Color color) {
    // Each dot rises and brightens in turn, then rests.
    final phase = (_a.value - i * .16) % 1.0;
    final up = phase < .4 ? math.sin(phase / .4 * math.pi) : 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      child: Transform.translate(
        offset: Offset(0, -3.5 * up),
        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color.withValues(alpha: .45 + .55 * up), shape: BoxShape.circle)),
      ),
    );
  }
}

/// Text that types itself in as it arrives: it shows characters at a pace
/// that speeds up when it falls behind, and the newest few fade in like ink.
/// [live] is false once the answer is complete; it then catches up quickly.
/// With reduced motion the whole text shows at once.
class RevealText extends StatefulWidget {
  const RevealText({super.key, required this.text, required this.live, required this.builder, this.onCaughtUp});
  final String text;
  final bool live;

  /// Builds the visible part: (text shown so far, how far the fading tail starts).
  final Widget Function(String shown, int fadeFrom) builder;
  final VoidCallback? onCaughtUp;

  @override
  State<RevealText> createState() => _RevealTextState();
}

class _RevealTextState extends State<RevealText> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  double _shown = 0;
  Duration _last = Duration.zero;
  bool _instant = false;

  int get _target => widget.text.characters.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _instant = MediaQuery.disableAnimationsOf(context);
    if (_instant) _shown = _target.toDouble();
    _go();
  }

  @override
  void didUpdateWidget(RevealText old) {
    super.didUpdateWidget(old);
    if (_instant) _shown = _target.toDouble();
    _go();
  }

  void _go() {
    if (_shown < _target && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration t) {
    final dt = _last == Duration.zero ? 1 / 60 : (t - _last).inMicroseconds / 1e6;
    _last = t;
    final behind = _target - _shown;
    // About 55 characters a second, faster when behind; a finished answer catches up within half a second.
    final speed = widget.live ? 55 + behind * 4 : math.max(120, behind * 2.2);
    setState(() => _shown = math.min(_target.toDouble(), _shown + speed * dt));
    if (_shown >= _target) {
      _ticker.stop();
      widget.onCaughtUp?.call();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _shown.floor().clamp(0, _target);
    final shown = widget.text.characters.take(n).toString();
    final caughtUp = n >= _target;
    return widget.builder(shown, caughtUp ? shown.length : math.max(0, shown.length - 8));
  }
}

final _cite = RegExp(r'\[(\d+(?:\s*,\s*\d+)*)\]');
final _bold = RegExp(r'\*\*(.+?)\*\*');
final _partialCite = RegExp(r'\[[\d,\s]*$');

/// Chat text as spans: `**bold**`, list lines as bullets, and `[n]` citations
/// as small numbered badges ([onCite] opens the fact). The characters from
/// [fadeFrom] on are drawn fainter, so new words fade in.
InlineSpan chatSpans(BuildContext context, String text, TextStyle style, {int? fadeFrom, Color? citeColor, void Function(int n)? onCite}) {
  final c = context.ios;
  var t = text.replaceAll(_partialCite, '');
  t = t.split('\n').map((l) {
    final m = RegExp(r'^\s*[*-]\s+').firstMatch(l);
    return m == null ? l : '• ${l.substring(m.end)}';
  }).join('\n');
  final fade = fadeFrom == null || fadeFrom >= t.length ? null : fadeFrom;
  final spans = <InlineSpan>[];
  var i = 0;

  void plain(String s, int at, {bool bold = false}) {
    if (s.isEmpty) return;
    final base = bold ? style.copyWith(fontWeight: FontWeight.w600) : style;
    if (fade == null || at + s.length <= fade) {
      spans.add(TextSpan(text: s, style: base));
      return;
    }
    final cut = math.max(0, fade - at);
    if (cut > 0) spans.add(TextSpan(text: s.substring(0, cut), style: base));
    final tail = s.substring(cut);
    // A gentle ramp over the newest characters.
    for (var k = 0; k < tail.length; k++) {
      final p = (k + 1) / (tail.length + 1);
      spans.add(TextSpan(text: tail[k], style: base.copyWith(color: base.color?.withValues(alpha: (1 - p * .75).clamp(.2, 1.0)))));
    }
  }

  void withBold(String s, int at) {
    var j = 0;
    for (final m in _bold.allMatches(s)) {
      plain(s.substring(j, m.start), at + j);
      plain(m[1]!, at + m.start + 2, bold: true);
      j = m.end;
    }
    plain(s.substring(j), at + j);
  }

  for (final m in _cite.allMatches(t)) {
    withBold(t.substring(i, m.start), i);
    for (final n in RegExp(r'\d+').allMatches(m[1]!).map((x) => int.parse(x[0]!))) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: onCite == null ? null : () => onCite(n),
          child: Container(
            margin: const EdgeInsets.only(left: 2, right: 1),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: (citeColor ?? c.blue).withValues(alpha: .16), borderRadius: BorderRadius.circular(7)),
            child: Text('$n', style: TextStyle(fontSize: (style.fontSize ?? 17) * .62, fontWeight: FontWeight.w700, color: citeColor ?? c.blue, height: 1.2)),
          ),
        ),
      ));
    }
    i = m.end;
  }
  withBold(t.substring(i), i);
  return TextSpan(children: spans);
}

/// The text a citation-marked answer reads as, for speech and copying.
String plainChatText(String text) => text.replaceAll(_cite, '').replaceAll('**', '').replaceAllMapped(RegExp(r' +([.,;:।])'), (m) => m[1]!).trim();

/// Pops in from a corner with a spring: a sent bubble rises from the composer,
/// a received one grows from its tail. No movement with reduced motion.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, required this.fromRight, this.rise = 28});
  final Widget child;
  final bool fromRight;
  final double rise;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutBack,
      builder: (_, t, ch) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * rise),
          child: Transform.scale(scale: .82 + .18 * t, alignment: fromRight ? Alignment.bottomRight : Alignment.bottomLeft, child: ch),
        ),
      ),
      child: child,
    );
  }
}

/// Fades and lifts in after [delay] milliseconds: source chips and buttons
/// arrive one after another under a finished answer.
class Arrive extends StatelessWidget {
  const Arrive({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final total = 320 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (_, t, ch) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: ch)),
      child: child,
    );
  }
}
