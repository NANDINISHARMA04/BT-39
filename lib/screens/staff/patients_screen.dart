import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../engine/adapt_alert.dart';
import '../../models/patient_models.dart';
import '../../services/clinical_store.dart';
import '../../services/monitor.dart';
import '../../services/session.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/vitals.dart';
import '../patient/alert_detail_screen.dart';
import '../patient/alerts_screen.dart';
import 'schedule_screen.dart';
import 'staff_shell.dart';

void openPatient(BuildContext context, String id) => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => PatientDetailScreen(id: id)));

/// The live patient's status, from the band.
(String, Color) patientStatus(BuildContext context, CarePatient p) {
  final c = context.ios;
  if (p.live) {
    final st = context.watch<MonitorController>().engine.status;
    return switch (st) {
      'alert' => ('Alert', c.red),
      'watch' => ('Watching', c.orange),
      'held' => ('Learned pattern', c.indigo),
      'band' => ('No signal', c.gray),
      _ => ('Stable', c.green),
    };
  }
  if (p.source == PatientSource.account && p.store == null) return ('New', c.blue);
  return p.status == 'Watching' ? ('Watching', c.orange) : ('Stable', c.green);
}

String _ageSex(CarePatient p) => [if (p.age > 0) '${p.age}', if (p.sex.isNotEmpty) p.sex, if (p.store != null || p.source == PatientSource.example) p.bloodGroup].join(' · ');

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});
  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  String _q = '';
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    // Picks up patients who signed up on this device since the list was built.
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? context.read<ClinicalStore>().refreshPatients() : null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final cs = context.watch<ClinicalStore>();
    final q = _q.trim().toLowerCase();
    final list = cs.patients.where((p) {
      if (q.isNotEmpty && !'${p.name} ${p.condition} ${p.phone} ${p.email ?? ''}'.toLowerCase().contains(q)) return false;
      return switch (_filter) {
        'Live band' => p.live,
        'Signed up' => p.source != PatientSource.example,
        'Watching' => patientStatus(context, p).$1 != 'Stable',
        _ => true,
      };
    }).toList();
    return LargeTitlePage(
      title: 'Patients',
      subtitle: '${cs.patients.length} patients · home monitoring and clinic',
      children: [
        CupertinoSearchTextField(placeholder: 'Search by name, condition or phone', onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in ['All', 'Live band', 'Signed up', 'Watching'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: Pill(f, color: _filter == f ? c.blue : null, solid: _filter == f),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const EmptyState(icon: CupertinoIcons.person_2, title: 'No patients found', message: 'Try another name, or clear the filter.')
        else
          GroupedList(children: [
            for (final p in list)
              Builder(builder: (context) {
                final (st, col) = patientStatus(context, p);
                return IOSRow(
                  leading: Avatar(p.name, size: 40, colors: p.live ? [c.orange, c.pink] : p.source == PatientSource.account ? [c.indigo, c.blue] : [c.teal, c.green]),
                  title: p.name,
                  subtitle: '${_ageSex(p)}${_ageSex(p).isEmpty ? '' : ' · '}${p.condition}',
                  trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Pill(st, color: col),
                    if (p.live) Padding(padding: const EdgeInsets.only(top: 4), child: Text('band live', style: T.caption.copyWith(color: c.green))),
                  ]),
                  onTap: () => openPatient(context, p.id),
                );
              }),
          ]),
        const SizedBox(height: 10),
        Text('Patients who sign up on this device appear here automatically. Example patients are fictional.', textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
      ],
    );
  }
}

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  int _seg = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final cs = context.watch<ClinicalStore>();
    final s = context.watch<Session>();
    final p = cs.byId(widget.id);
    if (p == null) return const LargeTitlePage(title: 'Patient', children: [EmptyState(icon: CupertinoIcons.person, title: 'Patient not found', message: 'They may have been removed from this device.')]);
    final doctor = s.role == Role.doctor;
    final (st, col) = patientStatus(context, p);
    return LargeTitlePage(
      title: p.name,
      previousTitle: 'Back',
      children: [
        IOSCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(p.name, size: 56, colors: p.live ? [c.orange, c.pink] : [c.teal, c.blue]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_ageSex(p), style: T.footnote.copyWith(color: c.label2)),
                  Text(p.condition, style: T.headline.copyWith(color: c.label)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    Pill(st, color: col),
                    Pill(switch (p.source) { PatientSource.live => 'Home band', PatientSource.account => 'App account', PatientSource.example => 'Example' }, color: c.indigo),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              if (p.phone.isNotEmpty) _Action(CupertinoIcons.phone_fill, 'Call', c.green, () => launchUrl(Uri.parse('tel:${p.phone.replaceAll(' ', '')}'))),
              _Action(CupertinoIcons.pencil, 'Note', c.orange, () => showNoteSheet(context, p)),
              if (doctor) ...[
                _Action(CupertinoIcons.capsule_fill, 'Prescribe', c.teal, () => showPrescribeSheet(context, p)),
                _Action(CupertinoIcons.calendar_badge_plus, 'Book', c.blue, () => showBookSheet(context, p)),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        CupertinoSlidingSegmentedControl<int>(
          groupValue: _seg,
          children: const {0: Text('Overview'), 1: Text('Alerts'), 2: Text('Records'), 3: Text('Notes')},
          onValueChanged: (v) => setState(() => _seg = v ?? 0),
        ),
        const SizedBox(height: 4),
        ...switch (_seg) {
          1 => _alerts(context, p),
          2 => _records(context, p),
          3 => _notes(context, p, cs),
          _ => _overview(context, p, cs),
        },
      ],
    );
  }

  List<Widget> _overview(BuildContext context, CarePatient p, ClinicalStore cs) {
    final c = context.ios;
    final m = context.watch<MonitorController>();
    final e = m.engine;
    final r = m.last;
    final upcoming = cs.upcomingFor(p.id);
    Widget vital(String l, String v, String u, Color col) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: T.caption.copyWith(color: col, fontWeight: FontWeight.w600)),
            Text.rich(TextSpan(children: [TextSpan(text: v, style: T.title3.copyWith(color: c.label, fontFeatures: T.num)), TextSpan(text: ' $u', style: T.caption.copyWith(color: c.label2))]), maxLines: 1),
          ]),
        );
    return [
      SectionHeader(p.live ? 'Live vitals' : 'Last vitals', trailing: p.live ? 'from the wrist band' : (p.vitals == null ? null : '2 h ago')),
      if (p.live && r != null)
        IOSCard(
          child: Column(children: [
            Row(children: [
              vital('HR', r.good ? '${r.r.hr}' : '--', 'bpm', c.pink),
              vital('SpO₂', r.good ? '${r.r.spo2}' : '--', '%', c.blue),
              vital('Temp', r.good ? r.r.temp.toStringAsFixed(1) : '--', '°C', c.orange),
              vital('Activity', r.act, '', c.green),
            ]),
            const SizedBox(height: 10),
            Sparkline(e.history.reversed.take(60).toList().reversed.map((h) => h.good ? h.r.hr : null).toList(), color: c.pink, width: double.infinity, height: 40),
          ]),
        )
      else if (p.vitals != null)
        IOSCard(
          child: Row(children: [
            vital('HR', '${p.vitals!.hr}', 'bpm', c.pink),
            vital('SpO₂', '${p.vitals!.spo2}', '%', c.blue),
            vital('Temp', p.vitals!.temp.toStringAsFixed(1), '°C', c.orange),
          ]),
        )
      else
        const EmptyState(icon: CupertinoIcons.waveform, title: 'No readings yet', message: 'Readings appear once the patient pairs a band.'),
      if (p.live) ...[
        const SectionHeader('AdaptAlert'),
        IOSCard(
          onTap: () => openStaffSection(context, StaffSec.review),
          child: Row(children: [
            IconSquare(CupertinoIcons.sparkles, c.indigo),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sensitivity τ ${pct(e.tau)} · ${e.labels} feedback answers · ${e.held.length} alerts held back · ${e.alerts.where((a) => a.doctor == DoctorLabel.pending).length} to review',
                style: T.footnote.copyWith(color: c.label),
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 14, color: c.label3),
          ]),
        ),
      ],
      if (p.learned != null) ...[
        const SizedBox(height: 10),
        IOSCard(child: Row(children: [Icon(CupertinoIcons.sparkles, color: c.indigo), const SizedBox(width: 10), Expanded(child: Text('AdaptAlert learned: ${p.learned}', style: T.footnote.copyWith(color: c.label)))])),
      ],
      const SectionHeader('Conditions'),
      if (p.conditions.isEmpty)
        Text('None recorded.', style: T.footnote.copyWith(color: c.label2))
      else
        GroupedList(children: [for (final x in p.conditions) IOSRow(icon: CupertinoIcons.heart_fill, iconColor: c.pink, title: x, chevron: false)]),
      const SectionHeader('Allergies'),
      if (p.allergies.isEmpty)
        Text('No known allergies.', style: T.footnote.copyWith(color: c.label2))
      else
        Wrap(spacing: 6, runSpacing: 6, children: [for (final a in p.allergies) Pill(a, color: c.red, icon: CupertinoIcons.exclamationmark_triangle_fill)]),
      SectionHeader('Medicines', trailing: '${p.medications.length}'),
      if (p.medications.isEmpty)
        Text('No medicines recorded.', style: T.footnote.copyWith(color: c.label2))
      else
        GroupedList(children: [for (final x in p.medications) IOSRow(icon: CupertinoIcons.capsule_fill, iconColor: c.green, title: '${x.name} ${x.dose}', subtitle: x.schedule, chevron: false)]),
      SectionHeader('Upcoming visits', trailing: '${upcoming.length}'),
      if (upcoming.isEmpty) Text('None booked.', style: T.footnote.copyWith(color: c.label2)) else GroupedList(children: [for (final v in upcoming) VisitRow(v: v)]),
    ];
  }

  List<Widget> _alerts(BuildContext context, CarePatient p) {
    final c = context.ios;
    final s = context.watch<Session>();
    if (!p.live) {
      return [
        const SizedBox(height: 12),
        EmptyState(
          icon: CupertinoIcons.checkmark_seal,
          title: 'No alerts this week',
          message: p.learned != null ? 'AdaptAlert has learned ${p.learned!.toLowerCase()}, so those readings no longer alert.' : 'AdaptAlert alerts for this patient appear here.',
        ),
      ];
    }
    final e = context.watch<MonitorController>().engine;
    final pending = e.alerts.where((a) => a.doctor == DoctorLabel.pending).toList();
    final reviewed = e.alerts.where((a) => a.doctor != DoctorLabel.pending).toList();
    return [
      SectionHeader('To review', trailing: '${pending.length}'),
      if (pending.isEmpty)
        const EmptyState(icon: CupertinoIcons.checkmark_seal, title: 'Nothing to review', message: 'Use "Simulate home patient" to make an alert.')
      else
        for (final a in pending) AlertCard(a: a, staffMode: true, reviewer: s.name),
      if (reviewed.isNotEmpty) ...[
        SectionHeader('Reviewed', trailing: '${reviewed.length}'),
        GroupedList(children: [
          for (final a in reviewed)
            IOSRow(
              icon: a.doctor == DoctorLabel.confirmed ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle_fill,
              iconColor: a.doctor == DoctorLabel.confirmed ? c.red : c.green,
              title: a.title,
              subtitle: '${hhmm(a.t)} · ${a.doctor == DoctorLabel.confirmed ? 'Confirmed real' : 'False alarm'}${a.reviewedBy == null ? '' : ' · ${a.reviewedBy}'}',
              onTap: () => openAlertDetail(context, a, staffMode: true, reviewer: s.name),
            ),
        ]),
      ],
    ];
  }

  List<Widget> _records(BuildContext context, CarePatient p) {
    final c = context.ios;
    final recs = p.records.isNotEmpty || p.source != PatientSource.example
        ? p.records
        : [
            MedicalRecord(id: 'x1', title: 'Last clinic letter', category: 'Discharge summary', date: DateTime.now().subtract(const Duration(days: 20)), forMember: 'self', fileName: 'clinic_letter.pdf', sizeBytes: 182220, notes: p.condition),
            MedicalRecord(id: 'x2', title: 'Blood tests', category: 'Lab report', date: DateTime.now().subtract(const Duration(days: 9)), forMember: 'self', fileName: 'labs.pdf', sizeBytes: 96410, notes: 'Within the expected range for this patient.'),
          ];
    if (recs.isEmpty) return [const SizedBox(height: 12), const EmptyState(icon: CupertinoIcons.doc, title: 'No shared records', message: 'Records the patient shares with their care team appear here.')];
    return [
      SectionHeader('Shared with the care team', trailing: '${recs.length}'),
      GroupedList(children: [
        for (final r in recs)
          IOSRow(
            icon: r.category == 'Imaging' ? CupertinoIcons.photo_fill : r.category == 'Prescription' ? CupertinoIcons.capsule_fill : CupertinoIcons.doc_text_fill,
            iconColor: r.category == 'Lab report' ? c.purple : c.blue,
            title: r.title,
            subtitle: '${r.category} · ${DateFormat('d MMM y').format(r.date)} · ${r.fileName}',
            onTap: () => showSheet(context, (ctx) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.title, style: T.title2.copyWith(color: c.label)),
                    Text('${r.category} · ${DateFormat('d MMM y').format(r.date)} · ${(r.sizeBytes / 1024).round()} KB', style: T.footnote.copyWith(color: c.label2)),
                    const SizedBox(height: 14),
                    Text(r.notes.isEmpty ? 'No notes.' : r.notes, style: T.body.copyWith(color: c.label)),
                  ]),
                )),
          ),
      ]),
    ];
  }

  List<Widget> _notes(BuildContext context, CarePatient p, ClinicalStore cs) {
    final c = context.ios;
    final notes = cs.notesFor(p.id);
    (IconData, Color, String) look(String k) => switch (k) {
          'prescription' => (CupertinoIcons.capsule_fill, c.green, 'Prescription'),
          'consult' => (CupertinoIcons.person_crop_circle_badge_checkmark, c.blue, 'Consultation'),
          'nursing' => (CupertinoIcons.bandage_fill, c.teal, 'Nursing note'),
          _ => (CupertinoIcons.pencil, c.orange, 'Note'),
        };
    return [
      SectionHeader('Notes and prescriptions', trailing: '+ Add', onTrailing: () => showNoteSheet(context, p)),
      if (notes.isEmpty)
        const EmptyState(icon: CupertinoIcons.doc_text, title: 'No notes yet', message: 'Notes from doctors and nurses appear here.')
      else
        for (final n in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IOSCard(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconSquare(look(n.kind).$1, look(n.kind).$2),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(look(n.kind).$3.toUpperCase(), style: T.caption.copyWith(color: look(n.kind).$2, fontWeight: FontWeight.w700, letterSpacing: .4)),
                    const SizedBox(height: 2),
                    Text(n.text, style: T.body.copyWith(color: c.label)),
                    const SizedBox(height: 4),
                    Text('${n.by} · ${DateFormat('d MMM, h:mm a').format(n.at)}', style: T.caption.copyWith(color: c.label2)),
                  ]),
                ),
              ]),
            ),
          ),
    ];
  }
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Pressable(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

/// Adds a doctor's note or consultation, or a nursing note.
Future<void> showNoteSheet(BuildContext context, CarePatient p) {
  final cs = context.read<ClinicalStore>();
  final doctor = context.read<Session>().role == Role.doctor;
  final text = TextEditingController();
  var kind = doctor ? 'note' : 'nursing';
  return showSheet(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final c = ctx.ios;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Note for ${p.name}', style: T.title3.copyWith(color: c.label)),
            const SizedBox(height: 12),
            if (doctor)
              CupertinoSlidingSegmentedControl<String>(
                groupValue: kind,
                children: const {'note': Text('Note'), 'consult': Text('Consultation')},
                onValueChanged: (v) => set(() => kind = v ?? 'note'),
              ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: text,
              autofocus: true,
              placeholder: doctor ? 'Findings, plan, advice…' : 'Observations, care given, concerns…',
              maxLines: 6,
              minLines: 4,
              padding: const EdgeInsets.all(12),
              style: T.body.copyWith(color: c.label),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 14),
            CupertinoButton.filled(
              onPressed: () async {
                if (text.text.trim().isEmpty) return;
                await cs.addNote(p.id, kind, text.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) toast(context, 'Note saved', 'Everyone on ${p.name.split(' ').first}\'s care team can see it.');
              },
              child: const Text('Save note'),
            ),
          ]),
        );
      },
    ),
  );
}

