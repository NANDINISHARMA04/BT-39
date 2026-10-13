import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../../services/assistant.dart';
import '../../services/chat.dart';
import '../../services/chat_controller.dart';
import '../../services/monitor.dart';
import '../../services/patient_store.dart';
import '../../services/session.dart';
import '../../services/speech.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/chat/bubble.dart';
import '../../widgets/chat/chat_view.dart';
import '../../widgets/common.dart';
import '../research/research_lab_screen.dart';
import 'accessibility_screen.dart';
import 'alert_detail_screen.dart';
import 'doctors_screen.dart';
import 'family_screen.dart';
import 'how_it_works_screen.dart';
import 'insurance_screen.dart';
import 'me_screen.dart';
import 'patient_shell.dart';
import 'records_screen.dart';
import 'sos_screen.dart';

/// A help topic button: an icon, a short label, and the question it asks
/// (English keys, shown and sent with tr()). A null question opens SOS.
typedef _Topic = (IconData icon, String label, String? question);

const _findTopics = <_Topic>[
  (CupertinoIcons.doc_text_fill, 'Reports', 'Where are my reports?'),
  (CupertinoIcons.capsule_fill, 'Medicines', 'Where are my medicines?'),
  (CupertinoIcons.calendar, 'Appointments', 'How do I book an appointment?'),
  (CupertinoIcons.person_3_fill, 'Family', 'Where are my family contacts?'),
  (CupertinoIcons.shield_lefthalf_fill, 'Insurance', 'Where is my insurance?'),
];

const _helpTopics = <_Topic>[
  (CupertinoIcons.exclamationmark_octagon_fill, 'SOS · call 112', null),
  (CupertinoIcons.phone_fill, 'Call family', 'Call my family'),
  (CupertinoIcons.bandage_fill, 'I feel unwell', 'I feel unwell'),
];

