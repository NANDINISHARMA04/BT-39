import 'package:flutter/material.dart';

import '../theme/ios_theme.dart';
import 'common.dart';

/// One entry in the sidebar.
class SideNavItem {
  const SideNavItem({required this.icon, required this.activeIcon, required this.label, required this.onTap, this.selected = false, this.badge = 0});
  final IconData icon, activeIcon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final int badge;
}

/// The left-hand navigation on laptops and wide tablets, shared by the patient
/// and the staff app: a header, the sections, and buttons at the bottom.
class SideNav extends StatelessWidget {
  const SideNav({super.key, required this.header, required this.items, this.footer = const []});
  final Widget header;
  final List<SideNavItem> items;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Container(
      width: 260,
      decoration: BoxDecoration(color: c.card, border: Border(right: BorderSide(color: c.sep, width: .5))),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            header,
            const SizedBox(height: 24),
            for (final it in items) Padding(padding: const EdgeInsets.only(bottom: 4), child: _Row(item: it)),
            const Spacer(),
            ...footer,
          ]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final SideNavItem item;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final on = item.selected;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: on ? c.tint(c.blue) : Colors.transparent, borderRadius: BorderRadius.circular(R.sm)),
      child: TapHighlight(
        onTap: item.onTap,
        radius: R.sm,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(on ? item.activeIcon : item.icon, size: 21, color: on ? c.blue : c.label2),
            const SizedBox(width: 12),
            Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.callout.copyWith(color: on ? c.blue : c.label, fontWeight: on ? FontWeight.w600 : FontWeight.w400))),
            if (item.badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: c.red, borderRadius: BorderRadius.circular(9)),
                child: Text('${item.badge}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      ),
    );
  }
}
