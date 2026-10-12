import 'dart:js_interop';

import 'package:web/web.dart' as web;

var _gen = 0;
var _speaking = false;
web.SpeechSynthesisVoice? _voice;

/// Prefers an Indian English voice, then other natural-sounding English ones.
void _pickVoice() {
  if (_voice != null) return;
  try {
    final voices = web.window.speechSynthesis.getVoices().toDart;
    var best = -1;
    for (final v in voices) {
      final lang = v.lang.toLowerCase().replaceAll('_', '-');
      final name = v.name.toLowerCase();
      if (!lang.startsWith('en')) continue;
      var s = lang == 'en-in' ? 50 : lang == 'en-gb' ? 30 : 20;
      if (name.contains('google') || name.contains('natural') || name.contains('premium') || name.contains('enhanced')) s += 15;
      if (name.contains('veena') || name.contains('heera') || name.contains('samantha') || name.contains('female') || name.contains('zira')) s += 10;
      if (s > best) {
        best = s;
        _voice = v;
      }
    }
  } catch (_) {}
}

void unlock() {
  try {
    final s = web.window.speechSynthesis;
    final u = web.SpeechSynthesisUtterance(' ')..volume = 0;
    s.speak(u);
    _pickVoice();
  } catch (_) {}
}

void speak(String text) {
  try {
    final s = web.window.speechSynthesis;
    s.cancel();
    _pickVoice();
    final gen = ++_gen;
    final u = web.SpeechSynthesisUtterance(text)
      ..rate = 1.0
      ..pitch = 1.0;
    final v = _voice;
    if (v != null) {
      u.voice = v;
      u.lang = v.lang;
    } else {
      u.lang = 'en-IN';
    }
    void done(web.Event _) {
      if (gen == _gen) _speaking = false;
    }

    u.onend = done.toJS;
    u.onerror = done.toJS;
    _speaking = true;
    s.speak(u);
  } catch (_) {
    _speaking = false;
  }
}

void cancel() {
  _gen++;
  _speaking = false;
  try {
    web.window.speechSynthesis.cancel();
  } catch (_) {}
}

bool speaking() => _speaking;
