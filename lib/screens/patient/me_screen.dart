import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/patient_models.dart';
import '../../services/monitor.dart';
import '../../services/patient_store.dart';
import '../../services/session.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/lang_switch.dart';
import 'accessibility_screen.dart';
import 'family_screen.dart';
import 'insurance_screen.dart';
import 'patient_shell.dart';
import 'records_screen.dart';
import 'sos_screen.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.watch<PatientStore>();
    final s = context.watch<Session>();
    final p = store.profile;
    final prefs = store.prefs;
    final e = context.watch<MonitorController>().engine;
    return LargeTitlePage(
      title: tr('Me'),
      children: [
        FadeIn(
          child: IOSCard(
            onTap: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const ProfileEditor())),
            child: Row(children: [
              Avatar(p.name, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: T.title2.copyWith(color: c.label)),
                  Text(p.email.isEmpty ? tr('No email') : p.email, style: T.footnote.copyWith(color: c.label2)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    Pill(switch (s.mode) { AuthMode.demo => tr('Demo Mode'), AuthMode.local => tr('Device account'), AuthMode.cloud => tr('Signed in') }, color: s.demo ? c.orange : c.green, icon: s.demo ? CupertinoIcons.play_circle_fill : CupertinoIcons.checkmark_shield_fill),
                    Pill(tr('Edit profile'), color: c.blue),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        FadeIn(
          delay: 60,
          child: Row(children: [
            _Fact(tr('Age'), '${p.age}'),
            _Fact(tr('Blood'), p.bloodGroup),
            _Fact('BMI', p.bmi.toStringAsFixed(1)),
            _Fact(tr('Height'), '${p.heightCm.round()} cm'),
          ]),
        ),
        FormGroup(header: tr('Health'), children: [
          IOSRow(icon: CupertinoIcons.heart_circle_fill, iconColor: c.pink, title: tr('Health profile'), subtitle: '${p.conditions.length == 1 ? tr('{n} condition', {'n': 1}) : tr('{n} conditions', {'n': p.conditions.length})} · ${p.medications.length == 1 ? tr('{n} medicine', {'n': 1}) : tr('{n} medicines', {'n': p.medications.length})} · ${p.allergies.length == 1 ? tr('{n} allergy', {'n': 1}) : tr('{n} allergies', {'n': p.allergies.length})}', onTap: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const ProfileEditor()))),
          IOSRow(icon: CupertinoIcons.doc_text_fill, iconColor: c.teal, title: tr('Medical records'), subtitle: tr('{n} files', {'n': store.records.length}), onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const RecordsScreen()))),
          IOSRow(icon: CupertinoIcons.shield_lefthalf_fill, iconColor: c.green, title: tr('Insurance & claims'), subtitle: '${store.policies.length == 1 ? tr('{n} policy', {'n': 1}) : tr('{n} policies', {'n': store.policies.length})} · ${tr('{n} claims', {'n': store.claims.length})}', onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const InsuranceScreen()))),
          IOSRow(icon: CupertinoIcons.person_3_fill, iconColor: c.orange, title: tr('Family'), subtitle: '${tr('{n} members', {'n': store.family.length})} · ${store.caregiver == null ? tr('caregiver not set') : tr('caregiver {name}', {'name': store.caregiver!.name.split(' ').first})}', onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const FamilyScreen()))),
        ]),
        FormGroup(header: tr('Emergency'), children: [
          IOSRow(icon: CupertinoIcons.exclamationmark_octagon_fill, iconColor: c.red, title: tr('Emergency SOS'), subtitle: tr('Call 112 and alert {n} contacts', {'n': store.emergencyContacts.length}), onTap: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const SosScreen()))),
          IOSRow(icon: CupertinoIcons.staroflife_fill, iconColor: c.red, title: tr('Medical ID'), subtitle: tr('What responders see'), onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const MedicalIdScreen()))),
          IOSRow(
            icon: CupertinoIcons.bolt_fill,
            iconColor: c.orange,
            title: tr('Auto-SOS on critical alerts'),
            subtitle: tr('Opens SOS when a safety limit is reached'),
            trailing: CupertinoSwitch(value: prefs.autoSos, onChanged: (v) => store.updatePrefs((x) => x.autoSos = v)),
            chevron: false,
          ),
        ]),
        FormGroup(header: tr('Alerts'), footer: tr('Your alert threshold is {n}%. It is learned from feedback and can\'t go above 75%.', {'n': (e.tau * 100).round()}), children: [
          IOSRow(icon: CupertinoIcons.bell_fill, iconColor: c.red, title: tr('Notifications'), trailing: CupertinoSwitch(value: prefs.notifications, onChanged: (v) => store.updatePrefs((x) => x.notifications = v)), chevron: false),
          IOSRow(icon: CupertinoIcons.person_2_fill, iconColor: c.orange, title: tr('Tell my caregiver'), subtitle: tr('If I don\'t reply in 10 minutes'), trailing: CupertinoSwitch(value: prefs.caregiverEscalation, onChanged: (v) => store.updatePrefs((x) => x.caregiverEscalation = v)), chevron: false),
          IOSRow(icon: CupertinoIcons.share_up, iconColor: c.blue, title: tr('Share vitals with my care team'), trailing: CupertinoSwitch(value: prefs.shareWithCareTeam, onChanged: (v) => store.updatePrefs((x) => x.shareWithCareTeam = v)), chevron: false),
          IOSRow(icon: CupertinoIcons.slider_horizontal_3, iconColor: c.gray, title: tr('Band simulator'), subtitle: tr('Demo scenarios'), onTap: () => showSimulator(context)),
        ]),
        FormGroup(header: tr('Preferences'), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 10, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [IconSquare(CupertinoIcons.circle_lefthalf_fill, c.indigo), const SizedBox(width: 14), Text(tr('Appearance'), style: T.body.copyWith(color: c.label))]),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: prefs.theme,
                children: {'system': Text(tr('Auto')), 'light': Text(tr('Light')), 'dark': Text(tr('Dark'))},
                onValueChanged: (v) => store.updatePrefs((x) => x.theme = v ?? 'system'),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 10, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [IconSquare(CupertinoIcons.thermometer, c.orange), const SizedBox(width: 14), Text(tr('Temperature'), style: T.body.copyWith(color: c.label))]),
              CupertinoSlidingSegmentedControl<bool>(
                groupValue: prefs.fahrenheit,
                children: const {false: Text('°C'), true: Text('°F')},
                onValueChanged: (v) => store.updatePrefs((x) => x.fahrenheit = v ?? false),
              ),
            ]),
          ),
          const LanguageRow(),
          IOSRow(icon: CupertinoIcons.person_crop_circle_badge_checkmark, iconColor: c.blue, title: tr('Accessibility'), subtitle: tr('Larger text, easy home, flash and spoken alerts'), onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const AccessibilityScreen()))),
        ]),
        FormGroup(header: tr('About'), children: [
          IOSRow(icon: CupertinoIcons.info_circle_fill, iconColor: c.gray, title: 'PulseOS', subtitle: tr('Version 1.0 · AdaptAlert engine · student research prototype, not a medical device'), chevron: false),
          IOSRow(icon: CupertinoIcons.lock_fill, iconColor: c.green, title: tr('Privacy'), subtitle: switch (s.mode) { AuthMode.demo => tr('Demo Mode: all data stays on this device'), AuthMode.local => tr('Account stored on this device; the password is kept only as a salted hash'), AuthMode.cloud => tr('Signed in with Supabase. Health data in this build stays on this device.') }, chevron: false),
        ]),
        const SizedBox(height: 20),
        GroupedList(children: [
          IOSRow(
            title: s.demo ? tr('Leave Demo Mode') : tr('Sign out'),
            destructive: true,
            chevron: false,
            onTap: () async {
              if (await confirm(context, title: s.demo ? tr('Leave Demo Mode?') : tr('Sign out?'), message: tr('Your data stays on this device for next time.'), action: s.demo ? tr('Leave') : tr('Sign out'))) {
                await s.signOut();
              }
            },
          ),
        ]),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(value, style: T.headline.copyWith(color: c.label)),
          Text(label, style: T.caption.copyWith(color: c.label2)),
        ]),
      ),
    );
  }
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key});
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final p = context.read<PatientStore>().profile;
  late final _name = TextEditingController(text: p.name), _email = TextEditingController(text: p.email), _phone = TextEditingController(text: p.phone);
  late final _age = TextEditingController(text: '${p.age}'), _h = TextEditingController(text: '${p.heightCm.round()}'), _w = TextEditingController(text: '${p.weightKg.round()}');
  late final _city = TextEditingController(text: p.city), _cond = TextEditingController(text: p.conditions.join(', ')), _allergy = TextEditingController(text: p.allergies.join(', '));
  late String _blood = p.bloodGroup, _sex = p.sex;
  late final List<Medication> _meds = p.medications.map((m) => Medication(name: m.name, dose: m.dose, schedule: m.schedule)).toList();

  @override
  void dispose() {
    for (final x in [_name, _email, _phone, _age, _h, _w, _city, _cond, _allergy]) {
      x.dispose();
    }
    super.dispose();
  }

  List<String> _split(String s) => s.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

  Future<void> _editMed([int? i]) async {
    final m = i == null ? Medication(name: '', dose: '', schedule: '') : _meds[i];
    final n = TextEditingController(text: m.name), d = TextEditingController(text: m.dose), s = TextEditingController(text: m.schedule);
    final ok = await showSheet<bool>(context, (ctx) {
      final c = ctx.ios;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(i == null ? tr('Add medicine') : tr('Edit medicine'), style: T.title2.copyWith(color: c.label)),
          FormGroup(children: [FormField2(label: tr('Name'), controller: n), FormField2(label: tr('Dose'), controller: d, hint: tr('e.g. 75 mg')), FormField2(label: tr('When'), controller: s, hint: tr('e.g. Twice daily'))]),
          const SizedBox(height: 16),
          CupertinoButton.filled(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Done'))),
          if (i != null) CupertinoButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Remove medicine'), style: TextStyle(color: c.red))),
        ]),
      );
    });
    setState(() {
      if (ok == true && n.text.trim().isNotEmpty) {
        final med = Medication(name: n.text.trim(), dose: d.text.trim(), schedule: s.text.trim());
        i == null ? _meds.add(med) : _meds[i] = med;
      } else if (ok == false && i != null) {
        _meds.removeAt(i);
      }
    });
    n.dispose();
    d.dispose();
    s.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(
        backgroundColor: c.material,
        leading: CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
        middle: Text(tr('Profile')),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            if (_name.text.trim().isEmpty) return toast(context, tr('Add your name'));
            context.read<PatientStore>().updateProfile((x) => x
              ..name = _name.text.trim()
              ..email = _email.text.trim()
              ..phone = _phone.text.trim()
              ..age = int.tryParse(_age.text) ?? x.age
              ..heightCm = double.tryParse(_h.text) ?? x.heightCm
              ..weightKg = double.tryParse(_w.text) ?? x.weightKg
              ..city = _city.text.trim()
              ..sex = _sex
              ..bloodGroup = _blood
              ..conditions = _split(_cond.text)
              ..allergies = _split(_allergy.text)
              ..medications = _meds);
            Navigator.pop(context);
            toast(context, tr('Profile saved'));
          },
          child: Text(tr('Save'), style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        FormGroup(header: tr('About you'), children: [
          FormField2(label: tr('Name'), controller: _name),
          FormField2(label: tr('Email'), controller: _email, keyboard: TextInputType.emailAddress),
          FormField2(label: tr('Phone'), controller: _phone, keyboard: TextInputType.phone),
          FormField2(label: tr('City'), controller: _city),
          Padding(
            padding: const EdgeInsets.all(12),
            child: CupertinoSlidingSegmentedControl<String>(groupValue: _sex, children: {'F': Text(tr('Female')), 'M': Text(tr('Male')), 'O': Text(tr('Other'))}, onValueChanged: (v) => setState(() => _sex = v ?? 'F')),
          ),
        ]),
        FormGroup(header: tr('Body'), children: [
          FormField2(label: tr('Age'), controller: _age, keyboard: TextInputType.number),
          FormField2(label: tr('Height (cm)'), controller: _h, keyboard: TextInputType.number),
          FormField2(label: tr('Weight (kg)'), controller: _w, keyboard: TextInputType.number),
          IOSRow(
            title: tr('Blood group'),
            trailing: Text(_blood, style: T.sub.copyWith(color: c.label2)),
            onTap: () async {
              final v = await showCupertinoModalPopup<String>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  actions: [for (final b in const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']) CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, b), child: Text(b))],
                  cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
                ),
              );
              if (v != null) setState(() => _blood = v);
            },
          ),
        ]),
        FormGroup(header: tr('Medical'), footer: tr('Separate items with commas. Shown on your Medical ID.'), children: [
          FormField2(label: tr('Conditions'), controller: _cond, maxLines: 2),
          FormField2(label: tr('Allergies'), controller: _allergy, maxLines: 2),
        ]),
        FormGroup(header: tr('Medicines'), children: [
          for (final (i, m) in _meds.indexed) IOSRow(icon: CupertinoIcons.capsule_fill, iconColor: c.purple, title: '${m.name} ${m.dose}', subtitle: trData(m.schedule), onTap: () => _editMed(i)),
          IOSRow(icon: CupertinoIcons.add, iconColor: c.green, title: tr('Add medicine'), chevron: false, onTap: _editMed),
        ]),
      ]),
    );
  }
}
