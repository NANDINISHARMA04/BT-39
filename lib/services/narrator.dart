import 'narrator/narrator_stub.dart' if (dart.library.js_interop) 'narrator/narrator_web.dart' as impl;

/// Reads the guided demo aloud with the browser's built-in voice.
///
/// Uses the Web Speech API, so it needs no server or API key. On platforms
/// without it (tests, phones running the native app) it stays silent.
class Narrator {
  Narrator._();
  static final instance = Narrator._();

  bool muted = false;

  bool get speaking => !muted && impl.speaking();

  /// Call from a button tap: browsers only allow speech after a user gesture.
  void unlock() => impl.unlock();

  void say(String text) {
    if (muted) return;
    impl.speak(text
        .replaceAll('AdaptAlert', 'Adapt Alert')
        .replaceAll('PulseOS', 'Pulse O.S.')
        .replaceAll('Dr. ', 'Doctor ')
        .replaceAll('%', ' percent'));
  }

  void stop() => impl.cancel();

  void setMuted(bool m) {
    muted = m;
    if (m) impl.cancel();
  }
}
