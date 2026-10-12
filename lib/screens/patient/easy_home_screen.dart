import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../engine/adapt_alert.dart';
import '../../l10n/l10n.dart';
import '../../services/accessibility.dart';
import '../../services/monitor.dart';
import '../../services/patient_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import 'assistant_screen.dart';
import 'me_screen.dart';
import 'patient_shell.dart';
import 'sos_screen.dart';

/// A simpler Today page for older people and anyone who finds the full home
/// busy: one plain status, three big vitals and four big buttons.
class EasyHomeScreen extends StatelessWidget {
  const EasyHomeScreen({super.key});

  Future<void> _callFamily(BuildContext context) async {
    final cg = context.read<PatientStore>().caregiver;
    final phone = cg?.phone.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
    if (cg == null || phone.isEmpty) {
      toast(context, tr('No family phone number'), tr('Add a caregiver with a phone number in Me › Family.'));
      return;
    }
    var ok = false;
    try {
      final uri = Uri.parse('tel:$phone');
      ok = await canLaunchUrl(uri) && await launchUrl(uri);
    } catch (_) {}
    if (!ok && context.mounted) toast(context, tr('Call {name}', {'name': cg.name}), tr('This device can\'t place calls from the app. Dial {phone} from your phone.', {'phone': cg.phone}));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final m = context.watch<MonitorController>();
    final store = context.watch<PatientStore>();
    final r = m.last;
    final alert = m.engine.status == 'alert' || m.needsReply > 0;
    final band = m.engine.status == 'band';
    final f = store.prefs.fahrenheit;
    void push(Widget page, {bool dialog = false}) => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: dialog, builder: (_) => page));
    final cg = store.caregiver;
    return LargeTitlePage(
      title: tr('Today'),
      subtitle: store.profile.name,
      children: [
        _StatusCard(
          color: alert ? c.red : band ? c.orange : c.green,
          icon: alert ? CupertinoIcons.exclamationmark_triangle_fill : band ? CupertinoIcons.antenna_radiowaves_left_right : CupertinoIcons.checkmark_seal_fill,
          title: alert ? tr('Alert: tap to see') : band ? tr('Check your band') : tr('You\'re OK'),
          text: alert ? tr('Something needs your attention.') : band ? tr('The band can\'t read you well. Tighten it a little.') : tr('Your readings look normal for you.'),
          onTap: alert ? () => TabSwitcher.of(context, PatientTab.alerts) : null,
        ),
        const SizedBox(height: 14),
        _BigVital(
          icon: CupertinoIcons.heart_fill,
          color: c.pink,
          label: tr('Heart'),
          value: r == null || !r.good ? '--' : '${r.r.hr}',
          unit: 'bpm',
          state: vitalState(r, 'hr'),
        ),
        const SizedBox(height: 10),
        _BigVital(
          icon: CupertinoIcons.drop_fill,
          color: c.blue,
          label: tr('Oxygen'),
          value: r == null || !r.good ? '--' : '${r.r.spo2}',
          unit: '%',
          state: vitalState(r, 'spo2'),
        ),
        const SizedBox(height: 10),
        _BigVital(
          icon: CupertinoIcons.thermometer,
          color: c.orange,
          label: tr('Temperature'),
          value: r == null || !r.good ? '--' : (f ? r.r.temp * 9 / 5 + 32 : r.r.temp).toStringAsFixed(1),
          unit: f ? '°F' : '°C',
          state: vitalState(r, 'temp'),
        ),
        const SizedBox(height: 18),
        _BigButton(icon: CupertinoIcons.question_circle_fill, color: c.indigo, label: tr('Ask for help'), onTap: () => push(const AssistantScreen())),
        _BigButton(icon: CupertinoIcons.phone_fill, color: c.green, label: tr('Call family'), detail: cg?.name, onTap: () => _callFamily(context)),
        _BigButton(icon: CupertinoIcons.capsule_fill, color: c.purple, label: tr('My medicines'), onTap: () => push(const ProfileEditor(), dialog: true)),
        _BigButton(icon: CupertinoIcons.exclamationmark_octagon_fill, color: c.red, label: 'SOS', detail: tr('Emergency help'), onTap: () => push(const SosScreen(), dialog: true)),
        const SizedBox(height: 8),
        Center(
          child: CupertinoButton(
            onPressed: () => context.read<AccessibilitySettings>().setEasyHome(false),
            child: Text(tr('Show full home'), textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

/// Where a vital is against the person's normal range (the range shown on
/// Today): -1 low, 0 normal, 1 high, null no reading.
int? vitalState(WindowRecord? r, String v) {
  if (r == null || !r.good) return null;
  final z = r.z[v] ?? 0;
  if (v == 'spo2') return z <= -2 ? -1 : 0;
  return z >= 2 ? 1 : z <= -2 ? -1 : 0;
}

/// The word, icon and colour for a [vitalState], so it never relies on
/// colour alone.
(String, IconData, Color) vitalStateLook(BuildContext context, int? state) {
  final c = context.ios;
  return switch (state) {
    null => (tr('No reading'), CupertinoIcons.minus_circle_fill, c.gray),
    0 => (tr('Normal'), CupertinoIcons.checkmark_circle_fill, c.green),
    1 => (tr('High'), CupertinoIcons.arrow_up_circle_fill, c.red),
    _ => (tr('Low'), CupertinoIcons.arrow_down_circle_fill, c.red),
  };
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.color, required this.icon, required this.title, required this.text, this.onTap});
  final Color color;
  final IconData icon;
  final String title, text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: '$title. $text',
        excludeSemantics: true,
        button: onTap != null,
        child: IOSCard(
          onTap: onTap,
          color: color,
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 52),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.title1.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.3)),
              ]),
            ),
          ]),
        ),
      );
}

class _BigVital extends StatelessWidget {
  const _BigVital({required this.icon, required this.color, required this.label, required this.value, required this.unit, required this.state});
  final IconData icon;
  final Color color;
  final String label, value, unit;
  final int? state;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final (word, mark, col) = vitalStateLook(context, state);
    return Semantics(
      label: '$label $value $unit, $word',
      excludeSemantics: true,
      child: IOSCard(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 8),
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title3.copyWith(color: c.label, fontWeight: FontWeight.w700))),
              ]),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text(value, style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: c.label, fontFeatures: T.num, height: 1.1)),
                  const SizedBox(width: 6),
                  Text(unit, style: T.title3.copyWith(color: c.label2, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Column(children: [
              Icon(mark, color: col, size: 40),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, child: Text(word, maxLines: 1, style: T.headline.copyWith(color: col, fontWeight: FontWeight.w700))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.icon, required this.color, required this.label, required this.onTap, this.detail});
  final IconData icon;
  final Color color;
  final String label;
  final String? detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          button: true,
          label: detail == null ? label : '$label, $detail',
          excludeSemantics: true,
          child: Pressable(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                Icon(icon, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    if (detail != null) Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 15, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const Icon(CupertinoIcons.chevron_forward, color: Colors.white, size: 22),
              ]),
            ),
          ),
        ),
      );
}
