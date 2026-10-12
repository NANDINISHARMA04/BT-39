import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/session.dart';
import '../../theme/ios_theme.dart';
import 'role_auth_screen.dart';

/// Shown the moment the guided demo ends: log in or sign up now.
Future<void> showLoginNow(BuildContext context) => Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => const LoginNowScreen(),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));

class LoginNowScreen extends StatelessWidget {
  const LoginNowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final s = context.read<Session>();
    Widget logIn(Role r) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              color: roleColor(context, r),
              onPressed: () => s.leaveDemoToLogIn(r),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(roleIcon(r), color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(child: Text(tr('Log in as {role}', {'role': tr(roleLabel[r]!)}), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: .35),
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 14),
                  decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(28)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [c.green, c.teal])),
                      child: const Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: 14),
                    Text(tr('Demo complete'), textAlign: TextAlign.center, style: T.title1.copyWith(color: c.label)),
                    const SizedBox(height: 6),
                    Text(tr('Log in now to use PulseOS with your own account.'), textAlign: TextAlign.center, style: T.body.copyWith(color: c.label2)),
                    const SizedBox(height: 20),
                    for (final r in Role.values) logIn(r),
                    const SizedBox(height: 4),
                    Text(tr('New here? Create an account'), style: T.footnote.copyWith(color: c.label2)),
                    Wrap(alignment: WrapAlignment.center, children: [
                      for (final r in Role.values)
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onPressed: () => s.leaveDemoToLogIn(r, signUp: true),
                          child: Text(tr(roleLabel[r]!), style: TextStyle(color: roleColor(context, r), fontWeight: FontWeight.w600)),
                        ),
                    ]),
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr('Keep exploring the demo'), style: T.footnote.copyWith(color: c.label2)),
                    ),
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
