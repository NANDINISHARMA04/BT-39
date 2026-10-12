import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/patient_models.dart';
import '../../services/monitor.dart';
import '../../services/patient_store.dart';
import '../../services/session.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
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
      title: 'Me',
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
                  Text(p.email.isEmpty ? 'No email' : p.email, style: T.footnote.copyWith(color: c.label2)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    Pill(switch (s.mode) { AuthMode.demo => 'Demo Mode', AuthMode.local => 'Device account', AuthMode.cloud => 'Signed in' }, color: s.demo ? c.orange : c.green, icon: s.demo ? CupertinoIcons.play_circle_fill : CupertinoIcons.checkmark_shield_fill),
                    Pill('Edit profile', color: c.blue),
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
            _Fact('Age', '${p.age}'),
            _Fact('Blood', p.bloodGroup),
            _Fact('BMI', p.bmi.toStringAsFixed(1)),
            _Fact('Height', '${p.heightCm.round()} cm'),
          ]),
        ),
        FormGroup(header: 'Health', children: [
          IOSRow(icon: CupertinoIcons.heart_circle_fill, iconColor: c.pink, title: 'Health profile', subtitle: '${p.conditions.length} condition${p.conditions.length == 1 ? '' : 's'} · ${p.medications.length} medicine${p.medications.length == 1 ? '' : 's'} · ${p.allergies.length} allerg${p.allergies.length == 1 ? 'y' : 'ies'}', onTap: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const ProfileEditor()))),
          IOSRow(icon: CupertinoIcons.doc_text_fill, iconColor: c.teal, title: 'Medical records', subtitle: '${store.records.length} files', onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const RecordsScreen()))),
          IOSRow(icon: CupertinoIcons.shield_lefthalf_fill, iconColor: c.green, title: 'Insurance & claims', subtitle: '${store.policies.length} polic${store.policies.length == 1 ? 'y' : 'ies'} · ${store.claims.length} claims', onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const InsuranceScreen()))),
          IOSRow(icon: CupertinoIcons.person_3_fill, iconColor: c.orange, title: 'Family', subtitle: '${store.family.length} members · caregiver ${store.caregiver?.name.split(' ').first ?? 'not set'}', onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const FamilyScreen()))),
        ]),
        FormGroup(header: 'Emergency', children: [
          IOSRow(icon: CupertinoIcons.exclamationmark_octagon_fill, iconColor: c.red, title: 'Emergency SOS', subtitle: 'Call 112 and alert ${store.emergencyContacts.length} contacts', onTap: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const SosScreen()))),
          IOSRow(icon: CupertinoIcons.staroflife_fill, iconColor: c.red, title: 'Medical ID', subtitle: 'What responders see', onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const MedicalIdScreen()))),
          IOSRow(
            icon: CupertinoIcons.bolt_fill,
            iconColor: c.orange,
            title: 'Auto-SOS on critical alerts',
            subtitle: 'Opens SOS when a safety limit is reached',
            trailing: CupertinoSwitch(value: prefs.autoSos, onChanged: (v) => store.updatePrefs((x) => x.autoSos = v)),
            chevron: false,
          ),
        ]),
        FormGroup(header: 'Alerts', footer: 'Your alert threshold is ${(e.tau * 100).round()}%. It is learned from feedback and can\'t go above 75%.', children: [
          IOSRow(icon: CupertinoIcons.bell_fill, iconColor: c.red, title: 'Notifications', trailing: CupertinoSwitch(value: prefs.notifications, onChanged: (v) => store.updatePrefs((x) => x.notifications = v)), chevron: false),
          IOSRow(icon: CupertinoIcons.person_2_fill, iconColor: c.orange, title: 'Tell my caregiver', subtitle: 'If I don\'t reply in 10 minutes', trailing: CupertinoSwitch(value: prefs.caregiverEscalation, onChanged: (v) => store.updatePrefs((x) => x.caregiverEscalation = v)), chevron: false),
          IOSRow(icon: CupertinoIcons.share_up, iconColor: c.blue, title: 'Share vitals with my care team', trailing: CupertinoSwitch(value: prefs.shareWithCareTeam, onChanged: (v) => store.updatePrefs((x) => x.shareWithCareTeam = v)), chevron: false),
          IOSRow(icon: CupertinoIcons.slider_horizontal_3, iconColor: c.gray, title: 'Band simulator', subtitle: 'Demo scenarios', onTap: () => showSimulator(context)),
        ]),
        FormGroup(header: 'Preferences', children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 10, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [IconSquare(CupertinoIcons.circle_lefthalf_fill, c.indigo), const SizedBox(width: 14), Text('Appearance', style: T.body.copyWith(color: c.label))]),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: prefs.theme,
                children: const {'system': Text('Auto'), 'light': Text('Light'), 'dark': Text('Dark')},
                onValueChanged: (v) => store.updatePrefs((x) => x.theme = v ?? 'system'),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 10, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [IconSquare(CupertinoIcons.thermometer, c.orange), const SizedBox(width: 14), Text('Temperature', style: T.body.copyWith(color: c.label))]),
              CupertinoSlidingSegmentedControl<bool>(
                groupValue: prefs.fahrenheit,
                children: const {false: Text('°C'), true: Text('°F')},
                onValueChanged: (v) => store.updatePrefs((x) => x.fahrenheit = v ?? false),
              ),
            ]),
          ),
          IOSRow(
            icon: CupertinoIcons.globe,
            iconColor: c.blue,
            title: 'Language',
            trailing: Text(prefs.language, style: T.sub.copyWith(color: c.label2)),
            onTap: () async {
              final v = await showCupertinoModalPopup<String>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  title: const Text('App language'),
                  message: const Text('Translations are planned. The app shows English for now.'),
                  actions: [for (final l in ['English', 'हिन्दी (Hindi)', 'தமிழ் (Tamil)', 'বাংলা (Bengali)']) CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, l), child: Text(l))],
                  cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ),
              );
              if (v != null) store.updatePrefs((x) => x.language = v);
            },
          ),
        ]),
        FormGroup(header: 'About', children: [
          IOSRow(icon: CupertinoIcons.info_circle_fill, iconColor: c.gray, title: 'PulseOS', subtitle: 'Version 1.0 · AdaptAlert engine · student research prototype, not a medical device', chevron: false),
          IOSRow(icon: CupertinoIcons.lock_fill, iconColor: c.green, title: 'Privacy', subtitle: switch (s.mode) { AuthMode.demo => 'Demo Mode: all data stays on this device', AuthMode.local => 'Account stored on this device; the password is kept only as a salted hash', AuthMode.cloud => 'Signed in with Supabase. Health data in this build stays on this device.' }, chevron: false),
        ]),
        const SizedBox(height: 20),
        GroupedList(children: [
          IOSRow(
            title: s.demo ? 'Leave Demo Mode' : 'Sign out',
            destructive: true,
            chevron: false,
            onTap: () async {
              if (await confirm(context, title: s.demo ? 'Leave Demo Mode?' : 'Sign out?', message: 'Your data stays on this device for next time.', action: s.demo ? 'Leave' : 'Sign out')) {
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
          Text(i == null ? 'Add medicine' : 'Edit medicine', style: T.title2.copyWith(color: c.label)),
          FormGroup(children: [FormField2(label: 'Name', controller: n), FormField2(label: 'Dose', controller: d, hint: 'e.g. 75 mg'), FormField2(label: 'When', controller: s, hint: 'e.g. Twice daily')]),
          const SizedBox(height: 16),
          CupertinoButton.filled(onPressed: () => Navigator.pop(ctx, true), child: const Text('Done')),
          if (i != null) CupertinoButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Remove medicine', style: TextStyle(color: c.red))),
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
        leading: CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        middle: const Text('Profile'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            if (_name.text.trim().isEmpty) return toast(context, 'Add your name');
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
            toast(context, 'Profile saved');
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        FormGroup(header: 'About you', children: [
          FormField2(label: 'Name', controller: _name),
          FormField2(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress),
          FormField2(label: 'Phone', controller: _phone, keyboard: TextInputType.phone),
          FormField2(label: 'City', controller: _city),
          Padding(
            padding: const EdgeInsets.all(12),
            child: CupertinoSlidingSegmentedControl<String>(groupValue: _sex, children: const {'F': Text('Female'), 'M': Text('Male'), 'O': Text('Other')}, onValueChanged: (v) => setState(() => _sex = v ?? 'F')),
          ),
        ]),
        FormGroup(header: 'Body', children: [
          FormField2(label: 'Age', controller: _age, keyboard: TextInputType.number),
          FormField2(label: 'Height (cm)', controller: _h, keyboard: TextInputType.number),
          FormField2(label: 'Weight (kg)', controller: _w, keyboard: TextInputType.number),
          IOSRow(
            title: 'Blood group',
            trailing: Text(_blood, style: T.sub.copyWith(color: c.label2)),
            onTap: () async {
              final v = await showCupertinoModalPopup<String>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  actions: [for (final b in const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']) CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, b), child: Text(b))],
                  cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ),
              );
              if (v != null) setState(() => _blood = v);
            },
          ),
        ]),
        FormGroup(header: 'Medical', footer: 'Separate items with commas. Shown on your Medical ID.', children: [
          FormField2(label: 'Conditions', controller: _cond, maxLines: 2),
          FormField2(label: 'Allergies', controller: _allergy, maxLines: 2),
        ]),
        FormGroup(header: 'Medicines', children: [
          for (final (i, m) in _meds.indexed) IOSRow(icon: CupertinoIcons.capsule_fill, iconColor: c.purple, title: '${m.name} ${m.dose}', subtitle: m.schedule, onTap: () => _editMed(i)),
          IOSRow(icon: CupertinoIcons.add, iconColor: c.green, title: 'Add medicine', chevron: false, onTap: _editMed),
        ]),
      ]),
    );
  }
}
