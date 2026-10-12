import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool canSpeak() {
  try {
    return globalContext.has('speechSynthesis');
  } catch (_) {
    return false;
  }
}

JSFunction? get _recognitionClass {
  try {
    final g = globalContext;
    if (g.has('SpeechRecognition')) return g['SpeechRecognition'] as JSFunction;
    if (g.has('webkitSpeechRecognition')) return g['webkitSpeechRecognition'] as JSFunction;
  } catch (_) {}
  return null;
}

bool canListen() => _recognitionClass != null;

/// The clearest installed voice for [lang]: an exact match first, preferring
/// natural-sounding ones.
web.SpeechSynthesisVoice? _voice(String lang) {
  try {
    final voices = web.window.speechSynthesis.getVoices().toDart;
    final base = lang.split('-').first;
    web.SpeechSynthesisVoice? best;
    var bestScore = -1;
    for (final v in voices) {
      final l = v.lang.toLowerCase().replaceAll('_', '-');
      final n = v.name.toLowerCase();
      if (!l.startsWith(base)) continue;
      var s = l == lang.toLowerCase() ? 50 : 20;
      if (n.contains('google') || n.contains('natural') || n.contains('premium') || n.contains('enhanced') || n.contains('neural')) s += 20;
      if (s > bestScore) {
        bestScore = s;
        best = v;
      }
    }
    return best;
  } catch (_) {
    return null;
  }
}

void speak(String text, String lang) {
  try {
    final s = web.window.speechSynthesis;
    s.cancel();
    final u = web.SpeechSynthesisUtterance(text)
      ..lang = lang
      ..rate = .95;
    final v = _voice(lang);
    if (v != null) u.voice = v;
    s.speak(u);
  } catch (_) {}
}

void stopSpeaking() {
  try {
    web.window.speechSynthesis.cancel();
  } catch (_) {}
}

JSObject? _rec;

void listen(String lang, void Function(String text, bool done) onText, void Function() onEnd) {
  final cls = _recognitionClass;
  if (cls == null) {
    onEnd();
    return;
  }
  try {
    stopListening();
    final rec = cls.callAsConstructor<JSObject>();
    _rec = rec;
    rec['lang'] = lang.toJS;
    rec['interimResults'] = true.toJS;
    rec['continuous'] = false.toJS;
    rec['maxAlternatives'] = 1.toJS;
    rec['onresult'] = ((JSObject e) {
      final results = e['results'] as JSObject;
      final n = (results['length'] as JSNumber).toDartInt;
      final buf = StringBuffer();
      var done = false;
      for (var i = 0; i < n; i++) {
        final r = results.callMethod<JSObject>('item'.toJS, i.toJS);
        final alt = r.callMethod<JSObject>('item'.toJS, 0.toJS);
        buf.write((alt['transcript'] as JSString).toDart);
        done = (r['isFinal'] as JSBoolean).toDart;
      }
      onText(buf.toString().trim(), done);
    }).toJS;
    rec['onend'] = ((JSObject _) {
      if (identical(_rec, rec)) _rec = null;
      onEnd();
    }).toJS;
    rec['onerror'] = ((JSObject _) {}).toJS;
    rec.callMethod<JSAny?>('start'.toJS);
  } catch (_) {
    _rec = null;
    onEnd();
  }
}

void stopListening() {
  final rec = _rec;
  _rec = null;
  try {
    rec?.callMethod<JSAny?>('stop'.toJS);
  } catch (_) {}
}
