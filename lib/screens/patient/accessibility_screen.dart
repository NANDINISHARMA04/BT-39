import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/accessibility.dart';
import '../../services/session.dart';
import '../../services/speech.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/lang_switch.dart';

/// Accessibility settings: text size, bold text, easy home, flash and
/// spoken alerts. Each group says who it helps.
class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  static const _sizeNames = ['Normal', 'Large', 'Extra large'];

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final a = context.watch<AccessibilitySettings>();
    final patient = context.read<Session>().role == Role.patient;
    Widget toggle(bool v, ValueChanged<bool> on, String label) => Semantics(label: label, child: CupertinoSwitch(value: v, onChanged: on));
    return LargeTitlePage(
      title: tr('Accessibility'),
      previousTitle: tr('Back'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(tr('Make PulseOS easier to see, hear and use. Changes apply straight away and are saved on this device.'), style: T.sub.copyWith(color: c.label2)),
        ),
        FormGroup(
          header: tr('For low vision'),
          footer: patient ? tr('Bigger, bolder text, and alerts read aloud, for people who find the screen hard to see.') : tr('Bigger, bolder text for people who find small text hard to read.'),
          children: [
            for (final (i, size) in AccessibilitySettings.textSizes.indexed)
              Semantics(
                selected: a.textSize == size,
                inMutuallyExclusiveGroup: true,
                child: IOSRow(
                  icon: CupertinoIcons.textformat_size,
                  iconColor: c.blue,
                  title: tr(_sizeNames[i]),
                  trailing: a.textSize == size ? Icon(CupertinoIcons.checkmark_alt, color: c.blue, size: 24) : const SizedBox(width: 24),
                  chevron: false,
                  onTap: () => a.setTextSize(size),
                ),
              ),
            IOSRow(icon: CupertinoIcons.bold, iconColor: c.indigo, title: tr('Bold text'), trailing: toggle(a.boldText, a.setBoldText, tr('Bold text')), chevron: false),
            if (patient)
              IOSRow(
                icon: CupertinoIcons.speaker_3_fill,
                iconColor: c.purple,
                title: tr('Read alerts aloud'),
                subtitle: tr('For blind users: new alerts are spoken by the device'),
                trailing: toggle(a.speakAlerts, (v) {
                  a.setSpeakAlerts(v);
                  if (v) Speech.instance.speak(tr('Alerts will be read aloud like this.'));
                }, tr('Read alerts aloud')),
                chevron: false,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Preview(),
        if (patient) ...[
          FormGroup(
            header: tr('For hearing loss'),
            footer: tr('For deaf or hard-of-hearing people: the screen flashes, the phone vibrates and the alert stays on screen until you tap it.'),
            children: [
              IOSRow(icon: CupertinoIcons.lightbulb_fill, iconColor: c.orange, title: tr('Flash the screen for alerts'), trailing: toggle(a.flashAlerts, a.setFlashAlerts, tr('Flash the screen for alerts')), chevron: false),
            ],
          ),
          FormGroup(
            header: tr('For memory or for older users'),
            footer: tr('Easy home shows one clear status, your three vitals in large numbers and four big buttons: help, family, medicines and SOS.'),
            children: [
              IOSRow(icon: CupertinoIcons.house_fill, iconColor: c.green, title: tr('Easy home'), trailing: toggle(a.easyHome, a.setEasyHome, tr('Easy home')), chevron: false),
            ],
          ),
        ],
        FormGroup(
          header: tr('For motion sensitivity'),
          footer: tr('Turns off sliding and fading animations, for people who feel dizzy or distracted by movement.'),
          children: [
            IOSRow(icon: CupertinoIcons.wind, iconColor: c.teal, title: tr('Reduce motion'), trailing: toggle(a.reduceMotion, a.setReduceMotion, tr('Reduce motion')), chevron: false),
          ],
        ),
        FormGroup(
          header: tr('Language'),
          footer: tr('Use the app in the language you read best.'),
          children: const [LanguageRow()],
        ),
      ],
    );
  }
}

/// Shows how text looks at the chosen size.
class _Preview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return IOSCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Preview'), style: T.footnote.copyWith(color: c.label2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(tr('Heart 72 bpm · Normal'), style: T.title3.copyWith(color: c.label, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(tr('This is how text will look across the app.'), style: T.body.copyWith(color: c.label)),
      ]),
    );
  }
}