const _easierTopics = <_Topic>[
  (CupertinoIcons.globe, 'Language', 'How do I change the language?'),
  (CupertinoIcons.textformat_size, 'Bigger text', 'How do I make the text bigger?'),
  (CupertinoIcons.question_circle_fill, 'What can you do?', 'What can you help with?'),
];

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.initial});
  final String? initial;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const _readAloudKey = 'bt39.readAloud';

  late final ChatController _chat = ChatController(PulseChat(context.read<Session>().api));
  bool _readAloud = false;

  @override
  void initState() {
    super.initState();
    _chat.prepare();
    if (widget.initial != null) WidgetsBinding.instance.addPostFrameCallback((_) => _chat.send(widget.initial!));
    _loadReadAloud();
  }

  Future<void> _loadReadAloud() async {
    try {
      final v = (await SharedPreferences.getInstance()).getBool(_readAloudKey) ?? false;
      if (mounted) setState(() => _readAloud = v);
    } catch (_) {}
  }

  Future<void> _setReadAloud(bool v) async {
    setState(() => _readAloud = v);
    if (!v) Speech.instance.stopSpeaking();
    toast(context, v ? tr('Answers will be read aloud') : tr('Read aloud is off'));
    try {
      await (await SharedPreferences.getInstance()).setBool(_readAloudKey, v);
    } catch (_) {}
  }

  @override
  void dispose() {
    Speech.instance.stopSpeaking();
    _chat.dispose();
    super.dispose();
  }

  /// Text for the speech engine: citations dropped, bullets and arrows read as pauses.
  static String _spoken(String s) => plainChatText(s).replaceAll('•', '').replaceAll('→', ',').replaceAll('₹', '₹ ');

  void _answered(ChatMessage reply) {
    if (_readAloud && reply.shown.isNotEmpty) Speech.instance.speak(_spoken(reply.shown));
  }

  Future<void> _callFamily() async {
    final store = context.read<PatientStore>();
    final who = store.caregiver ?? store.emergencyContacts.firstOrNull ?? store.family.where((m) => m.phone.isNotEmpty).firstOrNull;
    if (who == null || who.phone.isEmpty) {
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const FamilyScreen()));
      return;
    }
    final uri = Uri.parse('tel:${who.phone.replaceAll(' ', '')}');
    var ok = false;
    try {
      ok = await canLaunchUrl(uri) && await launchUrl(uri);
    } catch (_) {}
    if (!ok && mounted) toast(context, tr('Call {name}', {'name': who.name.split(' ').first}), tr('This device can\'t place calls from the app. Dial {phone} from your phone.', {'phone': who.phone}));
  }

  void _act(String action) {
    Speech.instance.stopSpeaking();
    final nav = Navigator.of(context);
    void push(Widget page, {bool dialog = false}) => nav.push(CupertinoPageRoute(fullscreenDialog: dialog, builder: (_) => page));
    void toTab(int tab) {
      nav.popUntil((r) => r.isFirst);
      patientTab.value = tab;
    }

    switch (action) {
      case 'sos':
        push(const SosScreen(), dialog: true);
      case 'records':
        push(const RecordsScreen());
      case 'healthProfile':
        push(const ProfileEditor(), dialog: true);
      case 'insurance':
        push(const InsuranceScreen());
      case 'family':
        push(const FamilyScreen());
      case 'callFamily':
        _callFamily();
      case 'medicalId':
        push(const MedicalIdScreen());
      case 'findDoctor':
        push(const DoctorsScreen());
      case 'alertDetail':
        final alerts = context.read<MonitorController>().engine.alerts;
        if (alerts.isEmpty) {
          toTab(PatientTab.alerts);
        } else {
          push(AlertDetailScreen(alert: alerts.first));
        }
      case 'howItWorks':
        push(ChangeNotifierProvider.value(value: context.read<MonitorController>(), child: const HowItWorksScreen()));
      case 'research':
        push(const ResearchLabScreen());
      case 'accessibility':
        push(const AccessibilityScreen());
      case 'simulator':
        showSimulator(context);
      case 'language':
        setLang(hindi ? 'en' : 'hi');
      case 'alerts':
        toTab(PatientTab.alerts);
      case 'insights':
        toTab(PatientTab.insights);
      case 'book':
        toTab(PatientTab.care);
      case 'me':
        toTab(PatientTab.me);
    }
  }

  void _topic(_Topic t) {
    final q = t.$3;
    if (q == null) {
      _act('sos');
    } else {
      _chat.send(tr(q));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final speech = Speech.instance;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(
        previousPageTitle: tr('Today'),
        backgroundColor: c.material,
        middle: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [c.indigo, c.pink])), child: const Icon(CupertinoIcons.sparkles, size: 13, color: Colors.white)),
            const SizedBox(width: 6),
            Flexible(child: Text(tr('AI Health Assistant'), overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontSize: 16, height: 1.15, fontWeight: FontWeight.w600, color: c.label))),
          ]),
          Text(tr('Ask anything, or where to find something'), overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontSize: 12, height: 1.15, color: c.label2)),
        ]),
        trailing: speech.canSpeak
            ? Semantics(
                label: tr('Read answers aloud'),
                toggled: _readAloud,
                button: true,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 44),
                  onPressed: () => _setReadAloud(!_readAloud),
                  child: Icon(_readAloud ? CupertinoIcons.speaker_3_fill : CupertinoIcons.speaker_slash_fill, size: 26, color: _readAloud ? c.blue : c.label2),
                ),
              )
            : null,
      ),
      body: ChatView(
        controller: _chat,
        large: true,
        voice: true,
        placeholder: tr('Ask about your health'),
        starters: HealthAssistant.suggestions,
        onAction: _act,
        onSource: (s) {
          if (s.action != null) _act(s.action!);
        },
        onAnswered: _answered,
        header: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
            child: Bubble(
              color: incomingBubble(c),
              mine: false,
              child: Text(
                tr('Hi {name}. I can explain your vitals and alerts, and help with appointments, medicines, records and insurance. I don\'t diagnose or change doses.', {'name': context.read<PatientStore>().profile.name.split(' ').first}),
                style: TextStyle(fontSize: 18, height: 1.36, letterSpacing: -.3, color: c.label),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _HelpTopics(onTap: _topic),
        ]),
      ),
    );
  }
}

/// Big, grouped topic buttons for first-time and older users.
class _HelpTopics extends StatelessWidget {
  const _HelpTopics({required this.onTap});
  final void Function(_Topic) onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    Widget group(String title, List<_Topic> topics, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 8), child: Text(title, style: T.headline.copyWith(color: c.label))),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in topics) _Chip(icon: t.$1, label: tr(t.$2), color: t.$3 == null ? c.red : color, strong: t.$3 == null, onTap: () => onTap(t)),
          ]),
        ]);
    return Container(
      margin: const EdgeInsets.only(bottom: 14, top: 2),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.sep)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(CupertinoIcons.question_circle_fill, color: c.indigo, size: 24),
          const SizedBox(width: 8),
          Expanded(child: Text(tr('Help topics'), style: T.title3.copyWith(color: c.label))),
        ]),
        const SizedBox(height: 2),
        Text(tr('Tap a topic. I\'ll show you where it is, step by step.'), style: T.sub.copyWith(color: c.label2)),
        group(tr('Find something'), _findTopics, c.blue),
        group(tr('Get help'), _helpTopics, c.orange),
        group(tr('Make it easier'), _easierTopics, c.indigo),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.onTap, this.icon, this.strong = false});
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: strong ? color : color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: strong ? color : color.withValues(alpha: .45), width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 22, color: strong ? Colors.white : color), const SizedBox(width: 8)],
            Flexible(child: Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: strong ? Colors.white : c.label))),
          ]),
        ),
      ),
    );
  }
}
