import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../l10n/msg.dart';
import '../../services/chat.dart';
import '../../services/chat_controller.dart';
import '../../services/speech.dart';
import '../../theme/ios_theme.dart';
import '../common.dart';
import 'bubble.dart';

/// An iMessage-style conversation: the newest message at the bottom, bubbles
/// grouped with a tail on the last of each group, typing dots while the answer
/// is on its way, words that type themselves in, sources and buttons that
/// arrive under a finished answer, "Delivered" and a red "Not delivered" you
/// can tap to send again. Haptics mark sending, the first word, an urgent
/// answer and a failure. Everything holds still with reduced motion.
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.controller,
    this.header,
    this.starters = const [],
    this.placeholder,
    this.onAction,
    this.onSource,
    this.voice = false,
    this.onAnswered,
    this.large = false,
  });

  final ChatController controller;

  /// Shown above the first message (help topics, an intro).
  final Widget? header;

  /// Questions offered above the box (English keys, shown and sent with tr()).
  final List<String> starters;
  final String? placeholder;

  /// A reply's button was tapped: the action it carries.
  final void Function(String action)? onAction;

  /// A source chip or a citation was tapped.
  final void Function(ChatSource source)? onSource;

  /// Offer the microphone (when the device can listen).
  final bool voice;

  /// An answer finished (to read it aloud).
  final void Function(ChatMessage reply)? onAnswered;

  /// Bigger text, for the patient app.
  final bool large;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _timeShown = <int>{};
  StreamSubscription<ChatBeat>? _beats;
  bool _away = false; // scrolled up, away from the newest message
  bool _listening = false;

  ChatController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _beats = _c.beats.listen(_beat);
    _input.addListener(() => setState(() {}));
    _scroll.addListener(() {
      final away = _scroll.hasClients && _c.messages.any((m) => !m.isGreeting) && _scroll.offset > 160;
      if (away != _away) setState(() => _away = away);
    });
  }

  @override
  void didUpdateWidget(ChatView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      _beats?.cancel();
      _c.addListener(_changed);
      _beats = _c.beats.listen(_beat);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _beats?.cancel();
    if (_listening) Speech.instance.stopListening();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _beat(ChatBeat b) {
    switch (b) {
      case ChatBeat.sent:
        HapticFeedback.lightImpact();
        _toLatest();
      case ChatBeat.firstWord:
        HapticFeedback.selectionClick();
      case ChatBeat.urgent:
        HapticFeedback.heavyImpact();
      case ChatBeat.failed:
        HapticFeedback.mediumImpact();
      case ChatBeat.finished:
        final reply = _c.messages.lastWhere((m) => !m.mine, orElse: () => _c.messages.last);
        if (!reply.mine) widget.onAnswered?.call(reply);
    }
  }

  void _toLatest() {
    if (!_scroll.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  void _send([String? text]) {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty || _c.busy) return;
    if (text == null) _input.clear();
    Speech.instance.stopSpeaking();
    _c.send(q);
  }

  void _listen() {
    if (_listening) {
      Speech.instance.stopListening();
      return;
    }
    Speech.instance.stopSpeaking();
    setState(() {
      _listening = true;
      _input.clear();
    });
    var sent = false;
    void finish(String text) {
      if (sent) return;
      sent = true;
      if (mounted) setState(() => _listening = false);
      if (mounted && text.trim().isNotEmpty) {
        _input.clear();
        _send(text);
      }
    }

    Speech.instance.listen(
      onText: (text, done) {
        if (!mounted) return;
        setState(() => _input.text = text);
        if (done) finish(text);
      },
      onEnd: () {
        if (!mounted) return;
        if (!sent) {
          finish(_input.text);
        } else {
          setState(() => _listening = false);
        }
      },
    );
  }

  void _copy(ChatMessage m) {
    final text = m.mine ? m.text : plainChatText(m.shown);
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    toast(context, tr('Copied'));
  }

  ChatSource? _source(ChatMessage m, int n) => m.sources.where((s) => s.n == n).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final msgs = _c.messages;
    final head = widget.header == null ? 0 : 1;
    final count = msgs.length + head;
    // Before the first question the list reads from the top (the intro and the topics). Once there is a conversation
    // it is anchored at the bottom: the newest message sits there and a growing answer keeps it in view.
    final talking = msgs.any((m) => !m.isGreeting);
    return Column(children: [
      Expanded(
        child: Stack(children: [
          ListView.builder(
            key: ValueKey(talking),
            controller: _scroll,
            reverse: talking,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            itemCount: count,
            itemBuilder: (_, i) {
              if (!talking) return head == 1 && i == 0 ? widget.header! : _row(context, i - head);
              if (i == msgs.length) return widget.header!;
              return _row(context, msgs.length - 1 - i);
            },
          ),
          Positioned(
            right: 14,
            bottom: 10,
            child: IgnorePointer(
              ignoring: !_away,
              child: AnimatedScale(
                scale: _away ? 1 : .6,
                duration: Motion.base,
                curve: Motion.spring,
                child: AnimatedOpacity(
                  opacity: _away ? 1 : 0,
                  duration: Motion.quick,
                  child: Semantics(
                    button: true,
                    label: tr('Go to the latest message'),
                    child: Pressable(
                      onTap: _toLatest,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, border: Border.all(color: c.sep), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 10, offset: const Offset(0, 3))]),
                        child: Icon(CupertinoIcons.chevron_down, size: 18, color: c.blue),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
      if (widget.starters.isNotEmpty)
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final s in widget.starters)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 6, top: 2),
                child: _Capsule(label: tr(s), onTap: _c.busy ? null : () => _send(tr(s))),
              ),
          ]),
        ),
      _composer(context),
    ]);
  }

  // -- one message ---------------------------------------------------------------------------------------------------

  Widget _row(BuildContext context, int k) {
    final c = context.ios;
    final msgs = _c.messages;
    final m = msgs[k];
    final next = k + 1 < msgs.length ? msgs[k + 1] : null;
    final prev = k > 0 ? msgs[k - 1] : null;
    final grouped = next != null && next.mine == m.mine && next.at.difference(m.at).inMinutes < 2;
    final showHead = prev == null || m.at.difference(prev.at).inMinutes >= 10;
    final fresh = DateTime.now().difference(m.at).inMilliseconds < 1500;
    final lastMine = m.mine && !msgs.skip(k + 1).any((x) => x.mine);
    final maxW = MediaQuery.sizeOf(context).width * (widget.large ? .82 : .78);
    final style = TextStyle(fontSize: widget.large ? 18 : 16.5, height: 1.36, letterSpacing: -.3, color: m.mine ? Colors.white : c.label);

    Widget bubble;
    if (m.waiting) {
      bubble = const TypingBubble();
    } else {
      final urgent = !m.mine && m.urgent;
      final color = m.mine ? (m.state == ChatState.failed ? c.blue.withValues(alpha: .55) : c.blue) : (urgent ? Color.alphaBlend(c.red.withValues(alpha: .16), c.card) : incomingBubble(c));
      final body = m.mine
          ? Text(m.text, style: style)
          : RevealText(
              text: m.shown,
              live: m.state == ChatState.streaming,
              builder: (shown, fadeFrom) => Text.rich(chatSpans(context, shown, style, fadeFrom: fadeFrom, citeColor: urgent ? c.red : null, onCite: (n) {
                final s = _source(m, n);
                if (s != null) widget.onSource?.call(s);
              })),
            );
      bubble = Semantics(
        label: m.mine ? tr('You said') : tr('Assistant said'),
        liveRegion: !m.mine && m.state == ChatState.done,
        child: GestureDetector(
          onTap: () => setState(() => _timeShown.contains(m.id) ? _timeShown.remove(m.id) : _timeShown.add(m.id)),
          onLongPress: () => _copy(m),
          child: Bubble(
            color: color,
            mine: m.mine,
            tail: !grouped,
            border: urgent ? c.red : null,
            child: AnimatedSize(duration: const Duration(milliseconds: 160), curve: Curves.easeOut, alignment: Alignment.topLeft, child: body),
          ),
        ),
      );
    }
    if (fresh) bubble = PopIn(key: ValueKey('pop${m.id}${m.waiting}'), fromRight: m.mine, child: bubble);

    final under = <Widget>[];
    if (m.mine && m.state == ChatState.failed) {
      under.add(Pressable(
        onTap: () => _c.retry(m),
        child: Padding(
          padding: const EdgeInsets.only(top: 3, right: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(m.problem ?? tr('Not delivered'), textAlign: TextAlign.right, style: T.caption.copyWith(color: c.red, fontWeight: FontWeight.w600))),
            const SizedBox(width: 4),
            Text(tr('Tap to try again'), style: T.caption.copyWith(color: c.label2)),
          ]),
        ),
      ));
    } else if (lastMine && m.state == ChatState.delivered) {
      under.add(Arrive(child: Padding(padding: const EdgeInsets.only(top: 3, right: 6), child: Text(tr('Delivered'), style: T.caption.copyWith(color: c.label2, fontWeight: FontWeight.w500)))));
    }
    if (!m.mine) under.addAll(_afterAnswer(context, m, k));

    final failedMark = m.mine && m.state == ChatState.failed
        ? Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Semantics(
              button: true,
              label: tr('Not delivered. Tap to try again.'),
              child: Pressable(onTap: () => _c.retry(m), child: Icon(CupertinoIcons.exclamationmark_circle_fill, color: c.red, size: 24)),
            ),
          )
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: grouped ? 2 : 10),
      child: Column(crossAxisAlignment: m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        if (showHead)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Center(child: Text(_when(m.at), style: T.caption.copyWith(color: c.label2, fontWeight: FontWeight.w500))),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: _timeShown.contains(m.id) ? Padding(padding: const EdgeInsets.only(bottom: 3, left: 8, right: 8), child: Text(DateFormat.jm().format(m.at), style: T.caption.copyWith(color: c.label3))) : const SizedBox(width: double.infinity),
        ),
        Row(mainAxisAlignment: m.mine ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.center, children: [
          ConstrainedBox(constraints: BoxConstraints(maxWidth: maxW), child: bubble),
          ?failedMark,
        ]),
        ...under,
      ]),
    );
  }

  String _when(DateTime at) {
    final now = DateTime.now();
    final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
    return sameDay ? '${tr('Today')} ${DateFormat.jm().format(at)}' : DateFormat('EEE d MMM, h:mm a').format(at);
  }

  /// What arrives under an answer: a warning, the button, the sources, the follow-up questions.
  List<Widget> _afterAnswer(BuildContext context, ChatMessage m, int k) {
    final c = context.ios;
    final out = <Widget>[];
    final done = m.state == ChatState.done || m.state == ChatState.failed;
    if (m.problem != null) {
      out.add(Arrive(
        child: Padding(
          padding: const EdgeInsets.only(top: 4, left: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 14, color: c.orange),
            const SizedBox(width: 5),
            Flexible(child: Text(m.problem!, style: T.caption.copyWith(color: c.label2))),
          ]),
        ),
      ));
      final question = _c.messages.take(k).lastWhere((x) => x.mine, orElse: () => m);
      if (question.mine && done) {
        out.add(Padding(padding: const EdgeInsets.only(top: 6, left: 8), child: _Capsule(label: tr('Ask again'), icon: CupertinoIcons.arrow_clockwise, onTap: _c.busy ? null : () => _send(question.text))));
      }
    }
    if (done && m.fallback != null && m.fallback != 'cut_off') {
      out.add(Arrive(
        child: Padding(
          padding: const EdgeInsets.only(top: 4, left: 10),
          child: GestureDetector(
            onTap: () => toast(context, tr('Quick answer'), tr('The AI is resting right now, so this answer comes straight from your data, for free.')),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(CupertinoIcons.bolt_fill, size: 12, color: c.label3),
              const SizedBox(width: 4),
              Text(tr('Quick answer'), style: T.caption.copyWith(color: c.label3)),
            ]),
          ),
        ),
      ));
    }
    // An urgent answer shows its button at once, before the words: that is the point of being urgent.
    if (m.action != null && (done || m.urgent) && widget.onAction != null) {
      final label = m.actionLabel == null ? tr('Open') : msg(m.actionLabel);
      out.add(Arrive(
        delay: m.urgent ? 0 : 80,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, left: 6),
          child: AppButton(label, icon: CupertinoIcons.arrow_right_circle_fill, size: widget.large ? ButtonSize.medium : ButtonSize.small, color: m.urgent ? c.red : c.blue, onTap: () => widget.onAction!(m.action!)),
        ),
      ));
    }
    if (done && m.sources.isNotEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 8, left: 6),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (i, s) in m.sources.indexed) Arrive(delay: 120 + i * 60, child: _SourceChip(source: s, onTap: widget.onSource == null ? null : () => widget.onSource!(s))),
        ]),
      ));
    }
    if (done && m.suggestions.isNotEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 8, left: 6),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, s) in m.suggestions.indexed) Arrive(delay: 200 + i * 60, child: _Capsule(label: tr(s), onTap: _c.busy ? null : () => _send(tr(s)))),
        ]),
      ));
    }
    return out;
  }

  // -- the box -----------------------------------------------------------------------------------------------------

  Widget _composer(BuildContext context) {
    final c = context.ios;
    final canListen = widget.voice && Speech.instance.canListen;
    final hasText = _input.text.trim().isNotEmpty;
    final busy = _c.busy;
    final fontSize = widget.large ? 18.0 : 17.0;
    final trailing = hasText
        ? Semantics(
            key: const ValueKey('send'),
            button: true,
            label: tr('Send'),
            child: Pressable(
              onTap: busy ? null : () => _send(),
              scale: .85,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: busy ? c.gray : c.blue, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 19),
              ),
            ),
          )
        : canListen
            ? Semantics(
                key: const ValueKey('mic'),
                button: true,
                label: _listening ? tr('Stop listening') : tr('Speak your question'),
                child: Pressable(
                  onTap: _listen,
                  scale: .85,
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: _listening ? c.red : Colors.transparent, shape: BoxShape.circle),
                    child: Icon(_listening ? CupertinoIcons.stop_fill : CupertinoIcons.mic_fill, color: _listening ? Colors.white : c.label2, size: 20),
                  ),
                ),
              )
            : const SizedBox(key: ValueKey('none'), width: 8, height: 40);
    return Glass(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_listening)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Row(children: [
                    Icon(CupertinoIcons.waveform, color: c.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr('Listening… speak now'), style: T.headline.copyWith(color: c.red))),
                  ]),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(R.lg),
                border: Border.all(color: _listening ? c.red : (_focus.hasFocus ? c.blue.withValues(alpha: .5) : c.sep), width: _listening ? 2 : 1),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _input,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    placeholder: _listening ? tr('Listening…') : (widget.placeholder ?? tr('Message')),
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    decoration: null,
                    style: TextStyle(fontSize: fontSize, color: c.label, height: 1.25),
                    placeholderStyle: TextStyle(fontSize: fontSize, color: c.label3),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    onTap: () => setState(() {}),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
                  child: trailing,
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A question to ask, as a tinted capsule.
class _Capsule extends StatelessWidget {
  const _Capsule({required this.label, this.onTap, this.icon});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => AppChip(label, icon: icon, tinted: true, large: true, enabled: onTap != null, onTap: onTap);
}

