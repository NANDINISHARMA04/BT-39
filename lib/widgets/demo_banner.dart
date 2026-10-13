import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/session.dart';
import '../theme/ios_theme.dart';
import 'common.dart';

/// Reminds people in Demo Mode that they can make a real account.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return IOSCard(
      color: c.tint(c.orange),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(children: [
        Icon(CupertinoIcons.play_circle_fill, color: c.orange, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('You\'re exploring the demo'), style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w700)),
            Text(tr('Log in or create your own patient, doctor or nurse account.'), style: T.caption.copyWith(color: c.label2)),
          ]),
        ),
        AppButton(tr('Log in'), kind: ButtonKind.plain, size: ButtonSize.small, onTap: () => context.read<Session>().signOut()),
      ]),
    );
  }
}
