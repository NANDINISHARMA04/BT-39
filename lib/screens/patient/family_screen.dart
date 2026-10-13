import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/patient_models.dart';
import '../../services/patient_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';

const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.watch<PatientStore>();
    final cg = store.caregiver;
    return LargeTitlePage(
      title: tr('Family'),
      previousTitle: tr('Back'),
      subtitle: tr('Profiles, caregiver and emergency contacts'),
      trailing: Semantics(
        label: tr('Add family member'),
        button: true,
        child: Pressable(onTap: () => _edit(context, null), child: Icon(CupertinoIcons.person_crop_circle_fill_badge_plus, color: c.blue, size: 28)),
      ),
      children: [
        IOSCard(
          child: Row(children: [
            IconSquare(CupertinoIcons.bell_fill, c.orange, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cg == null
                    ? tr('No caregiver is set. A caregiver gets your alerts when you don\'t reply within 10 minutes, and every warning or urgent alert.')
                    : tr('{name} is your caregiver. They get warning and urgent alerts, and any alert you don\'t answer within 10 minutes.', {'name': cg.name}),
                style: T.footnote.copyWith(color: c.label, height: 1.35),
              ),
            ),
          ]),
        ),
        SectionHeader(tr('Members')),
        if (store.family.isEmpty) EmptyState(icon: CupertinoIcons.person_3, title: tr('No family members'), message: tr('Add the people you look after or who look after you.'), action: tr('Add a member'), onAction: () => _edit(context, null)),
        for (final (i, m) in store.family.indexed)
          FadeIn(
            delay: i * 60,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IOSCard(
                onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => MemberProfile(id: m.id))),
                child: Row(children: [
                  Avatar(m.name, size: 52, colors: [c.orange, c.pink]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.name, style: T.headline.copyWith(color: c.label)),
                      Text('${trData(m.relation)} · ${tr('{n} yrs', {'n': m.age})} · ${m.bloodGroup}', style: T.footnote.copyWith(color: c.label2)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (m.caregiver) Pill(tr('Caregiver'), color: c.orange),
                        if (m.emergencyContact) Pill(tr('Emergency contact'), color: c.red),
                        for (final cond in m.conditions) Pill(trData(cond)),
                      ]),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  const Chevron(),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

void _edit(BuildContext context, FamilyMember? m) => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => MemberEditor(member: m)));

