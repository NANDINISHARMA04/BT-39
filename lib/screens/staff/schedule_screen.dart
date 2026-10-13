import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/clinical_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import 'patients_screen.dart';

Color visitColor(BuildContext context, VisitStatus s) {
  final c = context.ios;
  return switch (s) { VisitStatus.upcoming => c.blue, VisitStatus.completed => c.green, VisitStatus.cancelled => c.gray, VisitStatus.noShow => c.orange };
}

/// The doctor's appointments, a day at a time.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _day = 1; // index into the strip; 1 is today

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final cs = context.watch<ClinicalStore>();
    final now = DateTime.now();
    final days = [for (var i = -1; i <= 6; i++) DateTime(now.year, now.month, now.day + i)];
    final sel = days[_day];
    final visits = cs.visitsOn(sel);
    final left = visits.where((v) => v.status == VisitStatus.upcoming).length;
    return LargeTitlePage(
      title: tr('Schedule'),
      subtitle: '${DateFormat('EEEE d MMMM').format(sel)} · ${tr('{n} appointments', {'n': visits.length})}${left > 0 ? ' · ${tr('{n} to see', {'n': left})}' : ''}',
      trailing: CupertinoButton(padding: EdgeInsets.zero, onPressed: () => showBookSheet(context, null, day: sel), child: const Icon(CupertinoIcons.add_circled_solid, size: 28)),
      children: [
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = days[i];
              final on = i == _day;
              final n = cs.visitsOn(d).where((v) => v.status != VisitStatus.cancelled).length;
              return GestureDetector(
                onTap: () => setState(() => _day = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  decoration: BoxDecoration(color: on ? c.blue : c.card, borderRadius: BorderRadius.circular(16)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(i == 1 ? tr('Today') : DateFormat('EEE').format(d), style: T.caption.copyWith(color: on ? Colors.white : c.label2, fontWeight: FontWeight.w600)),
                    Text('${d.day}', style: T.title3.copyWith(color: on ? Colors.white : c.label)),
                    Text(n == 0 ? '–' : '$n', style: T.caption.copyWith(color: on ? Colors.white70 : c.label3)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (visits.isEmpty)
          EmptyState(icon: CupertinoIcons.calendar, title: sel.weekday == DateTime.sunday ? tr('Sunday: clinic closed') : tr('No appointments'), message: tr('Tap + to book one.'))
        else
          GroupedList(children: [for (final v in visits) VisitRow(v: v)]),
        const SizedBox(height: 10),
        Text(tr('Visits patients book in PulseOS with you appear here too.'), textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
      ],
    );
  }
}

class VisitRow extends StatelessWidget {
  const VisitRow({super.key, required this.v});
  final Visit v;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final today = DateUtils.isSameDay(v.at, DateTime.now());
    return IOSRow(
      leading: SizedBox(
        width: 54,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(DateFormat('h:mm').format(v.at), style: T.headline.copyWith(color: c.label, fontFeatures: T.num)),
          Text(today ? DateFormat('a').format(v.at) : DateFormat('d MMM').format(v.at), style: T.caption.copyWith(color: c.label2)),
        ]),
      ),
      title: v.patientName,
      subtitle: '${v.video ? tr('Video') : tr('Clinic')} · ${trData(v.reason)}',
      trailing: Pill(tr(visitStatusLabel[v.status]!), color: visitColor(context, v.status)),
      onTap: () => showVisitSheet(context, v),
    );
  }
}

