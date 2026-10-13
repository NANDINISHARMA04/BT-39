import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../l10n/msg.dart';
import 'chat.dart';
import 'pulse_api.dart';

/// Where a message is on its way.
enum ChatState {
  /// Mine: on its way to the service. Theirs: waiting for the first word (typing dots).
  sending,

  /// Mine: the service has it (the first line of the answer came back).
  delivered,

  /// Theirs: words are arriving.
  streaming,

  /// Theirs: complete.
  done,

  /// Mine: the service could not be reached or refused it. Theirs: it broke off.
  failed,
}

/// One bubble.
class ChatMessage {
  ChatMessage._(this.id, this.mine, this.text, this.state, {this.isGreeting = false}) : at = DateTime.now();
  ChatMessage.mine(int id, String text) : this._(id, true, text, ChatState.sending);
  ChatMessage.theirs(int id) : this._(id, false, '', ChatState.sending);

  /// A message that is already there when the chat opens (the greeting). It is never sent back as history.
  ChatMessage.greeting(int id, String text) : this._(id, false, text, ChatState.done, isGreeting: true);

  final int id;
  final bool mine, isGreeting;
  final DateTime at;
  ChatState state;

  /// The words: the question, or the answer as it streams in.
  String text;

  /// The free answer, a message rendered in the app's language when shown.
  Object? message;

  bool urgent = false;
  String? action;
  Object? actionLabel;
  List<String> suggestions = const [];
  List<ChatSource> sources = const [];

  /// `exact` or `near` when it came from the cache.
  String? cached;

  /// Why the model did not write it (see [ChatEnd.fallback]).
  String? fallback;

  /// A sentence to show under the bubble when something went wrong.
  String? problem;

  /// What the bubble shows now.
  String get shown => message != null ? msg(message) : text;

  bool get waiting => !mine && state == ChatState.sending;
}

/// Moments the screen reacts to with a haptic, a sound or a scroll.
enum ChatBeat { sent, firstWord, finished, urgent, failed }

/// The conversation of one chat screen (the view model): it sends questions,
/// follows each answer's stream and keeps the bubbles. The screen draws them
/// and turns [beats] into haptics and read-aloud.
class ChatController extends ChangeNotifier {
  ChatController(this.chat, {this.focus, String? greeting}) {
    if (greeting != null) messages.add(ChatMessage.greeting(_id++, greeting));
  }

  final PulseChat chat;

  /// Doctors and nurses: the patient or demo bed the chat is about.
  final String? focus;

  final messages = <ChatMessage>[];
  final _beats = StreamController<ChatBeat>.broadcast();
  StreamSubscription<ChatEvent>? _sub;
  int _id = 0;
  bool _disposed = false;

  Stream<ChatBeat> get beats => _beats.stream;

  /// True while an answer is on its way: one question at a time.
  bool get busy => _sub != null;

  /// Warms the service up for this chat. Call once when the screen opens.
  void prepare() => unawaited(chat.prepare(focus: focus));

  /// The turns sent with a question: the last four that are complete.
  List<ChatTurn> _history() {
    final done = [
      for (final m in messages)
        if ((m.mine && m.state == ChatState.delivered) || (!m.mine && m.state == ChatState.done && !m.isGreeting && m.shown.isNotEmpty)) ChatTurn(m.mine, m.shown),
    ];
    return done.length <= 4 ? done : done.sublist(done.length - 4);
  }

  /// Sends [question]. Ignored when it is blank or an answer is still coming.
  Future<void> send(String question) async {
    final q = question.trim();
    if (q.isEmpty || busy || _disposed) return;
    final history = _history();
    final mine = ChatMessage.mine(_id++, q);
    messages.add(mine);
    _beat(ChatBeat.sent);
    _notify();
    await _ask(mine, history);
  }

  /// Sends a question that failed again.
  Future<void> retry(ChatMessage failed) async {
    if (!failed.mine || failed.state != ChatState.failed || busy) return;
    messages.remove(failed);
    await send(failed.text);
  }

  Future<void> _ask(ChatMessage mine, List<ChatTurn> history) async {
    final reply = ChatMessage.theirs(_id++);
    messages.add(reply);
    _notify();
    final finished = Completer<void>();
    var first = true;
    void end() {
      _sub = null;
      if (!finished.isCompleted) finished.complete();
      _notify();
    }

    _sub = chat.ask(mine.text, focus: focus, history: history).listen(
      (e) {
        switch (e) {
          case ChatMeta m:
            mine.state = ChatState.delivered;
            reply
              ..urgent = m.urgent
              ..action = m.action
              ..actionLabel = m.actionLabel
              ..suggestions = m.suggestions;
            if (m.urgent) _beat(ChatBeat.urgent);
          case ChatDeltaText d:
            if (first) {
              first = false;
              _beat(ChatBeat.firstWord);
            }
            reply
              ..state = ChatState.streaming
              ..text += d.text;
          case ChatFreeAnswer a:
            if (first) {
              first = false;
              _beat(ChatBeat.firstWord);
            }
            reply
              ..state = ChatState.streaming
              ..message = a.message;
          case ChatCutOff c:
            reply.problem = c.message.isEmpty ? tr('The assistant could not finish that answer. Please ask again.') : trData(c.message);
          case ChatEnd d:
            reply
              ..state = reply.problem != null && reply.shown.isEmpty ? ChatState.failed : ChatState.done
              ..sources = d.sources
              ..cached = d.cached
              ..fallback = d.fallback;
            if (d.action != null && reply.action == null) {
              reply
                ..action = d.action
                ..actionLabel = d.actionLabel;
            }
            if (mine.state == ChatState.sending) mine.state = ChatState.delivered;
            _beat(ChatBeat.finished);
        }
        _notify();
      },
      onError: (Object err, StackTrace _) {
        if (mine.state == ChatState.sending) {
          // Nothing came back: the question did not get through. iMessage-style "Not delivered", tap to try again.
          mine
            ..state = ChatState.failed
            ..problem = err is ApiException ? (err.message ?? tr('Not delivered')) : tr('Not delivered. Check your connection and tap to try again.');
          messages.remove(reply);
        } else {
          reply
            ..state = reply.shown.isEmpty ? ChatState.failed : ChatState.done
            ..problem = tr('The answer was cut off. Please ask again.');
        }
        _beat(ChatBeat.failed);
        end();
      },
      onDone: () {
        if (mine.state == ChatState.sending) {
          // The connection ended before the service said anything: the question did not get through.
          mine
            ..state = ChatState.failed
            ..problem = tr('Not delivered. Check your connection and tap to try again.');
          messages.remove(reply);
          _beat(ChatBeat.failed);
        } else if (reply.state == ChatState.sending || reply.state == ChatState.streaming) {
          // The stream ended without its last line.
          reply
            ..state = reply.shown.isEmpty ? ChatState.failed : ChatState.done
            ..problem = reply.shown.isEmpty ? tr('The answer was cut off. Please ask again.') : null;
        }
        end();
      },
      cancelOnError: true,
    );
    return finished.future;
  }

  void _beat(ChatBeat b) {
    if (!_beats.isClosed) _beats.add(b);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _sub = null;
    _beats.close();
    super.dispose();
  }
}
