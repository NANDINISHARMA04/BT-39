import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Options that make PulseOS easier to use for older people and people with
/// a disability. Saved on the device (not per account), so they also apply
/// on the welcome page and in the staff app.
class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings({bool autoLoad = true}) {
    if (autoLoad) ready = load();
  }

  /// Completes when the saved settings have been read.
  Future<void> ready = Future.value();

  static const normal = 1.0, large = 1.2, extraLarge = 1.4;
  static const textSizes = [normal, large, extraLarge];

  static const _k = 'bt39.a11y.';

  double textSize = normal;
  bool boldText = false;

  /// A simpler Today page with big words and big buttons.
  bool easyHome = false;

  /// For deaf or hard-of-hearing people: the screen flashes and the alert
  /// banner stays until it is tapped, and the phone vibrates.
  bool flashAlerts = false;

  /// For blind or low-vision people: new alerts are read aloud.
  bool speakAlerts = false;
  bool reduceMotion = false;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final size = p.getDouble('${_k}textSize');
      if (size != null && textSizes.contains(size)) textSize = size;
      boldText = p.getBool('${_k}boldText') ?? false;
      easyHome = p.getBool('${_k}easyHome') ?? false;
      flashAlerts = p.getBool('${_k}flashAlerts') ?? false;
      speakAlerts = p.getBool('${_k}speakAlerts') ?? false;
      reduceMotion = p.getBool('${_k}reduceMotion') ?? false;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save(String key, Object value) async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      if (value is double) {
        await p.setDouble('$_k$key', value);
      } else if (value is bool) {
        await p.setBool('$_k$key', value);
      }
    } catch (_) {}
  }

  Future<void> setTextSize(double v) {
    textSize = v;
    return _save('textSize', v);
  }

  Future<void> setBoldText(bool v) {
    boldText = v;
    return _save('boldText', v);
  }

  Future<void> setEasyHome(bool v) {
    easyHome = v;
    return _save('easyHome', v);
  }

  Future<void> setFlashAlerts(bool v) {
    flashAlerts = v;
    return _save('flashAlerts', v);
  }

  Future<void> setSpeakAlerts(bool v) {
    speakAlerts = v;
    return _save('speakAlerts', v);
  }

  Future<void> setReduceMotion(bool v) {
    reduceMotion = v;
    return _save('reduceMotion', v);
  }

  /// Applies text size, bold text and reduced motion on top of the device's
  /// own settings.
  MediaQueryData apply(MediaQueryData mq) {
    final base = mq.textScaler.scale(16) / 16;
    return mq.copyWith(
      textScaler: textSize == normal ? mq.textScaler : TextScaler.linear(base * textSize),
      boldText: mq.boldText || boldText,
      disableAnimations: mq.disableAnimations || reduceMotion,
    );
  }
}

/// Puts the [AccessibilitySettings] into the [MediaQuery] of everything below.
class AccessibleMediaQuery extends StatelessWidget {
  const AccessibleMediaQuery({super.key, required this.settings, required this.child});
  final AccessibilitySettings settings;
  final Widget child;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MediaQuery(data: settings.apply(MediaQuery.of(context)), child: child),
      );
}