Future<void> showVisitSheet(BuildContext context, Visit v) {
  final cs = context.read<ClinicalStore>();
  return showSheet(context, (ctx) {
    final c = ctx.ios;
    Future<void> set(VisitStatus s, {String note = ''}) async {
      await cs.setVisitStatus(v, s, note: note);
      if (ctx.mounted) Navigator.pop(ctx);
      if (context.mounted) toast(context, tr(visitStatusLabel[s]!), s == VisitStatus.completed ? tr('Your consultation note is in {name}\'s notes.', {'name': v.patientName.split(' ').first}) : null);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Avatar(v.patientName, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.patientName, style: T.title3.copyWith(color: c.label)),
              Text('${DateFormat('EEE d MMM, h:mm a').format(v.at)} · ${v.video ? tr('Video consult') : tr('In clinic')}', style: T.footnote.copyWith(color: c.label2)),
            ]),
          ),
          Pill(tr(visitStatusLabel[v.status]!), color: visitColor(ctx, v.status)),
        ]),
        const SizedBox(height: 14),
        IOSCard(child: Text(trData(v.reason), style: T.body.copyWith(color: c.label))),
        if (v.bookedByPatient) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('Booked by the patient in the PulseOS app.'), style: T.caption.copyWith(color: c.label2))),
        const SizedBox(height: 14),
        CupertinoButton.tinted(
          onPressed: () {
            Navigator.pop(ctx);
            openPatient(context, v.patientId);
          },
          child: Text(tr('Open patient record')),
        ),
        if (v.status == VisitStatus.upcoming) ...[
          if (v.video) ...[
            const SizedBox(height: 8),
            CupertinoButton.tinted(
              onPressed: () => toast(ctx, tr('Video consult'), tr('In a full deployment this opens the video call with {name}.', {'name': v.patientName.split(' ').first})),
              child: Text(tr('Start video consult')),
            ),
          ],
          const SizedBox(height: 8),
          CupertinoButton.filled(
            onPressed: () async {
              final note = TextEditingController();
              final ok = await showCupertinoDialog<bool>(
                context: ctx,
                builder: (d) => CupertinoAlertDialog(
                  title: Text(tr('Consultation note')),
                  content: Padding(padding: const EdgeInsets.only(top: 10), child: CupertinoTextField(controller: note, placeholder: tr('Findings and plan'), maxLines: 4)),
                  actions: [
                    CupertinoDialogAction(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
                    CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(d, true), child: Text(tr('Complete'))),
                  ],
                ),
              );
              if (ok == true) await set(VisitStatus.completed, note: note.text);
              note.dispose();
            },
            child: Text(tr('Mark as seen')),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: CupertinoButton(onPressed: () => set(VisitStatus.noShow), child: Text(tr('No-show'), style: TextStyle(color: c.orange)))),
            Expanded(child: CupertinoButton(onPressed: () => set(VisitStatus.cancelled), child: Text(tr('Cancel visit'), style: TextStyle(color: c.red)))),
          ]),
        ],
      ]),
    );
  });
}

/// Books a visit. With no [patient], the doctor picks one first.
Future<void> showBookSheet(BuildContext context, CarePatient? patient, {DateTime? day}) {
  final cs = context.read<ClinicalStore>();
  final now = DateTime.now();
  // Bookable days and free times come from the service (the next 8 days, clinic closed on Sundays).
  final days = cs.bookingDays();
  if (days.isEmpty) {
    toast(context, tr('Book a visit'), tr('The schedule has not loaded yet. Try again in a moment.'));
    return Future.value();
  }
  var p = patient;
  var d = days.firstWhere((x) => day != null && DateUtils.isSameDay(x, day), orElse: () => days.first);
  DateTime? slot;
  var video = false;
  final reason = TextEditingController();
  return showSheet(
    context,
    (ctx) => StatefulBuilder(builder: (ctx, set) {
      final c = ctx.ios;
      final slots = cs.bookingSlots(d);
      Widget chip(String text, bool on, VoidCallback tap) => Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: GestureDetector(onTap: tap, child: Pill(text, color: on ? c.blue : null, solid: on)),
          );
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p == null ? tr('Book a visit') : tr('Book a visit with {name}', {'name': p!.name}), style: T.title3.copyWith(color: c.label)),
            if (patient == null) ...[
              const SizedBox(height: 12),
              Text(tr('PATIENT'), style: T.footnote.copyWith(color: c.label2)),
              const SizedBox(height: 6),
              Wrap(children: [for (final x in cs.patients) chip(x.name, p?.id == x.id, () => set(() => p = x))]),
            ],
            const SizedBox(height: 12),
            Text(tr('DAY'), style: T.footnote.copyWith(color: c.label2)),
            const SizedBox(height: 6),
            Wrap(children: [
              for (final x in days)
                chip(DateUtils.isSameDay(x, now) ? tr('Today') : DateFormat('EEE d').format(x), DateUtils.isSameDay(x, d), () => set(() {
                      d = x;
                      slot = null;
                    })),
            ]),
            const SizedBox(height: 6),
            Text(tr('TIME'), style: T.footnote.copyWith(color: c.label2)),
            const SizedBox(height: 6),
            if (slots.isEmpty) Text(tr('No free slots left on this day.'), style: T.footnote.copyWith(color: c.label2)) else Wrap(children: [for (final s in slots) chip(DateFormat('h:mm a').format(s), slot == s, () => set(() => slot = s))]),
            const SizedBox(height: 6),
            CupertinoSlidingSegmentedControl<bool>(groupValue: video, children: {false: Text(tr('In clinic')), true: Text(tr('Video'))}, onValueChanged: (v) => set(() => video = v ?? false)),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: reason,
              placeholder: tr('Reason, e.g. Follow-up after alert'),
              padding: const EdgeInsets.all(12),
              style: T.body.copyWith(color: c.label),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: p == null || slot == null
                    ? null
                    : () async {
                        await cs.book(p!, slot!, reason.text, video: video);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) toast(context, tr('Visit booked'), '${p!.name}, ${DateFormat('EEE d MMM, h:mm a').format(slot!)}');
                      },
                child: Text(tr('Book visit')),
              ),
            ),
          ]),
        ),
      );
    }),
  );
}
