import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/ios_theme.dart';
import 'shell_navigator.dart';

// -- touch ---------------------------------------------------------------------------------------------------------------

/// Shrinks a little the moment it is touched and springs back on release, the
/// way App Store cards do. Holds still with reduced motion.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = .97, this.onLongPress});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down && !still ? widget.scale : 1,
          duration: _down ? Motion.press : Motion.base,
          curve: _down ? Curves.easeOut : Motion.spring,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fills with grey while a finger rests on it, like a row in Settings. The
/// fill comes in over a few frames, so a scroll that starts on the row barely
/// shows it, and fades out after a tap so even a quick tap is seen.
class TapHighlight extends StatefulWidget {
  const TapHighlight({super.key, required this.child, this.onTap, this.onLongPress, this.radius = 0, this.color});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? color;

  @override
  State<TapHighlight> createState() => _TapHighlightState();
}

class _TapHighlightState extends State<TapHighlight> {
  bool _on = false;

  void _set(bool v) {
    if (_on != v && mounted) setState(() => _on = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: _on ? const Duration(milliseconds: 80) : Motion.quick,
          decoration: BoxDecoration(color: _on ? (widget.color ?? c.fill) : Colors.transparent, borderRadius: BorderRadius.circular(widget.radius)),
          child: widget.child,
        ),
      ),
    );
  }
}

// -- surfaces ------------------------------------------------------------------------------------------------------------

/// A white card on the grey page, like the cards in Health. No shadow: the
/// contrast with the background is the edge.
class IOSCard extends StatelessWidget {
  const IOSCard({super.key, required this.child, this.padding = Insets.card, this.color, this.radius = R.md, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final box = Container(
      padding: padding,
      // Rows inside a card paint their highlight to the edge, so the card clips them to its corners.
      clipBehavior: padding == EdgeInsets.zero ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(color: color ?? c.card, borderRadius: BorderRadius.circular(radius)),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, scale: .98, child: box);
  }
}

/// The one coloured card on a page: a status, a headline figure, a wallet-style
/// policy. Text and icons inside are white.
class AccentCard extends StatelessWidget {
  const AccentCard({super.key, required this.color, required this.child, this.to, this.padding = const EdgeInsets.all(18), this.onTap});
  final Color color;

  /// The second colour of the gentle gradient. By default a darker shade of [color].
  final Color? to;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.lg),
        gradient: LinearGradient(colors: [color, to ?? Color.lerp(color, Colors.black, .16)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child),
      ),
    );
    return onTap == null ? box : Pressable(onTap: onTap, scale: .98, child: box);
  }
}

/// A frosted-glass panel.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 0, this.color});
  final Widget child;
  final double radius;
  final Color? color;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: ColoredBox(color: color ?? context.ios.material, child: child),
        ),
      );
}

/// A one-pixel line, as thin as the screen can draw.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0});
  final double indent;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: indent),
        child: SizedBox(width: double.infinity, height: 1 / MediaQuery.devicePixelRatioOf(context), child: ColoredBox(color: context.ios.sep)),
      );
}

/// The PulseOS mark: a pulse line on pink.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, this.size = 44, this.glow = true});
  final double size;
  final bool glow;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .23),
        gradient: LinearGradient(colors: [c.pink, c.red], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: glow ? [BoxShadow(color: c.pink.withValues(alpha: .35), blurRadius: 20, offset: const Offset(0, 8))] : null,
      ),
      child: Icon(CupertinoIcons.waveform_path_ecg, color: Colors.white, size: size * .55),
    );
  }
}

// -- text and labels ------------------------------------------------------------------------------------------------------

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.onTrailing});
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: T.title3.copyWith(fontWeight: FontWeight.w700, color: c.label))),
          if (trailing != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTrailing,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Text(trailing!, style: T.sub.copyWith(color: onTrailing != null ? c.blue : c.label2, fontWeight: onTrailing != null ? FontWeight.w500 : FontWeight.w400)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small capsule label: a status, a count, a tag.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon, this.solid = false});
  final String text;
  final Color? color;
  final IconData? icon;
  final bool solid;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final col = color ?? c.label2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: solid ? col : (color == null ? c.fill : c.tint(col)), borderRadius: BorderRadius.circular(R.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: solid ? Colors.white : col), const SizedBox(width: 4)],
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(fontWeight: FontWeight.w600, color: solid ? Colors.white : col))),
      ]),
    );
  }
}

