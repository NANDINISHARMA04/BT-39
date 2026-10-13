import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/news2.dart';
import '../../l10n/l10n.dart';
import '../../services/bt39_client.dart';
import '../../services/session.dart';
import '../../services/staff_controller.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/chat/bubble.dart';
import '../../widgets/common.dart';
import '../../widgets/vitals.dart';
import 'staff_ask_screen.dart';
import 'staff_shell.dart';

/// One bed: live values with NEWS2 points, alerts, and (for doctors) the patient chat.
class BedScreen extends StatefulWidget {
  const BedScreen({super.key, required this.bed});
  final String bed;
  @override
  State<BedScreen> createState() => _BedScreenState();
}

class _BedScreenState extends State<BedScreen> {
  final _q = TextEditingController();
  final List<(bool, String)> _chat = [];
  bool _asking = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _ask(LiveBed b) async {
    final q = _q.text.trim();
    if (q.isEmpty || _asking) return;
    final sc = context.read<StaffController>();
    _q.clear();
    setState(() {
      _chat.add((true, q));
      _chat.add((false, ''));
      _asking = true;
    });
    // The signed-in ward: the doctor chat of the BT39 monitor (/v1/chat). Demo beds open the PulseOS chat instead.
    await for (final ev in sc.client.chat(b.patientId!, q)) {
      if (!mounted) return;
      final sofar = _chat.last.$2;
      final next = switch (ev) {
        ChatDelta d => sofar + d.text,
        ChatError e => '$sofar\n\n⚠️ ${e.message}',
        ChatDone d => d.sources.isEmpty ? sofar : '$sofar\n\n${tr('Sources: {list}', {'list': d.sources.join(', ')})}',
      };
      setState(() => _chat[_chat.length - 1] = (false, next));
    }
    if (mounted) setState(() => _asking = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final sc = context.watch<StaffController>();
    final s = context.watch<Session>();
    final b = sc.beds.where((x) => x.bed == widget.bed).firstOrNull;
    if (b == null || b.empty) {
      return PlainPage(title: widget.bed, previousTitle: tr('Ward'), children: [EmptyState(icon: CupertinoIcons.bed_double, title: widget.bed, message: tr('This bed is empty.'))]);
    }
    final alerts = sc.sortedAlerts.where((a) => a.bed == b.bed).toList();
    final col = bandColor(context, b.band);
    Widget vital(String label, String unit, String vital, num? x, {String? sub}) {
      final pts = vital == 'dbp' ? null : b.points[vital]; // NEWS2 points, scored by the service
      final vc = (pts ?? 0) >= 3 ? c.red : pts == 2 ? c.orange : pts == 1 ? c.yellow : c.label;
      return IOSCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600))),
            if (pts != null && x != null) Text('+$pts', style: T.caption.copyWith(color: vc, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              AnimatedNumber(x?.toDouble(), decimals: vital == 'temp' ? 1 : 0, style: T.title1.copyWith(color: vc)),
              Padding(padding: const EdgeInsets.only(left: 3, bottom: 4), child: Text(unit, style: T.caption.copyWith(color: c.label2))),
            ]),
          ),
          if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: c.label3)),
        ]),
      );
    }

    return PlainPage(
      middle: Text('${b.bed} · ${b.name}'),
      previousTitle: tr('Ward'),
      trailing: StatusPill(status: sc.status),
      children: [
        AccentCard(
          color: col,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                Text('${b.age}${b.sex} · ${b.onOxygen == true ? tr('On oxygen') : tr('On air')} · ACVPU ${b.consciousness ?? 'A'}', style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            Column(children: [
              Text('${b.news2 ?? '—'}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, fontFeatures: T.num)),
              Text('NEWS2 · ${b.band == null ? '—' : tr(bandLabel[b.band] ?? '—')}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 700 ? 6 : 3,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .9,
          children: [
            vital('HR', '/min', 'hr', b.hr),
            vital('SpO₂', '%', 'spo2', b.spo2),
            vital('RR', '/min', 'rr', b.rr),
            vital(tr('Sys BP'), 'mmHg', 'sbp', b.sbp, sub: b.nibpAgeS == null ? null : tr('cuff {n} min ago', {'n': (b.nibpAgeS! / 60).round()})),
            vital(tr('Dia BP'), 'mmHg', 'dbp', b.dbp),
            vital(tr('Temp'), '°C', 'temp', b.temp),
          ],
        ),
        const SizedBox(height: 12),
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Heart rate, last 2 minutes'), style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Sparkline(sc.hrHistory[b.bed]?.toList() ?? const [], color: c.pink, width: double.infinity, height: 60),
          ]),
        ),
        if (sc.demo && s.role == Role.doctor) ...[
          SectionHeader(tr('Demo scenario')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (id, name) in [('stable', 'Stable'), ('sepsis', 'Sepsis'), ('hypoxia', 'Low oxygen'), ('tachy', 'Fast heart'), ('probe_off', 'Probe off')])
              AppChip(tr(name), tinted: true, onTap: () => sc.runScenario(b.bed, id).then((_) => context.mounted ? toast(context, tr('{name} on {bed}', {'name': tr(name), 'bed': b.bed})) : null)),
          ]),
        ],
        SectionHeader(tr('Alerts'), trailing: tr('{n} open', {'n': alerts.where((a) => a.open).length})),
        if (alerts.isEmpty) IOSCard(child: Text(tr('No alerts for this patient.'), style: T.sub.copyWith(color: c.label2))),
        for (final a in alerts) StaffAlertCard(a: a, showPatient: false),
        if (sc.demo) ...[
          SectionHeader(tr('Ask about this patient')),
          _AskCard(bed: b.bed, title: '${b.bed} · ${b.name ?? ''}'),
        ] else if (s.role == Role.doctor) ...[
          SectionHeader(tr('Ask about this patient')),
          IOSCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_chat.isEmpty) Text(tr('Answers come from the BT39 assistant, which reads this patient\'s vitals, alerts and uploaded notes. It never gives doses or orders.'), style: T.footnote.copyWith(color: c.label2)),
              for (final (mine, text) in _chat)
                Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: text.isEmpty
                        ? const TypingBubble()
                        : ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .72),
                            child: Bubble(color: mine ? c.blue : incomingBubble(c), mine: mine, child: Text(text, style: T.sub.copyWith(color: mine ? Colors.white : c.label, height: 1.35))),
                          ),
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(R.lg), border: Border.all(color: c.sep)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _q,
                      placeholder: tr('e.g. What changed in the last hour?'),
                      decoration: null,
                      minLines: 1,
                      maxLines: 4,
                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      style: T.body.copyWith(color: c.label),
                      placeholderStyle: T.body.copyWith(color: c.label3),
                      onSubmitted: (_) => _ask(b),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: tr('Send'),
                    child: Pressable(
                      onTap: _asking ? null : () => _ask(b),
                      scale: .85,
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: _asking ? c.gray : c.blue, shape: BoxShape.circle),
                        child: const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 19),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

/// A demo bed's way into the chat: three questions to tap and a box that opens the conversation about this bed.
class _AskCard extends StatelessWidget {
  const _AskCard({required this.bed, required this.title});
  final String bed, title;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    void open([String? q]) => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => StaffAskScreen(focus: bed, title: title, first: q)));
    return IOSCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Answers come from this bed\'s live values and alerts, and show where each fact is written. They never give orders or doses.'), style: T.footnote.copyWith(color: c.label2)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final q in const ['Is this sepsis?', 'What changed in the last hour?', 'Which alerts are open?']) AppChip(tr(q), tinted: true, onTap: () => open(tr(q))),
        ]),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: tr('Ask about this patient'),
          child: Pressable(
            onTap: open,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(R.lg), border: Border.all(color: c.sep)),
              child: Row(children: [
                Expanded(child: Text(tr('Ask about this patient'), style: T.body.copyWith(color: c.label3))),
                Container(width: 32, height: 32, decoration: BoxDecoration(color: c.blue, shape: BoxShape.circle), child: const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 19)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
