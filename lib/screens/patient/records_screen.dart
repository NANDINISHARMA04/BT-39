import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/patient_models.dart';
import '../../services/patient_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';

String fileSize(int b) => b >= 1 << 20 ? '${(b / (1 << 20)).toStringAsFixed(1)} MB' : '${(b / 1024).round()} KB';

IconData categoryIcon(String c) => switch (c) {
      'Lab report' => CupertinoIcons.lab_flask_solid,
      'Prescription' => CupertinoIcons.capsule_fill,
      'Imaging' => CupertinoIcons.photo_fill,
      'Discharge summary' => CupertinoIcons.doc_text_fill,
      'Vaccination' => CupertinoIcons.bandage_fill,
      _ => CupertinoIcons.folder_fill,
    };

Color categoryColor(BuildContext context, String cat) {
  final c = context.ios;
  return switch (cat) { 'Lab report' => c.purple, 'Prescription' => c.green, 'Imaging' => c.indigo, 'Discharge summary' => c.blue, 'Vaccination' => c.orange, _ => c.gray };
}

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String? _cat;
  String _member = 'all';
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final store = context.read<PatientStore>();
    PlatformFile? f;
    try {
      f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'doc', 'docx']);
    } catch (_) {
      if (mounted) toast(context, tr('Couldn\'t open files'), tr('Your device didn\'t allow the file picker.'));
      return;
    }
    if (f == null || !mounted) return;
    final size = f.lengthSync() ?? await f.length() ?? 0;
    if (size > 10 << 20) {
      if (mounted) toast(context, tr('File too large'), tr('Records can be up to 10 MB.'));
      return;
    }
    final name = f.name;
    final ext = (f.extension ?? '').toLowerCase();
    final rec = MedicalRecord(
      id: store.newId(),
      title: name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll(RegExp(r'[_-]+'), ' '),
      category: ['jpg', 'jpeg', 'png', 'heic'].contains(ext) ? 'Imaging' : 'Lab report',
      date: DateTime.now(),
      forMember: 'self',
      fileName: name,
      sizeBytes: size,
    );
    if (!mounted) return;
    await Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => RecordEditor(record: rec, isNew: true)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.watch<PatientStore>();
    final q = _q.text.trim().toLowerCase();
    final list = store.records.where((r) {
      if (_cat != null && r.category != _cat) return false;
      if (_member != 'all' && r.forMember != _member) return false;
      if (q.isNotEmpty && !'${r.title} ${r.notes} ${r.fileName}'.toLowerCase().contains(q)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = store.records.fold(0, (a, r) => a + r.sizeBytes);
    return LargeTitlePage(
      title: tr('Records'),
      previousTitle: tr('Back'),
      subtitle: tr('{n} files · {size} · {shared} shared with your doctor', {'n': store.records.length, 'size': fileSize(total), 'shared': store.records.where((r) => r.shared).length}),
      trailing: Semantics(label: tr('Upload record'), button: true, child: Pressable(onTap: _upload, child: Icon(CupertinoIcons.cloud_upload_fill, color: c.blue, size: 26))),
      children: [
        CupertinoSearchTextField(controller: _q, placeholder: tr('Search records'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          // Taller tiles when the text is larger (accessibility text size).
          childAspectRatio: 1 / MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
          children: [
            for (final cat in recordCategories)
              Pressable(
                scale: .95,
                onTap: () => setState(() => _cat = _cat == cat ? null : cat),
                child: AnimatedContainer(
                  duration: Motion.quick,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _cat == cat ? categoryColor(context, cat) : c.card,
                    borderRadius: BorderRadius.circular(R.md),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(categoryIcon(cat), color: _cat == cat ? Colors.white : categoryColor(context, cat), size: 22),
                    const Spacer(),
                    Text(trData(cat), maxLines: 2, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: _cat == cat ? Colors.white : c.label, fontWeight: FontWeight.w600)),
                    Text('${store.records.where((r) => r.category == cat).length}', style: T.caption.copyWith(color: _cat == cat ? Colors.white70 : c.label2)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (id, name) in [('all', tr('Everyone')), ('self', tr('Me')), ...store.family.map((m) => (m.id, m.name.split(' ').first))])
              Padding(padding: const EdgeInsets.only(right: 8), child: AppChip(name, selected: _member == id, onTap: () => setState(() => _member = id))),
          ]),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          EmptyState(icon: CupertinoIcons.doc, title: tr('No records here'), message: tr('Upload lab reports, prescriptions or scans. PDF and photos up to 10 MB.'), action: tr('Upload a record'), onAction: _upload)
        else
          GroupedList(children: [
            for (final r in list)
              IOSRow(
                icon: categoryIcon(r.category),
                iconColor: categoryColor(context, r.category),
                title: trData(r.title),
                subtitle: '${DateFormat('d MMM y').format(r.date)} · ${trData(store.memberName(r.forMember))} · ${fileSize(r.sizeBytes)}',
                trailing: r.shared ? Icon(CupertinoIcons.person_2_fill, size: 16, color: c.blue) : null,
                onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => RecordDetail(id: r.id))),
              ),
          ]),
        const SizedBox(height: 14),
        AppButton(tr('Upload a record'), icon: CupertinoIcons.cloud_upload_fill, expand: true, onTap: _upload),
        const SizedBox(height: 8),
        Text(tr('Record details are saved to your account. The files themselves are not uploaded.'), textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
      ],
    );
  }
}

class RecordDetail extends StatelessWidget {
  const RecordDetail({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.watch<PatientStore>();
    final r = store.records.where((x) => x.id == id).firstOrNull;
    if (r == null) return const SizedBox.shrink();
    final col = categoryColor(context, r.category);
    return PlainPage(
      title: trData(r.category),
      previousTitle: tr('Records'),
      trailing: BarButton(tr('Edit'), onTap: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => RecordEditor(record: r)))),
      children: [
        AccentCard(
          color: col,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
          child: Column(children: [
            Icon(categoryIcon(r.category), size: 56, color: Colors.white),
            const SizedBox(height: 10),
            Text(r.fileName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            Text(fileSize(r.sizeBytes), style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),
        Text(trData(r.title), style: T.title2.copyWith(color: c.label)),
        const SizedBox(height: 14),
        GroupedList(children: [
          IOSRow(icon: CupertinoIcons.calendar, iconColor: c.red, title: tr('Date'), value: DateFormat('d MMM y').format(r.date), chevron: false),
          IOSRow(icon: CupertinoIcons.person_fill, iconColor: c.orange, title: tr('Belongs to'), value: trData(store.memberName(r.forMember)), chevron: false),
          IOSRow(
            icon: CupertinoIcons.person_2_fill,
            iconColor: c.blue,
            title: tr('Share with my doctor'),
            subtitle: r.shared ? tr('Your care team can read it') : tr('Only you can see it'),
            trailing: CupertinoSwitch(value: r.shared, onChanged: (v) => store.upsertRecord(r..shared = v)),
            chevron: false,
          ),
        ]),
        if (r.notes.isNotEmpty) ...[SectionHeader(tr('Notes')), IOSCard(child: Text(trData(r.notes), style: T.body.copyWith(color: c.label, height: 1.4)))],
        const SizedBox(height: 24),
        AppButton(
          tr('Delete record'),
          kind: ButtonKind.plain,
          destructive: true,
          onTap: () async {
            if (await confirm(context, title: tr('Delete record?'), message: tr('“{title}” will be removed from your vault.', {'title': trData(r.title)}), action: tr('Delete'))) {
              store.deleteRecord(r.id);
              if (context.mounted) {
                Navigator.pop(context);
                toast(context, tr('Record deleted'));
              }
            }
          },
        ),
      ],
    );
  }
}

class RecordEditor extends StatefulWidget {
  const RecordEditor({super.key, required this.record, this.isNew = false});
  final MedicalRecord record;
  final bool isNew;
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  late final _title = TextEditingController(text: widget.record.title), _notes = TextEditingController(text: widget.record.notes);
  late String _cat = widget.record.category, _for = widget.record.forMember;
  late DateTime _date = widget.record.date;
  late bool _shared = widget.record.shared;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<PatientStore>();
    return PlainPage(
      title: widget.isNew ? tr('New record') : tr('Edit record'),
      leading: BarButton(tr('Cancel'), onTap: () => Navigator.pop(context)),
      trailing: BarButton(
        tr('Save'),
        bold: true,
        onTap: () {
          if (_title.text.trim().isEmpty) return toast(context, tr('Add a title'));
          store.upsertRecord(widget.record
            ..title = _title.text.trim()
            ..notes = _notes.text.trim()
            ..category = _cat
            ..forMember = _for
            ..date = _date
            ..shared = _shared);
          Navigator.pop(context);
          toast(context, widget.isNew ? tr('Record saved to your vault') : tr('Record updated'));
        },
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        FormGroup(header: tr('File'), children: [IOSRow(icon: categoryIcon(_cat), iconColor: categoryColor(context, _cat), title: widget.record.fileName, subtitle: fileSize(widget.record.sizeBytes), chevron: false)]),
        FormGroup(header: tr('Details'), children: [
          FormField2(label: tr('Title'), controller: _title),
          IOSRow(
            title: tr('Category'),
            value: trData(_cat),
            onTap: () async {
              final v = await showCupertinoModalPopup<String>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  actions: [for (final x in recordCategories) CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, x), child: Text(trData(x)))],
                  cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
                ),
              );
              if (v != null) setState(() => _cat = v);
            },
          ),
          IOSRow(
            title: tr('Date'),
            value: DateFormat('d MMM y').format(_date),
            onTap: () => showPicker(
              context,
              title: tr('Date'),
              picker: CupertinoDatePicker(mode: CupertinoDatePickerMode.date, initialDateTime: _date, maximumDate: DateTime.now().add(const Duration(days: 1)), onDateTimeChanged: (d) => setState(() => _date = d)),
            ),
          ),
          IOSRow(
            title: tr('Belongs to'),
            value: trData(store.memberName(_for)),
            onTap: () async {
              final v = await showCupertinoModalPopup<String>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  actions: [for (final (id, n) in [('self', tr('Me')), ...store.family.map((m) => (m.id, m.name))]) CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, id), child: Text(n))],
                  cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
                ),
              );
              if (v != null) setState(() => _for = v);
            },
          ),
          IOSRow(title: tr('Share with my doctor'), trailing: CupertinoSwitch(value: _shared, onChanged: (v) => setState(() => _shared = v)), chevron: false),
          FormField2(label: tr('Notes'), controller: _notes, hint: tr('Key results, doctor\'s advice…'), maxLines: 4),
        ]),
      ],
    );
  }
}