/// A rounded square with a white symbol, like the icons in Settings.
class IconSquare extends StatelessWidget {
  const IconSquare(this.icon, this.color, {super.key, this.size = 30});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * .26)),
        child: Icon(icon, color: Colors.white, size: size * .6),
      );
}

/// The grey chevron at the end of a row that opens something.
class Chevron extends StatelessWidget {
  const Chevron({super.key});
  @override
  Widget build(BuildContext context) => Icon(CupertinoIcons.chevron_forward, size: 15, color: context.ios.label3);
}

// -- lists ---------------------------------------------------------------------------------------------------------------

/// A group of rows with inset hairlines, like iOS Settings.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children, this.footer});
  final List<Widget> children;
  final String? footer;

  /// Whether a row has an icon or picture at its start, looking through the Semantics that wrap some rows.
  static bool _leads(Widget w) => w is IOSRow ? (w.icon != null || w.leading != null) : (w is Semantics && w.child != null && _leads(w.child!));

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    // Hairlines start where the text starts, and all of a group's start in the same place: after the icon when the
    // group has icons, at the card's edge when it has none.
    final indent = children.any(_leads) ? 58.0 : 14.0;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) rows.add(Hairline(indent: indent));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(R.md)),
        child: Column(children: rows),
      ),
      if (footer != null) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(footer!, style: T.footnote.copyWith(color: c.label2, height: 1.35))),
    ]);
  }
}

class IOSRow extends StatelessWidget {
  const IOSRow({super.key, this.icon, this.iconColor, this.leading, required this.title, this.subtitle, this.value, this.trailing, this.onTap, this.chevron = true, this.destructive = false});
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final String? subtitle;

  /// Grey text at the end of the row, like "Wi-Fi   Home".
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return TapHighlight(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)] else if (icon != null) ...[IconSquare(icon!, iconColor ?? c.blue), const SizedBox(width: 14)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.body.copyWith(color: destructive ? c.red : c.label), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: T.footnote.copyWith(color: c.label2))),
              ]),
            ),
            // The title takes what the value leaves; the value hugs the right edge and shortens with "…" when it is long.
            if (value != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .45),
                child: Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: T.body.copyWith(color: c.label2)),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (onTap != null && chevron) ...[const SizedBox(width: 6), const Chevron()],
          ]),
        ),
      ),
    );
  }
}

// -- controls ------------------------------------------------------------------------------------------------------------

enum ButtonKind { filled, tinted, plain }

enum ButtonSize { large, medium, small }

/// The app's button: filled for the main action, tinted for the second one,
/// plain for a link. Built on CupertinoButton, so it dims on press like iOS.
class AppButton extends StatelessWidget {
  const AppButton(this.label, {super.key, required this.onTap, this.kind = ButtonKind.filled, this.size = ButtonSize.large, this.icon, this.color, this.busy = false, this.expand = false, this.destructive = false});
  final String label;
  final VoidCallback? onTap;
  final ButtonKind kind;
  final ButtonSize size;
  final IconData? icon;
  final Color? color;

