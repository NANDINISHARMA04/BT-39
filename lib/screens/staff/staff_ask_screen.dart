import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/chat.dart';
import '../../services/chat_controller.dart';
import '../../services/session.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/chat/chat_view.dart';
import 'bed_screen.dart';
import 'patients_screen.dart';
import 'staff_shell.dart';

final _bed = RegExp(r'^B\d\d$');

/// Opens what a cited fact is about: a demo bed, a patient's record, or the section that holds it.
void openStaffSource(BuildContext context, ChatSource s) {
  final nav = Navigator.of(context);
  final ref = s.ref;
  if (ref != null && (s.kind == 'ward_alert' || _bed.hasMatch(ref))) {
    nav.push(CupertinoPageRoute(builder: (_) => BedScreen(bed: ref)));
  } else if (ref != null && s.kind != 'guide') {
    nav.push(CupertinoPageRoute(builder: (_) => PatientDetailScreen(id: ref)));
  } else {
    openStaffAction(context, s.action);
  }
}

/// Opens a `staff:<section>` action.
void openStaffAction(BuildContext context, String? action) {
  if (action == null || !action.startsWith('staff:')) return;
  final sec = StaffSec.values.where((x) => x.name == action.substring(6)).firstOrNull;
  if (sec != null) openStaffSection(context, sec);
}

/// The doctors' and nurses' chat. Without [focus] it reads everything they can
/// see; with a patient id or a demo bed it reads only that one.
class StaffAskScreen extends StatefulWidget {
  const StaffAskScreen({super.key, this.focus, this.title, this.first});

  /// A patient id from the care list, or a demo bed such as `B02`.
  final String? focus;

  /// Who or what the chat is about, for the bar.
  final String? title;

  /// A question to send as soon as the chat opens.
  final String? first;

  @override
  State<StaffAskScreen> createState() => _StaffAskScreenState();
}

class _StaffAskScreenState extends State<StaffAskScreen> {
  late final ChatController _chat = ChatController(PulseChat(context.read<Session>().api), focus: widget.focus);

  @override
  void initState() {
    super.initState();
    _chat.prepare();
    if (widget.first != null) WidgetsBinding.instance.addPostFrameCallback((_) => _chat.send(widget.first!));
  }

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  List<String> _starters(Role? role) {
    final f = widget.focus;
    if (f != null && _bed.hasMatch(f)) return const ['What changed in the last hour?', 'Is this sepsis?', 'Which alerts are open?'];
    if (f != null) return const ['Summarise this patient', 'What medicines are they on?', 'What did the last note say?', 'Any allergies?'];
    return role == Role.nurse
        ? const ['What is left on my shift?', 'Any handover notes?', 'Which beds are high risk?', 'How is the home patient\'s band right now?']
        : const ['Who needs attention right now?', 'What is on my schedule tomorrow?', 'Which band alerts are waiting for review?', 'Summarise the latest notes'];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final s = context.watch<Session>();
    final focused = widget.focus != null;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(
        previousPageTitle: tr('Back'),
        backgroundColor: c.material,
        middle: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [c.teal, c.indigo])), child: const Icon(CupertinoIcons.sparkles, size: 13, color: Colors.white)),
            const SizedBox(width: 6),
            Flexible(child: Text(focused ? (widget.title ?? tr('Ask')) : tr('Ask'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, height: 1.15, fontWeight: FontWeight.w600, color: c.label))),
          ]),
          Text(focused ? tr('Answers from this patient\'s records only') : tr('Patients, notes, visits, alerts and handovers'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.15, color: c.label2)),
        ]),
      ),
      body: ChatView(
        controller: _chat,
        placeholder: focused ? tr('Ask about this patient') : tr('Ask about your patients'),
        starters: _starters(s.role),
        onAction: (a) => openStaffAction(context, a),
        onSource: (src) => openStaffSource(context, src),
        header: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.sep)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(CupertinoIcons.text_bubble_fill, color: c.indigo, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  focused
                      ? tr('Ask anything about {who}. Answers come only from their records and live values, and show where each fact is written. They never give orders or doses.', {'who': widget.title ?? tr('this patient')})
                      : tr('Ask about the patients, notes, visits, alerts and handovers you can see. Answers show the records they used. They never give orders or doses.'),
                  style: T.footnote.copyWith(color: c.label2, height: 1.35),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
