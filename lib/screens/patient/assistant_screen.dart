import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/assistant.dart';
import '../../services/monitor.dart';
import '../../services/patient_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import 'family_screen.dart';
import 'insurance_screen.dart';
import 'patient_shell.dart';
import 'records_screen.dart';
import 'sos_screen.dart';

class _Msg {
  _Msg(this.mine, this.text, {this.reply});
  final bool mine;
  String text;
  final AssistantReply? reply;
  bool done = false;
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.initial});
  final String? initial;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _typing = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _msgs.add(_Msg(false, 'Hi ${context.read<PatientStore>().profile.name.split(' ').first}. I can explain your vitals and alerts, and help with appointments, medicines, records and insurance. I don\'t diagnose or change doses.')..done = true);
    if (widget.initial != null) WidgetsBinding.instance.addPostFrameCallback((_) => _send(widget.initial!));
  }

  @override
  void dispose() {
    _t?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      });

  void _send(String q) {
    q = q.trim();
    if (q.isEmpty || _typing) return;
    _input.clear();
    final reply = HealthAssistant(context.read<MonitorController>(), context.read<PatientStore>()).reply(q);
    setState(() {
      _msgs.add(_Msg(true, q)..done = true);
      _typing = true;
    });
    _toEnd();
    // "Typing", then stream the answer word by word.
    _t = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final m = _Msg(false, '', reply: reply);
      final words = reply.text.split(' ');
      var i = 0;
      setState(() => _msgs.add(m));
      _t = Timer.periodic(const Duration(milliseconds: 28), (t) {
        if (!mounted) return t.cancel();
        setState(() {
          m.text = words.sublist(0, ++i).join(' ');
          if (i >= words.length) {
            t.cancel();
            m.done = true;
            _typing = false;
          }
        });
        _toEnd();
      });
    });
  }

  void _act(String action) {
    final nav = Navigator.of(context);
    switch (action) {
      case 'sos':
        nav.push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const SosScreen()));
      case 'records':
        nav.push(CupertinoPageRoute(builder: (_) => const RecordsScreen()));
      case 'insurance':
        nav.push(CupertinoPageRoute(builder: (_) => const InsuranceScreen()));
      case 'family':
        nav.push(CupertinoPageRoute(builder: (_) => const FamilyScreen()));
      default:
        final tab = {'alerts': PatientTab.alerts, 'insights': PatientTab.insights, 'book': PatientTab.care}[action];
        nav.pop();
        if (tab != null) TabSwitcher.of(context, tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(
        previousPageTitle: 'Today',
        backgroundColor: c.material,
        middle: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [c.indigo, c.pink])), child: const Icon(CupertinoIcons.sparkles, size: 13, color: Colors.white)),
          const SizedBox(width: 6),
          const Flexible(child: Text('Health Assistant', overflow: TextOverflow.ellipsis)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            itemCount: _msgs.length + (_typing && (_msgs.isEmpty || _msgs.last.mine) ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= _msgs.length) return const _TypingBubble();
              final m = _msgs[i];
              return FadeIn(
                dy: 10,
                child: Align(
                  alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .8),
                    child: Column(crossAxisAlignment: m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: m.mine ? c.blue : (m.reply?.urgent == true ? c.red.withValues(alpha: .14) : c.card),
                          borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(m.mine ? 20 : 6), bottomRight: Radius.circular(m.mine ? 6 : 20)),
                        ),
                        child: Text(m.text, style: T.callout.copyWith(color: m.mine ? Colors.white : c.label, height: 1.35)),
                      ),
                      if (m.done && m.reply?.action != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CupertinoButton.tinted(
                            sizeStyle: CupertinoButtonSize.small,
                            color: m.reply!.urgent ? c.red : null,
                            onPressed: () => _act(m.reply!.action!),
                            child: Text(m.reply!.actionLabel ?? 'Open', style: TextStyle(color: m.reply!.urgent ? c.red : null)),
                          ),
                        ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final s in HealthAssistant.suggestions)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 6),
                child: Pressable(
                  onTap: () => _send(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: c.sep)),
                    child: Text(s, style: T.footnote.copyWith(color: c.label)),
                  ),
                ),
              ),
          ]),
        ),
        Glass(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _input,
                    placeholder: 'Ask about your health',
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.sep)),
                    style: T.callout.copyWith(color: c.label),
                    onSubmitted: _send,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 6),
                Semantics(
                  label: 'Send',
                  button: true,
                  child: Pressable(onTap: () => _send(_input.text), child: Icon(CupertinoIcons.arrow_up_circle_fill, size: 34, color: c.blue)),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20)),
        child: AnimatedBuilder(
          animation: _a,
          builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.label2.withValues(alpha: .3 + .7 * (((_a.value * 3 - i) % 3) < 1 ? 1 : 0))),
              ),
          ]),
        ),
      ),
    );
  }
}
