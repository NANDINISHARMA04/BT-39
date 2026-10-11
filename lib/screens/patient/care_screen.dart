import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
      title: 'Care',
      subtitle: 'Appointments and doctors',
      trailing: Semantics(
        label: 'Book appointment',
        button: true,
        child: Pressable(onTap: _findDoctor, child: Icon(CupertinoIcons.add_circled_solid, color: c.blue, size: 28)),
      ),
      children: [
        Pressable(
          onTap: _findDoctor,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(CupertinoIcons.search, size: 18, color: c.label2),
              const SizedBox(width: 8),
              Expanded(child: Text('Search doctors, specialities, hospitals', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.callout.copyWith(color: c.label2))),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 92,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final (s, icon, col) in [
              ('Cardiologist', CupertinoIcons.heart_fill, c.red),
              ('General Physician', CupertinoIcons.person_fill, c.blue),
              ('Pulmonologist', CupertinoIcons.wind, c.teal),
              ('Endocrinologist', CupertinoIcons.drop_fill, c.purple),
              ('Pediatrician', CupertinoIcons.smiley_fill, c.orange),
              ('Neurologist', CupertinoIcons.bolt_fill, c.indigo),
              ('Psychiatrist', CupertinoIcons.cloud_sun_fill, c.green),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Pressable(
                  onTap: () => _findDoctor(s),
                  child: SizedBox(
                    width: 84,
                    child: Column(children: [
                      Container(width: 56, height: 56, decoration: BoxDecoration(color: col.withValues(alpha: .15), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: col)),
                      const SizedBox(height: 6),
                      Text(s.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: c.label)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 4),
        CupertinoSlidingSegmentedControl<bool>(
          groupValue: _past,
          children: {false: Text('Upcoming (${store.upcoming.length})'), true: Text('Past (${store.past.length})')},
          onValueChanged: (v) => setState(() => _past = v ?? false),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          EmptyState(
            icon: CupertinoIcons.calendar,
            color: c.blue,
            title: _past ? 'No past appointments' : 'Nothing booked',
            message: _past ? 'Completed and cancelled visits show up here.' : 'Find a doctor and book a video or clinic visit.',
            action: _past ? null : 'Find a doctor',
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
      ApptStatus.upcoming => a.at.isBefore(DateTime.now().add(const Duration(hours: 24))) ? ('Soon', c.orange) : ('Confirmed', c.green),
      ApptStatus.completed => ('Completed', c.gray),
      ApptStatus.cancelled => ('Cancelled', c.red),
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
                Text('${d.specialty} · ${d.hospital}', style: T.footnote.copyWith(color: c.label2), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Pill(statusText, color: statusCol),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.card2, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(CupertinoIcons.calendar, size: 18, color: c.blue),
              const SizedBox(width: 8),
              Expanded(child: Text(DateFormat('EEE d MMM · h:mm a').format(a.at), style: T.sub.copyWith(color: c.label, fontWeight: FontWeight.w600))),
              Icon(a.mode == ApptMode.video ? CupertinoIcons.video_camera_solid : CupertinoIcons.building_2_fill, size: 18, color: c.blue),
              const SizedBox(width: 6),
              Text(a.mode == ApptMode.video ? 'Video' : 'Clinic', style: T.footnote.copyWith(color: c.label2)),
            ]),
          ),
          const SizedBox(height: 10),
          Text('For ${store.memberName(a.forMember)} · ${a.reason}', style: T.footnote.copyWith(color: c.label2)),
          if (a.fromAlert != null) Padding(padding: const EdgeInsets.only(top: 6), child: Pill('Booked from an AdaptAlert alert', icon: CupertinoIcons.sparkles, color: c.indigo)),
          if (upcoming) ...[
            const SizedBox(height: 12),
            Row(children: [
              if (a.mode == ApptMode.video)
                Expanded(
                  child: CupertinoButton.filled(
                    sizeStyle: CupertinoButtonSize.small,
                    onPressed: () => toast(context, 'Video call', 'The call opens 10 minutes before the start time. Demo only.'),
                    child: const Text('Join call'),
                  ),
                ),
              if (a.mode == ApptMode.video) const SizedBox(width: 8),
              Expanded(child: CupertinoButton.tinted(sizeStyle: CupertinoButtonSize.small, onPressed: () => _edit(context), child: const Text('Reschedule'))),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton.tinted(
                  sizeStyle: CupertinoButtonSize.small,
                  color: c.red,
                  onPressed: () async {
                    if (await confirm(context, title: 'Cancel appointment?', message: '${d.name}, ${DateFormat('EEE d MMM, h:mm a').format(a.at)}', action: 'Cancel appointment')) {
                      store.cancelAppointment(a.id);
                      if (context.mounted) toast(context, 'Appointment cancelled');
                    }
                  },
                  child: Text('Cancel', style: TextStyle(color: c.red)),
                ),
              ),
            ]),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  if (await confirm(context, title: 'Delete this record?', message: 'It will be removed from your appointment history.', action: 'Delete')) {
                    store.deleteAppointment(a.id);
                  }
                },
                child: Text('Delete', style: T.footnote.copyWith(color: c.red)),
              ),
            ),
        ]),
      ),
    );
  }

  void _edit(BuildContext context) => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => AppointmentEditor(initial: a)));
}
