import 'package:flutter/material.dart';

/// The tab to go back to, and how, for the tab that is showing now. Tab pages
/// show a back button while this is set (see LargeTitlePage).
final shellBack = ValueNotifier<({String label, VoidCallback go})?>(null);

/// A navigator for an app shell that lives under the shell's providers.
///
/// It remembers which tabs were visited, like pages in a browser. The
/// browser's back button, Android back, the iOS back swipe and the on-screen
/// back button close the open page first, then return to the previous tab,
/// then to the home tab, and only then leave the app.
class ShellNavigator extends StatefulWidget {
  const ShellNavigator({super.key, required this.navKey, required this.tab, required this.homeTab, required this.home, required this.labelOf});
  final GlobalKey<NavigatorState> navKey;
  final ValueNotifier<int> tab;
  final int homeTab;
  final Widget home;

  /// The name of a tab, for the back button.
  final String Function(int tab) labelOf;

  @override
  State<ShellNavigator> createState() => _ShellNavigatorState();
}

class _ShellNavigatorState extends State<ShellNavigator> {
  bool _innerCanPop = false;
  final List<int> _history = [];
  late int _current = widget.tab.value;
  bool _goingBack = false;

  @override
  void initState() {
    super.initState();
    widget.tab.addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
  }

  @override
  void dispose() {
    widget.tab.removeListener(_onTab);
    shellBack.value = null;
    super.dispose();
  }

  void _onTab() {
    final next = widget.tab.value;
    if (next == _current) return;
    if (!_goingBack) {
      _history.remove(next);
      _history.add(_current);
      if (_history.length > 20) _history.removeAt(0);
    }
    _current = next;
    _goingBack = false;
    _publish();
    if (mounted) setState(() {});
  }

  /// Where back goes when no page is open: the previous tab, else home.
  int? get _backTab => _history.isNotEmpty ? _history.last : (_current != widget.homeTab ? widget.homeTab : null);

  void _publish() {
    final t = _backTab;
    shellBack.value = t == null ? null : (label: widget.labelOf(t), go: _backToTab);
  }

  void _backToTab() {
    final t = _backTab;
    if (t == null) return;
    if (_history.isNotEmpty) _history.removeLast();
    _goingBack = true;
    widget.tab.value = t;
    _goingBack = false;
    _publish();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_innerCanPop && _backTab == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_innerCanPop) {
          widget.navKey.currentState?.maybePop();
        } else {
          _backToTab();
        }
      },
      child: NotificationListener<NavigationNotification>(
        onNotification: (n) {
          if (n.canHandlePop != _innerCanPop) {
            // Notifications can arrive during a build; update after it.
            WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() => _innerCanPop = n.canHandlePop) : null);
          }
          return true;
        },
        child: HeroControllerScope(
          controller: MaterialApp.createMaterialHeroController(),
          child: Navigator(key: widget.navKey, onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => widget.home)),
        ),
      ),
    );
  }
}
