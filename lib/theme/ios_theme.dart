import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// iOS system colours, with the light and dark variants Apple uses.
@immutable
class IOS extends ThemeExtension<IOS> {
  const IOS({
    required this.bg,
    required this.card,
    required this.card2,
    required this.label,
    required this.label2,
    required this.label3,
    required this.sep,
    required this.fill,
    required this.fill2,
    required this.material,
    required this.red,
    required this.orange,
    required this.yellow,
    required this.green,
    required this.teal,
    required this.blue,
    required this.indigo,
    required this.purple,
    required this.pink,
    required this.gray,
    required this.dark,
  });

  final Color bg, card, card2, label, label2, label3, sep, fill, fill2, material;
  final Color red, orange, yellow, green, teal, blue, indigo, purple, pink, gray;
  final bool dark;

  static const light = IOS(
    bg: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFF2F2F7),
    label: Color(0xFF000000),
    label2: Color(0x9E3C3C43),
    label3: Color(0x523C3C43),
    sep: Color(0x243C3C43),
    fill: Color(0x1F787880),
    fill2: Color(0x33787880),
    material: Color(0xC7F9F9FB),
    red: Color(0xFFFF3B30),
    orange: Color(0xFFFF9500),
    yellow: Color(0xFFFFCC00),
    green: Color(0xFF34C759),
    teal: Color(0xFF30B0C7),
    blue: Color(0xFF007AFF),
    indigo: Color(0xFF5856D6),
    purple: Color(0xFFAF52DE),
    pink: Color(0xFFFF2D55),
    gray: Color(0xFF8E8E93),
    dark: false,
  );

  static const darkTheme = IOS(
    bg: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    card2: Color(0xFF2C2C2E),
    label: Color(0xFFFFFFFF),
    label2: Color(0x9EEBEBF5),
    label3: Color(0x4DEBEBF5),
    sep: Color(0x8C545458),
    fill: Color(0x3D787880),
    fill2: Color(0x5C787880),
    material: Color(0xBD1C1C1E),
    red: Color(0xFFFF453A),
    orange: Color(0xFFFF9F0A),
    yellow: Color(0xFFFFD60A),
    green: Color(0xFF30D158),
    teal: Color(0xFF40C8E0),
    blue: Color(0xFF0A84FF),
    indigo: Color(0xFF5E5CE6),
    purple: Color(0xFFBF5AF2),
    pink: Color(0xFFFF375F),
    gray: Color(0xFF8E8E93),
    dark: true,
  );

  @override
  IOS copyWith() => this;

  @override
  IOS lerp(ThemeExtension<IOS>? other, double t) => t < .5 ? this : (other as IOS? ?? this);
}

extension IOSContext on BuildContext {
  IOS get ios => Theme.of(this).extension<IOS>()!;
}

const _fontFallback = ['SF Pro Text', 'SF Pro Display', '.SF UI Text', 'Helvetica Neue', 'Roboto', 'Segoe UI'];

/// Apple platforms use the system font (SF Pro). Everywhere else Roboto is the
/// system font already; naming it also gives widget tests real font metrics.
String? get _family => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS ? null : 'Roboto';

ThemeData buildTheme(IOS c) {
  final cupertinoText = _family == null ? null : CupertinoTextThemeData(textStyle: TextStyle(fontFamily: _family, fontSize: 17, color: c.label, letterSpacing: -.4));
  final base = ThemeData(
    fontFamily: _family,
    useMaterial3: true,
    brightness: c.dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.blue,
      brightness: c.dark ? Brightness.dark : Brightness.light,
      primary: c.blue,
      surface: c.card,
      error: c.red,
    ),
    scaffoldBackgroundColor: c.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    fontFamilyFallback: _fontFallback,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
    }),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: c.dark ? Brightness.dark : Brightness.light,
      primaryColor: c.blue,
      scaffoldBackgroundColor: c.bg,
      barBackgroundColor: c.material,
      textTheme: cupertinoText == null
          ? null
          : CupertinoTextThemeData(
              primaryColor: c.blue,
              textStyle: cupertinoText.textStyle,
              actionTextStyle: cupertinoText.textStyle.copyWith(color: c.blue),
              navTitleTextStyle: cupertinoText.textStyle.copyWith(fontWeight: FontWeight.w600),
              navLargeTitleTextStyle: cupertinoText.textStyle.copyWith(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: .37),
              navActionTextStyle: cupertinoText.textStyle.copyWith(color: c.blue),
              tabLabelTextStyle: cupertinoText.textStyle.copyWith(fontSize: 10, letterSpacing: -.24, color: c.gray),
            ),
    ),
    extensions: [c],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.label, displayColor: c.label, fontFamilyFallback: _fontFallback),
    dividerColor: c.sep,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.blue, width: 1.5)),
      hintStyle: TextStyle(color: c.label3),
      labelStyle: TextStyle(color: c.label2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.card2,
      contentTextStyle: TextStyle(color: c.label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Text styles that follow Apple's type scale.
class T {
  static const largeTitle = TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: .37, height: 1.1);
  static const title1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.4);
  static const title2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.3);
  static const title3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -.2);
  static const headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -.4);
  static const body = TextStyle(fontSize: 17, letterSpacing: -.4);
  static const callout = TextStyle(fontSize: 16, letterSpacing: -.3);
  static const sub = TextStyle(fontSize: 15, letterSpacing: -.2);
  static const footnote = TextStyle(fontSize: 13, letterSpacing: -.1);
  static const caption = TextStyle(fontSize: 12);
  static const num = [FontFeature.tabularFigures()];
}
