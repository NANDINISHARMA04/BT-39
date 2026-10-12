import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hi.dart';

/// The app's language: 'en' or 'hi'. Saved on the device.
final appLang = ValueNotifier<String>('en');

bool get hindi => appLang.value == 'hi';

/// Text shown in Hindi that has no translation yet. Tests keep this empty.
final missingHindi = <String>{};

/// Translates a piece of interface text. [en] is the English text and the
/// lookup key; `{name}` placeholders are filled from [args].
String tr(String en, [Map<String, Object?>? args]) {
  var s = en;
  if (appLang.value == 'hi') {
    final h = hiStrings[en];
    if (h != null) {
      s = h;
    } else {
      missingHindi.add(en);
    }
  }
  if (args != null) {
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  }
  return s;
}

/// Translates a data value (a condition, a speciality, a category) when a
/// translation exists, and otherwise shows it as entered.
String trData(String en) => appLang.value == 'hi' ? (hiStrings[en] ?? en) : en;

Future<void> loadLang() async {
  try {
    final l = (await SharedPreferences.getInstance()).getString('bt39.lang');
    if (l == 'hi' || l == 'en') appLang.value = l!;
  } catch (_) {}
}

Future<void> setLang(String l) async {
  appLang.value = l;
  try {
    await (await SharedPreferences.getInstance()).setString('bt39.lang', l);
  } catch (_) {}
}

/// Rebuilds the whole app when the language changes, keeping its state.
class LangScope extends StatefulWidget {
  const LangScope({super.key, required this.child});
  final Widget child;
  @override
  State<LangScope> createState() => _LangScopeState();
}

class _LangScopeState extends State<LangScope> {
  @override
  void initState() {
    super.initState();
    appLang.addListener(_changed);
  }

  @override
  void dispose() {
    appLang.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    setState(() {});
    // Many screens are const widgets that don't depend on the language, so
    // mark every element for rebuild.
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