  /// Shows a spinner in place of the label and ignores taps.
  final bool busy;
  final bool expand;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final col = destructive ? c.red : (color ?? c.blue);
    final filled = kind == ButtonKind.filled;
    final fg = filled ? Colors.white : col;
    final (height, radius, fontSize, pad) = switch (size) {
      ButtonSize.large => (50.0, R.md, 17.0, 20.0),
      ButtonSize.medium => (44.0, 12.0, 16.0, 16.0),
      ButtonSize.small => (34.0, R.sm, 15.0, 12.0),
    };
    final label0 = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, letterSpacing: -.3, color: fg));
    final button = CupertinoButton(
      padding: EdgeInsets.symmetric(horizontal: kind == ButtonKind.plain ? 8 : pad),
      minimumSize: Size(height, height),
      borderRadius: BorderRadius.circular(radius),
      color: filled ? col : (kind == ButtonKind.tinted ? c.tint(col) : null),
      disabledColor: filled ? col.withValues(alpha: .4) : (kind == ButtonKind.tinted ? c.fill : Colors.transparent),
      pressedOpacity: .7,
      onPressed: busy ? null : onTap,
      child: busy
          ? CupertinoActivityIndicator(color: fg, radius: size == ButtonSize.small ? 7 : 9)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: fontSize + 2, color: fg), const SizedBox(width: 7)],
                label0,
              ]),
            ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A capsule you can pick: a filter, a time slot, a question to ask.
/// Grey when idle, the colour when selected, a light wash of the colour when
/// [tinted] (a suggestion that is not a choice).
class AppChip extends StatelessWidget {
  const AppChip(this.label, {super.key, this.icon, this.selected = false, this.tinted = false, this.onTap, this.color, this.large = false, this.enabled = true, this.square = false});
  final String label;
  final IconData? icon;
  final bool selected, tinted, large, enabled, square;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final col = color ?? c.blue;
    final (bg, fg) = selected ? (col, Colors.white) : tinted ? (c.tint(col), col) : (c.fill, c.label);
    final style = (large ? T.sub : T.footnote).copyWith(fontWeight: FontWeight.w600, color: fg);
    return Pressable(
      onTap: enabled ? onTap : null,
      scale: .95,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : .45,
        duration: Motion.quick,
        child: AnimatedContainer(
          duration: Motion.quick,
          curve: Motion.enter,
          constraints: BoxConstraints(minHeight: large ? 40 : 32),
          padding: EdgeInsets.symmetric(horizontal: large ? 14 : 12, vertical: large ? 8 : 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(square ? R.sm : R.pill)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: large ? 18 : 15, color: fg), const SizedBox(width: 6)],
            Flexible(child: Text(label, maxLines: large ? 2 : 1, overflow: TextOverflow.ellipsis, style: style)),
          ]),
        ),
      ),
    );
  }
}

/// A rounded bar that fills to [value] (0–1).
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color, this.track, this.height = 6});
  final double value;
  final Color? color, track;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: track ?? c.fill2)),
          TweenAnimationBuilder<double>(
            tween: Tween(end: v),
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 700),
            curve: Motion.enter,
            builder: (_, t, _) => FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: t, heightFactor: 1, child: ColoredBox(color: color ?? c.blue)),
          ),
        ]),
      ),
    );
  }
}

/// Looks like the iOS search field; tapping it opens a page where the real search happens.
class SearchBox extends StatelessWidget {
  const SearchBox({super.key, required this.placeholder, required this.onTap});
  final String placeholder;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Semantics(
      button: true,
      label: placeholder,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: .99,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(R.sm)),
          child: Row(children: [
            Icon(CupertinoIcons.search, size: 18, color: c.label3),
            const SizedBox(width: 5),
            Expanded(child: Text(placeholder, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body.copyWith(color: c.label3))),
          ]),
        ),
      ),
    );
  }
}

/// A text button for a navigation bar: Cancel, Save, Edit.
class BarButton extends StatelessWidget {
  const BarButton(this.label, {super.key, required this.onTap, this.bold = false});
  final String label;
  final VoidCallback? onTap;
  final bool bold;
  @override
  Widget build(BuildContext context) => CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: onTap,
        child: Text(label, style: TextStyle(fontSize: 17, fontWeight: bold ? FontWeight.w600 : FontWeight.w400, letterSpacing: -.4)),
      );
}

// -- motion --------------------------------------------------------------------------------------------------------------

/// Counts up or down to [value] whenever it changes.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber(this.value, {super.key, this.decimals = 0, required this.style});
  final double? value;
  final int decimals;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    if (value == null) return Text('--', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value!),
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 650),
      curve: Motion.enter,
      builder: (_, v, _) => Text(v.toStringAsFixed(decimals), style: style.copyWith(fontFeatures: T.num)),
    );
  }
}

