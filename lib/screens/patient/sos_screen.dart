import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../engine/adapt_alert.dart';
import '../../l10n/l10n.dart';
import '../../services/monitor.dart';
import '../../services/patient_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';

/// Emergency SOS. Hold the button for 3 seconds, or let the 10-second
/// countdown run out when a critical alert opened this screen.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key, this.trigger});
  final HealthAlert? trigger;
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  Timer? _countdown;
  int _left = 10;
  bool _active = false;
  final Map<String, int> _contactState = {}; // 0 sending, 1 delivered, 2 seen

  /// The SOS as the service recorded it, so ending it is recorded too.
  String? _sosId;

  @override
  void initState() {
    super.initState();
    _hold.addStatusListener((s) {
      if (s == AnimationStatus.completed) _activate();
    });
    if (widget.trigger != null) {
      _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _left--);
        if (_left <= 0) {
          t.cancel();
          _activate();
        }
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _hold.dispose();
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_active) return;
    _countdown?.cancel();
    HapticFeedback.vibrate();
    setState(() => _active = true);
    final store = context.read<PatientStore>();
    for (final m in store.emergencyContacts) {
      _contactState[m.id] = 0;
    }
    // The service records the SOS and says when each contact's message shows as delivered and seen (messages are
    // simulated: there is no SMS provider). Times count from the press, so a quick answer feels as before. If the
    // service can't be reached, the same times run here.
    final pressed = DateTime.now();
    final plan = await store.startSos(alertId: widget.trigger?.id);
    if (!mounted) return;
    _sosId = plan?.id;
    final spent = DateTime.now().difference(pressed).inMilliseconds;
    final contacts = plan?.contacts ??
        [for (final (i, m) in store.emergencyContacts.indexed) (id: m.id, name: m.name, deliveredMs: 1200 + i * 700, seenMs: 3500 + i * 1500)];
    for (final x in contacts) {
      _contactState[x.id] = _contactState[x.id] ?? 0;
      Future.delayed(Duration(milliseconds: max(0, x.deliveredMs - spent)), () => mounted ? setState(() => _contactState[x.id] = max(_contactState[x.id] ?? 0, 1)) : null);
      Future.delayed(Duration(milliseconds: max(0, x.seenMs - spent)), () => mounted ? setState(() => _contactState[x.id] = 2) : null);
    }
    setState(() {});
  }

  Future<void> _call() async {
    final ok = await canLaunchUrl(Uri.parse('tel:112')) && await launchUrl(Uri.parse('tel:112'));
    if (!ok && mounted) toast(context, tr('Dial 112'), tr('This device can\'t place calls from the app. Dial 112 from your phone.'));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PatientStore>();
    final r = context.watch<MonitorController>().last;
    return Scaffold(
      backgroundColor: _active ? const Color(0xFF8E0E00) : Colors.black,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
          Row(children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (_active) {
                  final id = _sosId;
                  if (id != null) context.read<PatientStore>().endSos(id);
                  toast(context, tr('SOS ended'), tr('Your contacts were told you cancelled.'));
                }
                Navigator.pop(context);
              },
              child: Text(_active ? tr('End SOS') : tr('Cancel'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(_active ? tr('Help is on the way') : (widget.trigger != null ? tr('Critical alert') : tr('Emergency SOS')), textAlign: TextAlign.center, style: T.largeTitle.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            _active
                ? tr('Your emergency contacts have your location and live vitals.')
                : widget.trigger != null
                    ? tr('{title}. SOS starts in {n} s unless you cancel.', {'title': trData(widget.trigger!.title), 'n': _left})
                    : tr('Press and hold for 3 seconds to call 112 and alert your emergency contacts.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 30),
          Center(
            child: GestureDetector(
              onTapDown: (_) => _active ? null : _hold.forward(),
              onTapUp: (_) => _hold.isCompleted ? null : _hold.reverse(),
              onTapCancel: () => _hold.isCompleted ? null : _hold.reverse(),
              child: Semantics(
                button: true,
                label: tr('Hold for SOS'),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulse, _hold]),
                  builder: (_, _) => SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(alignment: Alignment.center, children: [
                      for (var i = 0; i < 3; i++)
                        Opacity(
                          opacity: (1 - ((_pulse.value + i / 3) % 1)).clamp(0, 1) * .5,
                          child: Container(width: 150 + 90 * ((_pulse.value + i / 3) % 1), height: 150 + 90 * ((_pulse.value + i / 3) % 1), decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF3B30))),
                        ),
                      SizedBox(width: 176, height: 176, child: CircularProgressIndicator(value: _active ? 1 : (widget.trigger != null ? 1 - _left / 10 : _hold.value), strokeWidth: 6, color: Colors.white, backgroundColor: Colors.white24)),
                      Container(
                        width: 156,
                        height: 156,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFFFF6B5E), Color(0xFFD70015)])),
                        child: Text(_active ? tr('ACTIVE') : (widget.trigger != null ? '$_left' : 'SOS'), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          if (widget.trigger != null && !_active) ...[
            const SizedBox(height: 18),
            CupertinoButton(color: Colors.white, onPressed: _activate, child: Text(tr('Send SOS now'), style: TextStyle(color: Color(0xFFD70015), fontWeight: FontWeight.w700))),
            CupertinoButton(onPressed: () => Navigator.pop(context), child: Text(tr('I\'m OK, cancel'), style: const TextStyle(color: Colors.white))),
          ],
          const SizedBox(height: 22),
          _DarkCard(children: [
            _DarkRow(icon: CupertinoIcons.phone_fill, title: tr('Call 112'), subtitle: tr('National emergency number'), trailing: CupertinoButton(padding: const EdgeInsets.symmetric(horizontal: 14), color: const Color(0xFF34C759), sizeStyle: CupertinoButtonSize.small, onPressed: _call, child: Text(tr('Call')))),
            _DarkRow(icon: CupertinoIcons.location_fill, title: tr('Location'), subtitle: _active ? tr('Shared · Sector 62, Noida (demo location)') : tr('Shared when SOS starts')),
            if (r != null && r.good) _DarkRow(icon: CupertinoIcons.waveform_path_ecg, title: tr('Live vitals'), subtitle: 'HR ${r.r.hr} · SpO₂ ${r.r.spo2}% · ${r.r.temp.toStringAsFixed(1)} °C'),
          ]),
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.only(left: 6, bottom: 8), child: Text(tr('EMERGENCY CONTACTS'), style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: .5))),
          _DarkCard(children: [
            if (store.emergencyContacts.isEmpty) _DarkRow(icon: CupertinoIcons.person_crop_circle_badge_exclam, title: tr('No emergency contacts'), subtitle: tr('Add them in Me > Family')),
            for (final m in store.emergencyContacts)
              _DarkRow(
                icon: CupertinoIcons.person_crop_circle_fill,
                title: '${m.name} · ${trData(m.relation)}',
                subtitle: m.phone,
                trailing: !_active
                    ? null
                    : switch (_contactState[m.id] ?? 0) {
                        0 => const CupertinoActivityIndicator(color: Colors.white),
                        1 => Text(tr('Delivered'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        _ => Text(tr('Seen ✓'), style: const TextStyle(color: Color(0xFF30D158), fontSize: 13, fontWeight: FontWeight.w700)),
                      },
              ),
          ]),
          const SizedBox(height: 14),
          CupertinoButton(
            onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const MedicalIdScreen())),
            child: Text(tr('Show Medical ID'), style: const TextStyle(color: Colors.white)),
          ),
          Text(tr('Messages to contacts are simulated and recorded by the BT39 service; no text message is sent. The 112 call uses your phone\'s dialer.'), textAlign: TextAlign.center, style: T.caption.copyWith(color: Colors.white38)),
        ]),
      ),
    );
  }
}

