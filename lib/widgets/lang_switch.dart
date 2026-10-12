import 'package:flutter/cupertino.dart';

import '../l10n/l10n.dart';
import '../theme/ios_theme.dart';
import 'common.dart';

/// English / हिन्दी switch for the welcome page.
class LangToggle extends StatelessWidget {
  const LangToggle({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: appLang,
        builder: (context, lang, _) => CupertinoSlidingSegmentedControl<String>(
          groupValue: lang,
          children: const {'en': Text('English'), 'hi': Text('हिन्दी')},
          onValueChanged: (v) => setLang(v ?? 'en'),
        ),
      );
}

/// A settings row that switches the app language.
class LanguageRow extends StatelessWidget {
  const LanguageRow({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return IOSRow(
      icon: CupertinoIcons.globe,
      iconColor: c.blue,
      title: hindi ? 'भाषा' : 'Language',
      chevron: false,
      trailing: const LangToggle(),
    );
  }
}