/// Fades and lifts a child in once, after [delay] milliseconds. Used for staggered lists.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.delay = 0, this.dy = 12});
  final Widget child;
  final int delay;
  final double dy;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final total = 420 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Motion.enter),
      builder: (_, t, ch) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * dy), child: ch)),
      child: child,
    );
  }
}

// -- states --------------------------------------------------------------------------------------------------------------

/// Nothing here yet: a grey symbol, a title and a line of help, like iOS's "content unavailable" view.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action, this.onAction, this.color});
  final IconData icon;
  final String title, message;
  final String? action;
  final VoidCallback? onAction;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(children: [
        Icon(icon, size: 44, color: color ?? c.label3),
        const SizedBox(height: 10),
        Text(title, style: T.headline.copyWith(color: c.label), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(message, style: T.footnote.copyWith(color: c.label2, height: 1.35), textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 14), AppButton(action!, kind: ButtonKind.tinted, size: ButtonSize.medium, onTap: onAction)],
      ]),
    );
  }
}

// -- pages ---------------------------------------------------------------------------------------------------------------

/// A page with an iOS large title that collapses into a blurred bar on scroll.
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({super.key, required this.title, required this.children, this.trailing, this.leading, this.subtitle, this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 120), this.previousTitle});
  final String title;
  final String? subtitle;
  final String? previousTitle;
  final List<Widget> children;
  final Widget? trailing;
  final Widget? leading;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    // A tab's first page offers a way back to the previous tab.
    if (leading == null && !(ModalRoute.of(context)?.canPop ?? false)) {
      return ValueListenableBuilder(
        valueListenable: shellBack,
        builder: (context, back, _) => _page(
          context,
          back == null
              ? null
              // Phones have little room beside the title, so they show the arrow only.
              : Semantics(
                  label: back.label,
                  button: true,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(34, 34),
                    onPressed: back.go,
                    child: MediaQuery.sizeOf(context).width >= 600
                        ? Row(mainAxisSize: MainAxisSize.min, children: [const Icon(CupertinoIcons.chevron_back, size: 26), Text(back.label, style: const TextStyle(fontSize: 17))])
                        : const Icon(CupertinoIcons.chevron_back, size: 28),
                  ),
                ),
        ),
      );
    }
    return _page(context, leading);
  }

  Widget _page(BuildContext context, Widget? leading) {
    final c = context.ios;
    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            leading: leading,
            previousPageTitle: previousTitle,
            trailing: trailing,
            backgroundColor: c.material,
            border: Border(bottom: BorderSide(color: c.sep, width: .5)),
            stretch: true,
            // Tabs keep several of these pages alive in one route; their default
            // Hero tags would clash on push, so they don't animate between routes.
            transitionBetweenRoutes: false,
          ),
          if (subtitle != null)
            SliverToBoxAdapter(
              child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 6), child: Text(subtitle!, style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600))),
            ),
          SliverPadding(padding: padding, sliver: SliverList(delegate: SliverChildListDelegate(children))),
        ],
      ),
    );
  }
}

/// The standard bar of a pushed page: a title in the middle, the previous
/// page's name on the back button, and a hairline under the blur.
CupertinoNavigationBar plainBar(BuildContext context, {Widget? middle, String? previousTitle, Widget? leading, Widget? trailing}) {
  final c = context.ios;
  return CupertinoNavigationBar(
    middle: middle,
    previousPageTitle: previousTitle,
    leading: leading,
    trailing: trailing,
    backgroundColor: c.material,
    border: Border(bottom: BorderSide(color: c.sep, width: .5)),
  );
}

/// A pushed page with a small title: the same bar, scroll feel and margins everywhere.
class PlainPage extends StatelessWidget {
  const PlainPage({super.key, this.title, this.middle, required this.children, this.previousTitle, this.leading, this.trailing, this.padding});
  final String? title;

