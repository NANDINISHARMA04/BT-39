import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/patient_models.dart';
import '../../services/patient_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import 'appointment_editor.dart';
import 'doctors_screen.dart';

class CareScreen extends StatefulWidget {
  const CareScreen({super.key});
  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> {
  bool _past = false;

  void _findDoctor([String? specialty]) => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => DoctorsScreen(specialty: specialty)));

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.watch<PatientStore>();
    final list = _past ? store.past : store.upcoming;
    return LargeTitlePage(
      title: tr('Care'),
      subtitle: tr('Appointments and doctors'),
      trailing: Semantics(
        label: tr('Book appointment'),
        button: true,
        child: Pressable(onTap: _findDoctor, child: Icon(CupertinoIcons.add_circled_solid, color: c.blue, size: 28)),
      ),
      children: [
        SearchBox(placeholder: tr('Search doctors, specialities, hospitals'), onTap: _findDoctor),
        const SizedBox(height: 14),
        SizedBox(
          height: 92,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final (s, short, icon, col) in [
              ('Cardiologist', tr('Heart'), CupertinoIcons.heart_fill, c.red),
              ('General Physician', tr('General'), CupertinoIcons.person_fill, c.blue),
              ('Pulmonologist', tr('Lungs'), CupertinoIcons.wind, c.teal),
              ('Endocrinologist', tr('Hormones'), CupertinoIcons.drop_fill, c.purple),
              ('Pediatrician', tr('Children'), CupertinoIcons.smiley_fill, c.orange),
              ('Neurologist', tr('Brain'), CupertinoIcons.bolt_fill, c.indigo),
              ('Psychiatrist', tr('Mind'), CupertinoIcons.cloud_sun_fill, c.green),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Pressable(
                  onTap: () => _findDoctor(s),
                  scale: .94,
                  child: SizedBox(
                    width: 84,
                    child: Column(children: [
                      Container(width: 56, height: 56, decoration: BoxDecoration(color: c.tint(col), borderRadius: BorderRadius.circular(R.md)), child: Icon(icon, color: col)),
                      const SizedBox(height: 6),
                      Text(hindi ? short : s.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: c.label)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 4),
        CupertinoSlidingSegmentedControl<bool>(
          groupValue: _past,
          children: {false: Text(tr('Upcoming ({n})', {'n': store.upcoming.length})), true: Text(tr('Past ({n})', {'n': store.past.length}))},
          onValueChanged: (v) => setState(() => _past = v ?? false),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          EmptyState(
            icon: CupertinoIcons.calendar,
            title: _past ? tr('No past appointments') : tr('Nothing booked'),
            message: _past ? tr('Completed and cancelled visits show up here.') : tr('Find a doctor and book a video or clinic visit.'),
            action: _past ? null : tr('Find a doctor'),
            onAction: _findDoctor,
          )
        else
          for (final (i, a) in list.indexed) FadeIn(delay: i * 50, child: _ApptCard(a: a)),
      ],
    );
  }
}

class _ApptCard extends StatelessWidget {
  const _ApptCard({required this.a});
  final Appointment a;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.read<PatientStore>();
    final d = doctorById(a.doctorId);
    final (statusText, statusCol) = switch (a.status) {
      ApptStatus.upcoming => a.at.isBefore(DateTime.now().add(const Duration(hours: 24))) ? (tr('Soon'), c.orange) : (tr('Confirmed'), c.green),
      ApptStatus.completed => (tr('Completed'), c.gray),
      ApptStatus.cancelled => (tr('Cancelled'), c.red),
    };
    final upcoming = a.status == ApptStatus.upcoming;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IOSCard(
        onTap: upcoming ? () => _edit(context) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(d.name, size: 46, colors: [c.teal, c.blue]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name, style: T.headline.copyWith(color: c.label)),
                Text('${trData(d.specialty)} · ${d.hospital}', style: T.footnote.copyWith(color: c.label2), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Pill(statusText, color: statusCol),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.card2, borderRadius: BorderRadius.circular(R.sm)),
            child: Row(children: [
              Icon(CupertinoIcons.calendar, size: 18, color: c.blue),
              const SizedBox(width: 8),
              Expanded(child: Text(DateFormat('EEE d MMM · h:mm a').format(a.at), style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w600))),
              Icon(a.mode == ApptMode.video ? CupertinoIcons.video_camera_solid : CupertinoIcons.building_2_fill, size: 18, color: c.blue),
              const SizedBox(width: 6),
              Text(a.mode == ApptMode.video ? tr('Video') : tr('Clinic'), style: T.footnote.copyWith(color: c.label2)),
            ]),
          ),
          const SizedBox(height: 10),
          Text('${tr('For {name}', {'name': trData(store.memberName(a.forMember))})} · ${trData(a.reason)}', style: T.footnote.copyWith(color: c.label2)),
          if (a.fromAlert != null) Padding(padding: const EdgeInsets.only(top: 6), child: Pill(tr('Booked from an AdaptAlert alert'), icon: CupertinoIcons.sparkles, color: c.indigo)),
          if (upcoming) ...[
            const SizedBox(height: 12),
            Row(children: [
              if (a.mode == ApptMode.video) ...[
                Expanded(child: AppButton(tr('Join call'), size: ButtonSize.small, onTap: () => toast(context, tr('Video call'), tr('The call opens 10 minutes before the start time. Demo only.')))),
                const SizedBox(width: 8),
              ],
              Expanded(child: AppButton(tr('Reschedule'), kind: ButtonKind.tinted, size: ButtonSize.small, onTap: () => _edit(context))),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  tr('Cancel'),
                  kind: ButtonKind.tinted,
                  size: ButtonSize.small,
                  destructive: true,
                  onTap: () async {
                    if (await confirm(context, title: tr('Cancel appointment?'), message: '${d.name}, ${DateFormat('EEE d MMM, h:mm a').format(a.at)}', action: tr('Cancel appointment'))) {
                      store.cancelAppointment(a.id);
                      if (context.mounted) toast(context, tr('Appointment cancelled'));
                    }
                  },
                ),
              ),
            ]),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                tr('Delete'),
                kind: ButtonKind.plain,
                size: ButtonSize.small,
                destructive: true,
                onTap: () async {
                  if (await confirm(context, title: tr('Delete this record?'), message: tr('It will be removed from your appointment history.'), action: tr('Delete'))) {
                    store.deleteAppointment(a.id);
                  }
                },
              ),
            ),
        ]),
      ),
    );
  }

  void _edit(BuildContext context) => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => AppointmentEditor(initial: a)));
}
