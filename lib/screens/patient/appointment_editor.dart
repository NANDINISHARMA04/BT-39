import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/patient_models.dart';
import '../../services/patient_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';

/// Create, reschedule or delete an appointment.
class AppointmentEditor extends StatefulWidget {
  const AppointmentEditor({super.key, required this.initial, this.isNew = false});
  final Appointment initial;
  final bool isNew;
  @override
  State<AppointmentEditor> createState() => _AppointmentEditorState();
}

class _AppointmentEditorState extends State<AppointmentEditor> {
  late String _doctor = widget.initial.doctorId, _for = widget.initial.forMember;
  late ApptMode _mode = widget.initial.mode;
  late DateTime _day = DateUtils.dateOnly(widget.isNew ? DateTime.now() : widget.initial.at);
  DateTime? _slot;
  late final _reason = TextEditingController(text: widget.initial.reason), _notes = TextEditingController(text: widget.initial.notes);

  @override
  void initState() {
    super.initState();
    if (!widget.isNew) _slot = widget.initial.at;
    final d = doctorById(_doctor);
    if (!d.video && _mode == ApptMode.video) _mode = ApptMode.clinic;
    if (!d.clinic && _mode == ApptMode.clinic) _mode = ApptMode.video;
  }

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDoctor() async {
    final v = await showSheet<String>(context, (ctx) {
      final c = ctx.ios;
      return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        Text(tr('Choose a doctor'), style: T.title2.copyWith(color: c.label)),
        const SizedBox(height: 12),
        GroupedList(children: [
          for (final d in doctorCatalog)
            IOSRow(leading: Avatar(d.name, size: 34, colors: [c.teal, c.blue]), title: d.name, subtitle: '${trData(d.specialty)} · ₹${d.fee}', trailing: d.id == _doctor ? Icon(CupertinoIcons.checkmark_alt, color: c.blue) : null, chevron: false, onTap: () => Navigator.pop(ctx, d.id)),
        ]),
      ]);
    });
    if (v != null) {
      setState(() {
        _doctor = v;
        _slot = null;
        final d = doctorById(v);
        if (!d.video) _mode = ApptMode.clinic;
        if (!d.clinic) _mode = ApptMode.video;
      });
    }
  }

  void _save() {
    if (_slot == null) {
      toast(context, tr('Pick a time'), tr('Choose one of the free slots.'));
      return;
    }
    if (_reason.text.trim().isEmpty) {
      toast(context, tr('Add a reason'), tr('A few words help the doctor prepare.'));
      return;
    }
    final store = context.read<PatientStore>();
    final a = widget.initial
      ..doctorId = _doctor
      ..forMember = _for
      ..mode = _mode
      ..at = _slot!
      ..reason = _reason.text.trim()
      ..notes = _notes.text.trim()
      ..status = ApptStatus.upcoming;
    store.upsertAppointment(a);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    toast(context, widget.isNew ? tr('Appointment booked') : tr('Appointment updated'), '${doctorById(_doctor).name}, ${DateFormat('EEE d MMM, h:mm a').format(_slot!)}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.watch<PatientStore>();
    final d = doctorById(_doctor);
    // Free times come from the service (they leave out what anyone already booked with this doctor).
    final slots = store.slotsFor(d, _day, exceptAppt: widget.initial.id);
    final finding = store.slotsLoading(d, exceptAppt: widget.initial.id);
    final days = List.generate(14, (i) => DateUtils.dateOnly(DateTime.now()).add(Duration(days: i)));
    return PlainPage(
      title: widget.isNew ? tr('Book appointment') : tr('Reschedule'),
      leading: BarButton(tr('Cancel'), onTap: () => Navigator.pop(context)),
      trailing: BarButton(widget.isNew ? tr('Book') : tr('Save'), bold: true, onTap: _save),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
      children: [
        FormGroup(header: tr('Doctor'), children: [
          IOSRow(leading: Avatar(d.name, size: 40, colors: [c.teal, c.blue]), title: d.name, subtitle: '${trData(d.specialty)} · ₹${d.fee}', onTap: _pickDoctor),
        ]),
        FormGroup(header: tr('Who is it for'), children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (id, name) in [('self', tr('Me')), ...store.family.map((m) => (m.id, m.name.split(' ').first))]) AppChip(name, selected: _for == id, onTap: () => setState(() => _for = id)),
            ]),
          ),
        ]),
        FormGroup(header: tr('Visit type'), children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: CupertinoSlidingSegmentedControl<ApptMode>(
              groupValue: _mode,
              children: {
                ApptMode.clinic: Text(tr('In clinic'), style: TextStyle(color: d.clinic ? null : c.label3)),
                ApptMode.video: Text(tr('Video'), style: TextStyle(color: d.video ? null : c.label3)),
              },
              onValueChanged: (v) {
                if (v == ApptMode.video && !d.video || v == ApptMode.clinic && !d.clinic) {
                  toast(context, tr('Not offered'), v == ApptMode.video ? tr('{name} doesn\'t offer video visits.', {'name': d.name}) : tr('{name} doesn\'t offer clinic visits.', {'name': d.name}));
                  return;
                }
                setState(() => _mode = v!);
              },
            ),
          ),
        ]),
        FormGroup(header: tr('Day'), children: [
          SizedBox(
            height: 84,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(10), children: [
              for (final day in days)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pressable(
                    scale: .94,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _day = day;
                        _slot = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: Motion.quick,
                      width: 52,
                      decoration: BoxDecoration(color: day == _day ? c.blue : c.fill, borderRadius: BorderRadius.circular(R.sm)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(DateFormat('EEE').format(day), style: T.caption.copyWith(color: day == _day ? Colors.white : c.label2)),
                        Text('${day.day}', style: T.title3.copyWith(color: day == _day ? Colors.white : c.label, fontFeatures: T.num)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
        FormGroup(header: tr('Time'), footer: finding ? tr('Finding free times…') : slots.isEmpty ? tr('No free slots this day. Try another day.') : tr('{n} free slots', {'n': slots.length}), children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in slots)
                AppChip(
                  DateFormat('h:mm a').format(s),
                  selected: _slot == s,
                  square: true,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _slot = s);
                  },
                ),
              if (finding) const CupertinoActivityIndicator() else if (slots.isEmpty) Text('—', style: T.sub.copyWith(color: c.label3)),
            ]),
          ),
        ]),
        FormGroup(header: tr('Details'), children: [
          FormField2(label: tr('Reason'), controller: _reason, hint: tr('e.g. Follow-up after surgery')),
          FormField2(label: tr('Notes'), controller: _notes, hint: tr('Optional'), maxLines: 3),
        ]),
        if (!widget.isNew) ...[
          const SizedBox(height: 24),
          AppButton(
            tr('Delete appointment'),
            kind: ButtonKind.plain,
            destructive: true,
            onTap: () async {
              if (await confirm(context, title: tr('Delete appointment?'), message: tr('This removes it completely. To keep a record, cancel it instead.'), action: tr('Delete'))) {
                if (!context.mounted) return;
                context.read<PatientStore>().deleteAppointment(widget.initial.id);
                Navigator.pop(context);
                toast(context, tr('Appointment deleted'));
              }
            },
          ),
        ],
      ],
    );
  }
}