  /// Replaces the title with any widget.
  final Widget? middle;
  final String? previousTitle;
  final Widget? leading, trailing;
  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: plainBar(context, middle: middle ?? (title == null ? null : Text(title!)), previousTitle: previousTitle, leading: leading, trailing: trailing),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: padding ?? EdgeInsets.fromLTRB(16, 16, 16, 40 + bottom),
        children: children,
      ),
    );
  }
}

// -- overlays ------------------------------------------------------------------------------------------------------------

/// iOS-style HUD toast that drops in near the bottom of the screen.
void toast(BuildContext context, String title, [String? message]) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Toast(title: title, message: message, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.title, this.message, required this.onDone});
  final String title;
  final String? message;
  final VoidCallback onDone;
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: Motion.slow);
  @override
  void initState() {
    super.initState();
    a.forward();
    Future.delayed(const Duration(milliseconds: 2600), () async {
      if (!mounted) return;
      await a.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final t = CurvedAnimation(parent: a, curve: Motion.spring, reverseCurve: Curves.easeIn);
    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 96,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: t,
          builder: (_, ch) => Opacity(opacity: a.value, child: Transform.translate(offset: Offset(0, (1 - t.value) * 24), child: ch)),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Glass(
                radius: R.lg,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(border: Border.all(color: c.sep, width: .5), borderRadius: BorderRadius.circular(R.lg)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.title, style: T.sub.copyWith(fontWeight: FontWeight.w600, color: c.label), textAlign: TextAlign.center),
                    if (widget.message != null && widget.message!.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 2), child: Text(widget.message!, style: T.footnote.copyWith(color: c.label2), textAlign: TextAlign.center)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, {required String title, required String message, required String action, bool destructive = true}) async {
  final r = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel'))),
        CupertinoDialogAction(isDestructiveAction: destructive, isDefaultAction: !destructive, onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  return r ?? false;
}

/// A rounded modal sheet with a grabber.
Future<X?> showSheet<X>(BuildContext context, Widget Function(BuildContext) builder) {
  final c = context.ios;
  return showModalBottomSheet<X>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: c.bg,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg))),
    builder: builder,
  );
}

/// A wheel picker (a date, a time) in a sheet with a Done button.
Future<void> showPicker(BuildContext context, {required Widget picker, String? title}) {
  final c = context.ios;
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => Container(
      height: 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(R.lg))),
      child: SafeArea(
        top: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(children: [
              Expanded(child: Text(title ?? '', style: T.headline.copyWith(color: c.label))),
              BarButton(tr('Done'), bold: true, onTap: () => Navigator.pop(ctx)),
            ]),
          ),
          const Hairline(),
          Expanded(child: picker),
        ]),
      ),
    ),
  );
}

// -- forms ---------------------------------------------------------------------------------------------------------------

/// A grouped form card: fields separated by hairlines.
class FormGroup extends StatelessWidget {
  const FormGroup({super.key, required this.children, this.header, this.footer});
  final List<Widget> children;
  final String? header, footer;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (header != null) Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 6), child: Text(header!.toUpperCase(), style: T.footnote.copyWith(color: c.label2))),
      GroupedList(footer: footer, children: children),
    ]);
  }
}

/// A plain text field that sits inside a [FormGroup] row.
class FormField2 extends StatelessWidget {
  const FormField2({super.key, required this.label, required this.controller, this.hint, this.keyboard, this.obscure = false, this.maxLines = 1, this.validator, this.autofill});
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboard;
  final bool obscure;
  final int maxLines;
  final String? Function(String?)? validator;
  final Iterable<String>? autofill;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
        SizedBox(width: 110, child: Padding(padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0), child: Text(label, style: T.body.copyWith(color: c.label)))),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboard,
            obscureText: obscure,
            maxLines: maxLines,
            validator: validator,
            autofillHints: autofill,
            style: T.body.copyWith(color: c.label),
            decoration: InputDecoration(hintText: hint, fillColor: Colors.transparent, contentPadding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
      ]),
    );
  }
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 40, this.colors});
  final String name;
  final double size;
  final List<Color>? colors;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors ?? [c.indigo, c.blue], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Text(initials(name), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * .36)),
    );
  }
}
