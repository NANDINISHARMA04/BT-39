import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/session.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
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
                  decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(R.xl)),
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
                    for (final r in Role.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppButton(tr('Log in as {role}', {'role': tr(roleLabel[r]!)}), icon: roleIcon(r), color: roleColor(context, r), expand: true, onTap: () => s.leaveDemoToLogIn(r)),
                      ),
                    const SizedBox(height: 4),
                    Text(tr('New here? Create an account'), style: T.footnote.copyWith(color: c.label2)),
                    Wrap(alignment: WrapAlignment.center, children: [
                      for (final r in Role.values) AppButton(tr(roleLabel[r]!), kind: ButtonKind.plain, size: ButtonSize.medium, color: roleColor(context, r), onTap: () => s.leaveDemoToLogIn(r, signUp: true)),
                    ]),
                    AppButton(tr('Keep exploring the demo'), kind: ButtonKind.plain, size: ButtonSize.medium, color: c.label2, onTap: () => Navigator.of(context).pop()),
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
