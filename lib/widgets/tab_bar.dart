import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ios_theme.dart';
import 'common.dart';

/// One tab: an outline symbol, its filled twin for when it is selected, a name
/// and an optional count.
class TabItem {
  const TabItem({required this.icon, required this.activeIcon, required this.label, this.badge = 0});
  final IconData icon, activeIcon;
  final String label;
  final int badge;
}

/// The bottom tab bar, shared by the patient and the staff app: frosted glass
/// over the page, a hairline on top, and a symbol that bounces once when it
/// is picked. No ripple, no lift: iOS tabs only change colour.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.items, required this.index, required this.onSelect});
  final List<TabItem> items;
  final int index;
  final void Function(int index) onSelect;

  /// How tall the bar is, for things that float above it.
  static double heightOf(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return 6 + 24 + 3 + MediaQuery.textScalerOf(context).scale(10) * 1.3 + 2 + (bottom > 0 ? bottom : 10);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Glass(
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.sep, width: .5))),
        padding: EdgeInsets.only(top: 6, bottom: bottom > 0 ? bottom : 10),
        child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _TabButton(
                item: items[i],
                selected: i == index,
                onTap: () {
                  if (i != index) HapticFeedback.selectionClick();
                  onSelect(i);
                },
              ),
            ),
        ]),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  const _TabButton({required this.item, required this.selected, required this.onTap});
  final TabItem item;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 60),
  ]).animate(_bounce);

  @override
  void didUpdateWidget(_TabButton old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected && !MediaQuery.disableAnimationsOf(context)) _bounce.forward(from: 0);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final it = widget.item;
    final col = widget.selected ? c.blue : c.gray;
    return Semantics(
      selected: widget.selected,
      button: true,
      label: it.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              ScaleTransition(
                scale: _scale,
                child: Icon(widget.selected ? it.activeIcon : it.icon, size: 24, color: col),
              ),
              if (it.badge > 0)
                Positioned(
                  right: -10,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(color: c.red, borderRadius: BorderRadius.circular(9)),
                    child: Text(it.badge > 99 ? '99+' : '${it.badge}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, height: 1.3)),
                  ),
                ),
            ]),
            const SizedBox(height: 3),
            Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: -.1, color: col)),
          ]),
        ),
      ),
    );
  }
}

/// The pages of a tab bar, all kept alive. The one that is showing fades in;
/// a page that is left fades out, then goes offstage: it stops ticking, is
/// not drawn and is hidden from touch and screen readers, like a tab that is
/// not showing on iOS.
class TabPages extends StatelessWidget {
  const TabPages({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Stack(children: [for (var i = 0; i < children.length; i++) _TabPage(active: i == index, child: children[i])]);
}

class _TabPage extends StatefulWidget {
  const _TabPage({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> {
  late bool _offstage = !widget.active;

  @override
  void didUpdateWidget(_TabPage old) {
    super.didUpdateWidget(old);
    // Back on screen at once; off screen only once the fade has finished.
    if (widget.active) _offstage = false;
  }

  @override
  // The fade must keep running when a tab is left, so only the page's own
  // animations are paused, not the fade itself. Otherwise a page that is
  // left half-faded stays drawn over the tab below it.
  Widget build(BuildContext context) => Offstage(
        offstage: _offstage,
        child: IgnorePointer(
          ignoring: !widget.active,
          child: AnimatedOpacity(
            opacity: widget.active ? 1 : 0,
            duration: Motion.quick,
            onEnd: () {
              if (!widget.active && mounted) setState(() => _offstage = true);
            },
            child: TickerMode(enabled: widget.active, child: ExcludeSemantics(excluding: !widget.active, child: widget.child)),
          ),
        ),
      );
}