/// Prescribes a medicine. Patients with an account see it in their medicines.
Future<void> showPrescribeSheet(BuildContext context, CarePatient p) {
  final cs = context.read<ClinicalStore>();
  final name = TextEditingController(), dose = TextEditingController(), sched = TextEditingController(), days = TextEditingController();
  return showSheet(
    context,
    (ctx) {
      final c = ctx.ios;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Prescribe for ${p.name}', style: T.title3.copyWith(color: c.label)),
          if (p.allergies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Pill('Allergic to ${p.allergies.join(', ')}', color: c.red, icon: CupertinoIcons.exclamationmark_triangle_fill),
          ],
          FormGroup(children: [
            FormField2(label: 'Medicine', controller: name, hint: 'e.g. Furosemide'),
            FormField2(label: 'Dose', controller: dose, hint: 'e.g. 40 mg'),
            FormField2(label: 'When', controller: sched, hint: 'e.g. Every morning'),
            FormField2(label: 'For (days)', controller: days, hint: 'optional', keyboard: TextInputType.number),
          ]),
          const SizedBox(height: 14),
          CupertinoButton.filled(
            onPressed: () async {
              if (name.text.trim().isEmpty || dose.text.trim().isEmpty) return;
              final allergic = p.allergies.any((a) => name.text.toLowerCase().contains(a.toLowerCase().split(' ').first));
              if (allergic && !await confirm(ctx, title: 'Allergy warning', message: '${p.name} is allergic to ${p.allergies.join(', ')}. Prescribe anyway?', action: 'Prescribe')) return;
              await cs.prescribe(p, Medication(name: name.text.trim(), dose: dose.text.trim(), schedule: sched.text.trim().isEmpty ? 'As directed' : sched.text.trim()), days: days.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) toast(context, 'Prescription saved', p.store != null && p.source != PatientSource.example ? 'Added to ${p.name.split(' ').first}\'s medicine list too.' : null);
            },
            child: const Text('Save prescription'),
          ),
        ]),
      );
    },
  );
}
