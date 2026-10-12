import '../l10n/l10n.dart';
import 'narrator/narrator_stub.dart' if (dart.library.js_interop) 'narrator/narrator_web.dart' as impl;

/// Plays the guided demo's voice-over in the app's language.
///
/// The voice-over is recorded ahead of time (assets/voice/LANG/NN.mp3, made
/// with the Kokoro text-to-speech model), so it sounds the same in every
/// browser. On platforms without web audio (tests, the native app) it stays
/// silent.
class Narrator {
  Narrator._();
  static final instance = Narrator._();

  bool muted = false;

  bool get speaking => !muted && impl.playing();

  /// Call from a button tap: browsers only allow sound after a user gesture.
  void unlock() => impl.unlock('assets/assets/voice/silence.mp3');

  /// Plays the voice-over for demo step [n] (1-based).
  void playStep(int n) {
    if (muted) return;
    impl.play('assets/assets/voice/${appLang.value}/${n.toString().padLeft(2, '0')}.mp3');
  }

  void stop() => impl.stop();

  void setMuted(bool m) {
    muted = m;
    if (m) impl.stop();
  }
}