IconData _kindIcon(String kind) => switch (kind) {
      'medication' => CupertinoIcons.capsule_fill,
      'appointment' => CupertinoIcons.calendar,
      'record' => CupertinoIcons.doc_text_fill,
      'family' => CupertinoIcons.person_2_fill,
      'policy' || 'claim' => CupertinoIcons.shield_lefthalf_fill,
      'alert' || 'ward_alert' => CupertinoIcons.bell_fill,
      'pattern' || 'baseline' => CupertinoIcons.sparkles,
      'live' => CupertinoIcons.waveform_path_ecg,
      'note' || 'handover' => CupertinoIcons.pencil,
      'patient' || 'profile' => CupertinoIcons.person_crop_circle_fill,
      'guide' => CupertinoIcons.book_fill,
      'prefs' => CupertinoIcons.gear_alt_fill,
      _ => CupertinoIcons.info_circle_fill,
    };

/// A fact the answer cited: its number, an icon for its kind and its title.
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source, this.onTap});
  final ChatSource source;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Semantics(
      button: onTap != null,
      label: tr('Source {n}: {title}', {'n': source.n, 'title': trData(source.title)}),
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.blue.withValues(alpha: .16), shape: BoxShape.circle),
              child: Text('${source.n}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.blue)),
            ),
            const SizedBox(width: 6),
            Icon(_kindIcon(source.kind), size: 13, color: c.label2),
            const SizedBox(width: 4),
            Flexible(child: Text(trData(source.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.footnote.copyWith(color: c.label, fontWeight: FontWeight.w500))),
            if (onTap != null) ...[const SizedBox(width: 2), Icon(CupertinoIcons.chevron_right, size: 11, color: c.label3)],
          ]),
        ),
      ),
    );
  }
}
