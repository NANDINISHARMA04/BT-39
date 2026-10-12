import 'dart:js_interop';

import 'package:web/web.dart' as web;

// One audio element for the whole demo: once it has played during a tap,
// browsers (Safari on iPhone included) let it play again later.
final _audio = web.HTMLAudioElement()..preload = 'auto';
var _gen = 0;
var _playing = false;

void unlock(String silentUrl) {
  try {
    _audio.src = silentUrl;
    _audio.play();
  } catch (_) {}
}

void play(String url) {
  final gen = ++_gen;
  void done(web.Event _) {
    if (gen == _gen) _playing = false;
  }

  try {
    _audio.pause();
    _audio.onended = done.toJS;
    _audio.onerror = done.toJS;
    _audio.src = url;
    _playing = true;
    _audio.play().toDart.catchError((Object _) {
      if (gen == _gen) _playing = false;
      return null;
    });
  } catch (_) {
    _playing = false;
  }
}

void stop() {
  _gen++;
  _playing = false;
  try {
    _audio.pause();
  } catch (_) {}
}

bool playing() => _playing;