class MemberProfile extends StatelessWidget {
  const MemberProfile({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.watch<PatientStore>();
    final m = store.family.where((x) => x.id == id).firstOrNull;
    if (m == null) return const SizedBox.shrink();
    final appts = store.upcoming.where((a) => a.forMember == id).toList();
    final recs = store.records.where((r) => r.forMember == id).toList();
    return PlainPage(
      previousTitle: tr('Family'),
      trailing: BarButton(tr('Edit'), onTap: () => _edit(context, m)),
      children: [
        Center(child: Avatar(m.name, size: 88, colors: [c.orange, c.pink])),
        const SizedBox(height: 10),
        Text(m.name, textAlign: TextAlign.center, style: T.title1.copyWith(color: c.label)),
        Text('${trData(m.relation)} · ${tr('{n} years', {'n': m.age})} · ${m.bloodGroup}', textAlign: TextAlign.center, style: T.sub.copyWith(color: c.label2)),
        const SizedBox(height: 16),
        GroupedList(children: [
          IOSRow(icon: CupertinoIcons.phone_fill, iconColor: c.green, title: m.phone.isEmpty ? tr('No phone number') : m.phone, subtitle: tr('Phone'), chevron: false),
          IOSRow(icon: CupertinoIcons.heart_circle_fill, iconColor: c.pink, title: m.conditions.isEmpty ? tr('None recorded') : m.conditions.map(trData).join(', '), subtitle: tr('Conditions'), chevron: false),
          IOSRow(icon: CupertinoIcons.bell_fill, iconColor: c.orange, title: tr('Caregiver'), trailing: CupertinoSwitch(value: m.caregiver, onChanged: (v) => _setCaregiver(store, m, v)), chevron: false),
          IOSRow(icon: CupertinoIcons.exclamationmark_octagon_fill, iconColor: c.red, title: tr('Emergency contact'), trailing: CupertinoSwitch(value: m.emergencyContact, onChanged: (v) => store.upsertMember(m..emergencyContact = v)), chevron: false),
        ]),
        SectionHeader(tr('Appointments'), trailing: '${appts.length}'),
        if (appts.isEmpty)
          IOSCard(child: Text(tr('Nothing booked for {name}.', {'name': m.name.split(' ').first}), style: T.sub.copyWith(color: c.label2)))
        else
          GroupedList(children: [
            for (final a in appts) IOSRow(icon: CupertinoIcons.calendar, iconColor: c.blue, title: doctorById(a.doctorId).name, subtitle: '${DateFormat('EEE d MMM, h:mm a').format(a.at)} · ${trData(a.reason)}', chevron: false),
          ]),
        SectionHeader(tr('Records'), trailing: '${recs.length}'),
        if (recs.isEmpty)
          IOSCard(child: Text(tr('No records yet.'), style: T.sub.copyWith(color: c.label2)))
        else
          GroupedList(children: [for (final r in recs) IOSRow(icon: CupertinoIcons.doc_text_fill, iconColor: c.teal, title: trData(r.title), subtitle: '${trData(r.category)} · ${DateFormat('d MMM y').format(r.date)}', chevron: false)]),
      ],
    );
  }
}

void _setCaregiver(PatientStore store, FamilyMember m, bool v) {
  if (v) {
    for (final x in store.family) {
      x.caregiver = false;
    }
  }
  store.upsertMember(m..caregiver = v);
}

class MemberEditor extends StatefulWidget {
  const MemberEditor({super.key, this.member});
  final FamilyMember? member;
  @override
  State<MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends State<MemberEditor> {
  late final m = widget.member;
  late final _name = TextEditingController(text: m?.name ?? ''), _rel = TextEditingController(text: m?.relation ?? ''), _age = TextEditingController(text: m == null ? '' : '${m!.age}');
  late final _phone = TextEditingController(text: m?.phone ?? ''), _cond = TextEditingController(text: m?.conditions.join(', ') ?? '');
  late String _blood = m?.bloodGroup ?? 'O+';
  late bool _caregiver = m?.caregiver ?? false, _emergency = m?.emergencyContact ?? false;

  @override
  void dispose() {
    for (final x in [_name, _rel, _age, _phone, _cond]) {
      x.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<PatientStore>();
    return PlainPage(
      title: m == null ? tr('Add member') : tr('Edit member'),
      leading: BarButton(tr('Cancel'), onTap: () => Navigator.pop(context)),
      trailing: BarButton(
        tr('Save'),
        bold: true,
        onTap: () {
          if (_name.text.trim().isEmpty || _rel.text.trim().isEmpty) return toast(context, tr('Add a name and relation'));
          final mem = FamilyMember(
            id: m?.id ?? store.newId(), name: _name.text.trim(), relation: _rel.text.trim(), age: int.tryParse(_age.text) ?? 0, bloodGroup: _blood, phone: _phone.text.trim(),
            conditions: _cond.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(), caregiver: false, emergencyContact: _emergency,
          );
          store.upsertMember(mem);
          _setCaregiver(store, mem, _caregiver);
          Navigator.pop(context);
          toast(context, m == null ? tr('{name} added', {'name': mem.name.split(' ').first}) : tr('Saved'));
        },
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        FormGroup(header: tr('Person'), children: [
          FormField2(label: tr('Name'), controller: _name, hint: tr('Full name')),
          FormField2(label: tr('Relation'), controller: _rel, hint: tr('e.g. Mother, Son')),
          FormField2(label: tr('Age'), controller: _age, keyboard: TextInputType.number),
          FormField2(label: tr('Phone'), controller: _phone, keyboard: TextInputType.phone, hint: '+91'),
          IOSRow(
            title: tr('Blood group'),
            value: _blood,
            onTap: () async {
              final v = await showCupertinoModalPopup<String>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  actions: [for (final b in _bloodGroups) CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, b), child: Text(b))],
                  cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
                ),
              );
              if (v != null) setState(() => _blood = v);
            },
          ),
          FormField2(label: tr('Conditions'), controller: _cond, hint: tr('Comma separated'), maxLines: 2),
        ]),
        FormGroup(header: tr('Roles'), footer: tr('Only one person can be the caregiver. Emergency contacts are alerted when you press SOS.'), children: [
          IOSRow(title: tr('Caregiver'), trailing: CupertinoSwitch(value: _caregiver, onChanged: (v) => setState(() => _caregiver = v)), chevron: false),
          IOSRow(title: tr('Emergency contact'), trailing: CupertinoSwitch(value: _emergency, onChanged: (v) => setState(() => _emergency = v)), chevron: false),
        ]),
        if (m != null) ...[
          const SizedBox(height: 24),
          AppButton(
            tr('Remove from family'),
            kind: ButtonKind.plain,
            destructive: true,
            onTap: () async {
              if (await confirm(context, title: tr('Remove {name}?', {'name': m!.name}), message: tr('Their upcoming appointments will be cancelled. Records stay in your vault.'), action: tr('Remove'))) {
                store.deleteMember(m!.id);
                if (context.mounted) {
                  // Close the editor and the member's profile behind it.
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.pop();
                }
              }
            },
          ),
        ],
      ],
    );
  }
}
