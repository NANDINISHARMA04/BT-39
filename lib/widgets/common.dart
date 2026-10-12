import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/ios_theme.dart';
import 'shell_navigator.dart';

/// Shrinks a little while pressed, with an iOS spring.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = .96, this.onLongPress});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

class IOSCard extends StatelessWidget {
  const IOSCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.radius = 20, this.onTap});
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
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: c.dark ? null : const [BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.onTrailing});
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: T.title3.copyWith(fontWeight: FontWeight.w700, color: c.label))),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailing,
              child: Text(trailing!, style: T.sub.copyWith(color: onTrailing != null ? c.blue : c.label2)),
            ),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? col : (color == null ? c.fill : col.withValues(alpha: .16)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: solid ? Colors.white : col), const SizedBox(width: 4)],
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(fontWeight: FontWeight.w600, color: solid ? Colors.white : col))),
      ]),
    );
  }
}

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

/// A group of rows with inset hairlines, like iOS Settings.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children, this.footer});
  final List<Widget> children;
  final String? footer;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) rows.add(Padding(padding: const EdgeInsets.only(left: 58), child: Divider(height: .5, thickness: .5, color: c.sep)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(color: c.card, child: Column(children: rows)),
      ),
      if (footer != null)
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(footer!, style: T.footnote.copyWith(color: c.label2))),
    ]);
  }
}

class IOSRow extends StatelessWidget {
  const IOSRow({super.key, this.icon, this.iconColor, this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.chevron = true, this.destructive = false});
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return InkWell(
      onTap: onTap,
      highlightColor: c.fill,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)] else if (icon != null) ...[IconSquare(icon!, iconColor ?? c.blue), const SizedBox(width: 14)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.body.copyWith(color: destructive ? c.red : c.label), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: T.footnote.copyWith(color: c.label2))),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (onTap != null && chevron) ...[const SizedBox(width: 6), Icon(CupertinoIcons.chevron_forward, size: 16, color: c.label3)],
        ]),
      ),
    );
  }
}

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
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(v.toStringAsFixed(decimals), style: style.copyWith(fontFeatures: T.num)),
    );
  }
}

/// Fades and slides a child in once, after [delay]. Used for staggered lists.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.delay = 0, this.dy = 18});
  final Widget child;
  final int delay;
  final double dy;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + delay),
      curve: Interval(delay / (520 + delay), 1, curve: Curves.easeOutCubic),
      builder: (_, t, ch) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * dy), child: ch)),
      child: child,
    );
  }
}

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
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(children: [
        Icon(icon, size: 48, color: color ?? c.green),
        const SizedBox(height: 10),
        Text(title, style: T.headline.copyWith(color: c.label), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(message, style: T.footnote.copyWith(color: c.label2), textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 14), CupertinoButton.tinted(onPressed: onAction, sizeStyle: CupertinoButtonSize.medium, child: Text(action!))],
      ]),
    );
  }
}

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
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
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
    final t = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
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
                radius: 18,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(border: Border.all(color: c.sep, width: .5), borderRadius: BorderRadius.circular(18)),
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
Future<R?> showSheet<R>(BuildContext context, Widget Function(BuildContext) builder) {
  final c = context.ios;
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: c.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    builder: builder,
  );
}

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
