import '../l10n/l10n.dart';
import 'speech/speech_stub.dart' if (dart.library.js_interop) 'speech/speech_web.dart' as impl;

/// Reads text aloud and listens to the person, in the app's language, with
/// the browser's built-in speech services (no server, no API key). Used by
/// the help assistant and the accessibility options. On platforms without
/// them it does nothing, and [canListen] is false.
class Speech {
  Speech._();
  static final instance = Speech._();

  String get _lang => appLang.value == 'hi' ? 'hi-IN' : 'en-IN';

  bool get canSpeak => impl.canSpeak();
  bool get canListen => impl.canListen();

  void speak(String text) => impl.speak(text, _lang);

  void stopSpeaking() => impl.stopSpeaking();

  /// Listens once. [onText] gets the words heard so far ([done] on the last
  /// call); [onEnd] runs when listening stops for any reason.
  void listen({required void Function(String text, bool done) onText, required void Function() onEnd}) => impl.listen(_lang, onText, onEnd);

  void stopListening() => impl.stopListening();
}