class _DarkCard extends StatelessWidget {
  const _DarkCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(height: .5, color: Colors.white12, indent: 54), children[i]],
        ]),
      );
}

class _DarkRow extends StatelessWidget {
  const _DarkRow({required this.icon, required this.title, required this.subtitle, this.trailing});
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ]),
          ),
          ?trailing,
        ]),
      );
}

/// What a first responder needs, in one screen.
class MedicalIdScreen extends StatelessWidget {
  const MedicalIdScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.watch<PatientStore>();
    final p = store.profile;
    Widget block(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: T.caption.copyWith(color: c.red, fontWeight: FontWeight.w700, letterSpacing: .5)),
            const SizedBox(height: 3),
            Text(body, style: T.body.copyWith(color: c.label)),
          ]),
        );
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(previousPageTitle: tr('Back'), backgroundColor: c.material, middle: Text(tr('Medical ID'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(p.name, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: T.title2.copyWith(color: c.label)),
                  Text('${tr('{n} years', {'n': p.age})} · ${p.sex == 'M' ? tr('Male') : p.sex == 'F' ? tr('Female') : tr('Other')}', style: T.footnote.copyWith(color: c.label2)),
                ]),
              ),
              Icon(CupertinoIcons.staroflife_fill, color: c.red, size: 30),
            ]),
            const SizedBox(height: 18),
            block(tr('Blood type'), p.bloodGroup),
            block(tr('Medical conditions'), p.conditions.isEmpty ? tr('None') : p.conditions.map(trData).join('\n')),
            block(tr('Allergies'), p.allergies.isEmpty ? tr('None known') : p.allergies.map(trData).join(', ')),
            block(tr('Medications'), p.medications.isEmpty ? tr('None') : p.medications.map((m) => '${m.name} ${m.dose}, ${trData(m.schedule)}').join('\n')),
            block(tr('Height / weight'), '${p.heightCm.round()} cm · ${p.weightKg.round()} kg'),
            block(tr('Emergency contacts'), store.emergencyContacts.isEmpty ? tr('None') : store.emergencyContacts.map((m) => '${m.name} (${trData(m.relation)}) ${m.phone}').join('\n')),
          ]),
        ),
      ]),
    );
  }
}
