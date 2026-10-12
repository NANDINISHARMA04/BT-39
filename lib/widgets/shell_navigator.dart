import 'package:flutter/material.dart';

/// A navigator for an app shell that lives under the shell's providers.
///
/// The browser's back button, Android back and the iOS back swipe close the
/// open page first, then go back to the home tab, and only then leave the app.
class ShellNavigator extends StatefulWidget {
  const ShellNavigator({super.key, required this.navKey, required this.tab, required this.homeTab, required this.home});
  final GlobalKey<NavigatorState> navKey;
  final ValueNotifier<int> tab;
  final int homeTab;
  final Widget home;

  @override
  State<ShellNavigator> createState() => _ShellNavigatorState();
}

class _ShellNavigatorState extends State<ShellNavigator> {
  bool _innerCanPop = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.tab,
      builder: (context, tab, child) => PopScope<Object?>(
        canPop: !_innerCanPop && tab == widget.homeTab,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_innerCanPop) {
            widget.navKey.currentState?.maybePop();
          } else {
            widget.tab.value = widget.homeTab;
          }
        },
        child: child!,
      ),
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
