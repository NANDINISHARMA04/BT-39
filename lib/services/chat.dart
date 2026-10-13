import 'dart:async';

import 'pulse_api.dart';

/// One fact the answer used, shown as a chip under it. [action] is the screen
/// that holds it: a patient action such as `records`, or `staff:<section>`
/// for doctors and nurses. [ref] is the patient (or demo bed) it is about.
class ChatSource {
  const ChatSource({required this.n, required this.id, required this.kind, required this.title, this.snippet = '', this.action, this.ref});
  final int n;
  final String id, kind, title, snippet;
  final String? action, ref;

  factory ChatSource.fromJson(Map<String, dynamic> j) => ChatSource(
        n: (j['n'] as num?)?.toInt() ?? 0,
        id: '${j['id'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        title: '${j['title'] ?? ''}',
        snippet: '${j['snippet'] ?? ''}',
        action: j['action'] as String?,
        ref: j['ref'] as String?,
      );
}

/// A turn of the conversation sent back with a question, so a follow-up such
/// as "and when is it?" knows what "it" is.
class ChatTurn {
  const ChatTurn(this.mine, this.text);
  final bool mine;
  final String text;
  Map<String, String> toJson() => {'role': mine ? 'user' : 'assistant', 'text': text};
}

/// What the stream of `POST /chat` says, line by line (the service's
/// docs/pulseos.md, section 10).
sealed class ChatEvent {
  const ChatEvent();
}

/// The first line, before any work: is it urgent, which button to show.
class ChatMeta extends ChatEvent {
  const ChatMeta({this.urgent = false, this.action, this.actionLabel, this.suggestions = const [], this.intent});
  final bool urgent;
  final String? action;

  /// A message (see msg.dart), rendered when shown.
  final Object? actionLabel;
  final List<String> suggestions;
  final String? intent;
}

/// Words of the answer as the model writes them (or the whole answer from the cache).
class ChatDeltaText extends ChatEvent {
  const ChatDeltaText(this.text);
  final String text;
}

/// The free answer, as one message, when the model was not asked.
class ChatFreeAnswer extends ChatEvent {
  const ChatFreeAnswer(this.message);
  final Object? message;
}

/// The model stopped half way. The words already shown stay.
class ChatCutOff extends ChatEvent {
  const ChatCutOff(this.message);
  final String message;
}

/// The last line.
class ChatEnd extends ChatEvent {
  const ChatEnd({this.sources = const [], this.cached, this.fallback, this.tokens = 0, this.cost = 0, this.ms = 0, this.action, this.actionLabel});
  final List<ChatSource> sources;

  /// null, `exact` or `near`: answered from the cache, for free.
  final String? cached;

  /// null when the model wrote the answer; otherwise why it did not
  /// (`budget`, `cap`, `no_key`, `model_error`, `cut_off`, `error`).
  final String? fallback;
  final int tokens, ms;
  final double cost;
  final String? action;
  final Object? actionLabel;
}

/// The PulseOS chat: patients ask about their own records and the app;
/// doctors and nurses about the patients they can see ([focus] narrows it to
/// one patient or one demo bed).
class PulseChat {
  PulseChat(this.api);
  final PulseApi api;

  /// Sent when a chat opens, so the service has the caller's facts ready and
  /// the first answer does not wait. Never throws.
  Future<void> prepare({String? focus}) async {
    try {
      await api.post('/chat/prepare', {'focus': ?focus});
    } catch (_) {}
  }

  /// Asks one question. The stream ends after [ChatEnd]; it fails with an
  /// [ApiException] when the service refuses the question (a 422 sentence, a
  /// 429, an expired demo) and with another error when it cannot be reached.
  /// Cancelling the subscription closes the connection.
  Stream<ChatEvent> ask(String q, {String? focus, List<ChatTurn> history = const []}) {
    final client = api.newClient();
    late final StreamController<ChatEvent> out;
    StreamSubscription<Map<String, dynamic>>? sub;
    out = StreamController<ChatEvent>(
      onListen: () {
        final body = {'q': q, 'focus': ?focus, if (history.isNotEmpty) 'history': [for (final t in history) t.toJson()]};
        sub = api.lines('/chat', client, method: 'POST', body: body).listen(
          (line) {
            final e = parse(line);
            if (e != null) out.add(e);
            if (e is ChatEnd) {
              sub?.cancel();
              client.close();
              out.close();
            }
          },
          onError: (Object e, StackTrace s) {
            out.addError(e, s);
            client.close();
            out.close();
          },
          onDone: () {
            client.close();
            if (!out.isClosed) out.close();
          },
          cancelOnError: true,
        );
      },
      // Not awaited: a stream delivers its "done" only after this returns, and closing the connection must not hold
      // the end of an answer back.
      onCancel: () {
        unawaited(sub?.cancel());
        client.close();
      },
    );
    return out.stream;
  }

  /// One stream line as an event; null for a line this app does not know.
  static ChatEvent? parse(Map<String, dynamic> j) {
    List<String> strings(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];
    return switch (j['type']) {
      'meta' => ChatMeta(urgent: j['urgent'] == true, action: j['action'] as String?, actionLabel: j['action_label'], suggestions: strings(j['suggestions']), intent: j['intent'] as String?),
      'delta' => ChatDeltaText('${j['text'] ?? ''}'),
      'answer' => ChatFreeAnswer(j['msg']),
      'error' => ChatCutOff('${j['message'] ?? ''}'),
      'done' => ChatEnd(
          sources: [for (final s in (j['sources'] as List? ?? const [])) if (s is Map) ChatSource.fromJson(Map<String, dynamic>.from(s))],
          cached: j['cached'] as String?,
          fallback: j['fallback'] as String?,
          tokens: (j['tokens'] as num?)?.toInt() ?? 0,
          cost: (j['cost'] as num?)?.toDouble() ?? 0,
          ms: (j['ms'] as num?)?.toInt() ?? 0,
          action: j['action'] as String?,
          actionLabel: j['action_label'],
        ),
      _ => null,
    };
  }
}
