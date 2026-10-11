import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
      if (mounted) toast(context, 'Couldn\'t open files', 'Your device didn\'t allow the file picker.');
      return;
    }
    if (f == null || !mounted) return;
    final size = f.lengthSync() ?? await f.length() ?? 0;
    if (size > 10 << 20) {
      if (mounted) toast(context, 'File too large', 'Records can be up to 10 MB.');
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
      title: 'Records',
      previousTitle: 'Back',
      subtitle: '${store.records.length} files · ${fileSize(total)} · ${store.records.where((r) => r.shared).length} shared with your doctor',
      trailing: Semantics(label: 'Upload record', button: true, child: Pressable(onTap: _upload, child: Icon(CupertinoIcons.cloud_upload_fill, color: c.blue, size: 26))),
      children: [
        CupertinoSearchTextField(controller: _q, placeholder: 'Search records', onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.0,
          children: [
            for (final cat in recordCategories)
              Pressable(
                onTap: () => setState(() => _cat = _cat == cat ? null : cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _cat == cat ? categoryColor(context, cat) : c.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(categoryIcon(cat), color: _cat == cat ? Colors.white : categoryColor(context, cat), size: 22),
                    const Spacer(),
                    Text(cat, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: _cat == cat ? Colors.white : c.label, fontWeight: FontWeight.w600)),
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
            for (final (id, name) in [('all', 'Everyone'), ('self', 'Me'), ...store.family.map((m) => (m.id, m.name.split(' ').first))])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(name),
                  selected: _member == id,
                  onSelected: (_) => setState(() => _member = id),
                  showCheckmark: false,
                  selectedColor: c.blue,
                  labelStyle: TextStyle(color: _member == id ? Colors.white : c.label, fontWeight: FontWeight.w600),
                  backgroundColor: c.card,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          EmptyState(icon: CupertinoIcons.doc, color: c.blue, title: 'No records here', message: 'Upload lab reports, prescriptions or scans. PDF and photos up to 10 MB.', action: 'Upload a record', onAction: _upload)
        else
          GroupedList(children: [
            for (final r in list)
              IOSRow(
                icon: categoryIcon(r.category),
                iconColor: categoryColor(context, r.category),
                title: r.title,
                subtitle: '${DateFormat('d MMM y').format(r.date)} · ${store.memberName(r.forMember)} · ${fileSize(r.sizeBytes)}',
                trailing: r.shared ? Icon(CupertinoIcons.person_2_fill, size: 16, color: c.blue) : null,
                onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => RecordDetail(id: r.id))),
              ),
          ]),
        const SizedBox(height: 14),
        CupertinoButton.filled(onPressed: _upload, child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(CupertinoIcons.cloud_upload_fill, size: 18), SizedBox(width: 8), Text('Upload a record')])),
        const SizedBox(height: 8),
        Text('In this build, record details are kept on this device. Files are not uploaded to a server.', textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
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
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(
        previousPageTitle: 'Records',
        backgroundColor: c.material,
        middle: Text(r.category),
        trailing: CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => RecordEditor(record: r))), child: const Text('Edit')),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          height: 200,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [col.withValues(alpha: .85), col.withValues(alpha: .55)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(22)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(categoryIcon(r.category), size: 64, color: Colors.white),
            const SizedBox(height: 10),
            Text(r.fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            Text(fileSize(r.sizeBytes), style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),
        Text(r.title, style: T.title2.copyWith(color: c.label)),
        const SizedBox(height: 14),
        GroupedList(children: [
          IOSRow(icon: CupertinoIcons.calendar, iconColor: c.red, title: 'Date', trailing: Text(DateFormat('d MMM y').format(r.date), style: T.sub.copyWith(color: c.label2)), chevron: false),
          IOSRow(icon: CupertinoIcons.person_fill, iconColor: c.orange, title: 'Belongs to', trailing: Text(store.memberName(r.forMember), style: T.sub.copyWith(color: c.label2)), chevron: false),
          IOSRow(
            icon: CupertinoIcons.person_2_fill,
            iconColor: c.blue,
            title: 'Share with my doctor',
            subtitle: r.shared ? 'Your care team can read it' : 'Only you can see it',
            trailing: CupertinoSwitch(value: r.shared, onChanged: (v) => store.upsertRecord(r..shared = v)),
            chevron: false,
          ),
        ]),
        if (r.notes.isNotEmpty) ...[const SectionHeader('Notes'), IOSCard(child: Text(r.notes, style: T.body.copyWith(color: c.label, height: 1.4)))],
        const SizedBox(height: 24),
        CupertinoButton(
          onPressed: () async {
            if (await confirm(context, title: 'Delete record?', message: '“${r.title}” will be removed from your vault.', action: 'Delete')) {
              store.deleteRecord(r.id);
              if (context.mounted) {
                Navigator.pop(context);
                toast(context, 'Record deleted');
              }
            }
          },
          child: Text('Delete record', style: TextStyle(color: c.red)),
        ),
      ]),
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
    final c = context.ios;
    final store = context.read<PatientStore>();
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(
        backgroundColor: c.material,
        leading: CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        middle: Text(widget.isNew ? 'New record' : 'Edit record'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            if (_title.text.trim().isEmpty) return toast(context, 'Add a title');
            store.upsertRecord(widget.record
              ..title = _title.text.trim()
              ..notes = _notes.text.trim()
              ..category = _cat
              ..forMember = _for
              ..date = _date
              ..shared = _shared);
            Navigator.pop(context);
            toast(context, widget.isNew ? 'Record saved to your vault' : 'Record updated');
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        FormGroup(header: 'File', children: [IOSRow(icon: categoryIcon(_cat), iconColor: categoryColor(context, _cat), title: widget.record.fileName, subtitle: fileSize(widget.record.sizeBytes), chevron: false)]),
        FormGroup(header: 'Details', children: [
          FormField2(label: 'Title', controller: _title),
          IOSRow(
            title: 'Category',
            trailing: Text(_cat, style: T.sub.copyWith(color: c.label2)),
            onTap: () async {
              final v = await showCupertinoModalPopup<String>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  actions: [for (final x in recordCategories) CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, x), child: Text(x))],
                  cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ),
              );
              if (v != null) setState(() => _cat = v);
            },
          ),
          IOSRow(
            title: 'Date',
            trailing: Text(DateFormat('d MMM y').format(_date), style: T.sub.copyWith(color: c.label2)),
            onTap: () => showCupertinoModalPopup(
              context: context,
              builder: (ctx) => Container(
                height: 260,
                color: c.card,
                child: CupertinoDatePicker(mode: CupertinoDatePickerMode.date, initialDateTime: _date, maximumDate: DateTime.now().add(const Duration(days: 1)), onDateTimeChanged: (d) => setState(() => _date = d)),
              ),
            ),
          ),
          IOSRow(
            title: 'Belongs to',
            trailing: Text(store.memberName(_for), style: T.sub.copyWith(color: c.label2)),
            onTap: () async {
              final v = await showCupertinoModalPopup<String>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  actions: [for (final (id, n) in [('self', 'Me'), ...store.family.map((m) => (m.id, m.name))]) CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, id), child: Text(n))],
                  cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ),
              );
              if (v != null) setState(() => _for = v);
            },
          ),
          IOSRow(title: 'Share with my doctor', trailing: CupertinoSwitch(value: _shared, onChanged: (v) => setState(() => _shared = v)), chevron: false),
          FormField2(label: 'Notes', controller: _notes, hint: 'Key results, doctor\'s advice…', maxLines: 4),
        ]),
      ]),
    );
  }
}
