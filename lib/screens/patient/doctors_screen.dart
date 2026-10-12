import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/patient_models.dart';
import '../../services/patient_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';
import 'appointment_editor.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key, this.specialty});
  final String? specialty;
  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final _q = TextEditingController();
  late String? _spec = widget.specialty;
  bool _video = false, _today = false, _top = false;
  String? _lang;
  String _sort = 'Recommended';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<Doctor> get _results {
    final q = _q.text.trim().toLowerCase();
    final out = doctorCatalog.where((d) {
      if (_spec != null && d.specialty != _spec) return false;
      if (_video && !d.video) return false;
      if (_today && d.nextFreeDays > 0) return false;
      if (_top && d.rating < 4.8) return false;
      if (_lang != null && !d.languages.contains(_lang)) return false;
      if (q.isNotEmpty && !'${d.name} ${d.specialty} ${d.hospital} ${d.city}'.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    switch (_sort) {
      case 'Rating':
        out.sort((a, b) => b.rating.compareTo(a.rating));
      case 'Fee: low to high':
        out.sort((a, b) => a.fee.compareTo(b.fee));
      case 'Nearest':
        out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      default:
        out.sort((a, b) => (b.rating * 10 - b.nextFreeDays - b.distanceKm / 10).compareTo(a.rating * 10 - a.nextFreeDays - a.distanceKm / 10));
    }
    return out;
  }

  Future<void> _pickSort() async {
    final v = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(tr('Sort doctors')),
        actions: [for (final s in ['Recommended', 'Rating', 'Fee: low to high', 'Nearest']) CupertinoActionSheetAction(isDefaultAction: s == _sort, onPressed: () => Navigator.pop(ctx, s), child: Text(tr(s)))],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
      ),
    );
    if (v != null) setState(() => _sort = v);
  }

  Future<void> _pickLang() async {
    final langs = {for (final d in doctorCatalog) ...d.languages}.toList()..sort();
    final v = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(tr('Doctor speaks')),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, ''), child: Text(tr('Any language'))),
          for (final l in langs) CupertinoActionSheetAction(isDefaultAction: l == _lang, onPressed: () => Navigator.pop(ctx, l), child: Text(trData(l))),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
      ),
    );
    if (v != null) setState(() => _lang = v.isEmpty ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final res = _results;
    Widget chip(String label, bool on, VoidCallback tap, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Pressable(
            onTap: tap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: on ? c.blue : c.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: on ? c.blue : c.sep)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 14, color: on ? Colors.white : c.label), const SizedBox(width: 4)],
                Text(label, style: T.footnote.copyWith(color: on ? Colors.white : c.label, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
    return LargeTitlePage(
      title: tr('Find a doctor'),
      previousTitle: tr('Care'),
      children: [
        CupertinoSearchTextField(controller: _q, placeholder: tr('Name, speciality, hospital or city'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip(tr(_sort), false, _pickSort, icon: CupertinoIcons.arrow_up_arrow_down),
            chip(tr('Video'), _video, () => setState(() => _video = !_video), icon: CupertinoIcons.video_camera_solid),
            chip(tr('Available today'), _today, () => setState(() => _today = !_today)),
            chip(tr('4.8★ and up'), _top, () => setState(() => _top = !_top)),
            chip(_lang == null ? tr('Language') : trData(_lang!), _lang != null, _pickLang, icon: CupertinoIcons.globe),
          ]),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip(tr('All specialities'), _spec == null, () => setState(() => _spec = null)),
            for (final s in specialties) chip(trData(s), _spec == s, () => setState(() => _spec = _spec == s ? null : s)),
          ]),
        ),
        const SizedBox(height: 14),
        Text(res.length == 1 ? tr('{n} doctor', {'n': res.length}) : tr('{n} doctors', {'n': res.length}), style: T.footnote.copyWith(color: c.label2)),
        const SizedBox(height: 8),
        if (res.isEmpty)
          EmptyState(
            icon: CupertinoIcons.search,
            color: c.gray,
            title: tr('No doctors match'),
            message: tr('Try removing a filter.'),
            action: tr('Clear filters'),
            onAction: () => setState(() {
              _spec = _lang = null;
              _video = _today = _top = false;
              _q.clear();
            }),
          ),
        for (final (i, d) in res.indexed) FadeIn(delay: i * 35, child: DoctorCard(d: d)),
        const SizedBox(height: 8),
        Text(tr('Example doctors for the demo. Names and clinics are fictional.'), textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
      ],
    );
  }
}

String nextFreeText(Doctor d) => d.nextFreeDays == 0 ? tr('Available today') : d.nextFreeDays == 1 ? tr('Next free tomorrow') : tr('Next free in {n} days', {'n': d.nextFreeDays});

class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.d});
  final Doctor d;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IOSCard(
        onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => DoctorDetail(d: d))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Hero(tag: 'doc-${d.id}', child: Avatar(d.name, size: 56, colors: [c.teal, c.blue])),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: T.headline.copyWith(color: c.label)),
              Text('${trData(d.specialty)} · ${tr('{n} yrs', {'n': d.years})}', style: T.footnote.copyWith(color: c.label2)),
              Text('${d.hospital}, ${d.city} · ${d.distanceKm.toStringAsFixed(1)} km', style: T.footnote.copyWith(color: c.label2), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill('★ ${d.rating} (${d.reviews})', color: c.orange),
                Pill('₹${d.fee}', color: c.green),
                if (d.video) Pill(tr('Video'), icon: CupertinoIcons.video_camera_solid, color: c.blue),
                Pill(nextFreeText(d), color: d.nextFreeDays == 0 ? c.teal : null),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class DoctorDetail extends StatelessWidget {
  const DoctorDetail({super.key, required this.d});
  final Doctor d;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.read<PatientStore>();
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(previousPageTitle: tr('Doctors'), backgroundColor: c.material, middle: Text(d.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 120), children: [
        Center(child: Hero(tag: 'doc-${d.id}', child: Avatar(d.name, size: 96, colors: [c.teal, c.blue]))),
        const SizedBox(height: 12),
        Text(d.name, textAlign: TextAlign.center, style: T.title1.copyWith(color: c.label)),
        Text('${trData(d.specialty)} · ${d.hospital}, ${d.city}', textAlign: TextAlign.center, style: T.sub.copyWith(color: c.label2)),
        const SizedBox(height: 18),
        Row(children: [
          for (final (v, l) in [('${d.rating}★', tr('{n} reviews', {'n': d.reviews})), ('${d.years}', tr('years')), ('₹${d.fee}', tr('per visit')), ('${d.distanceKm.toStringAsFixed(1)} km', tr('away'))])
            Expanded(
              child: Column(children: [
                Text(v, style: T.title3.copyWith(color: c.label)),
                Text(l, style: T.caption.copyWith(color: c.label2)),
              ]),
            ),
        ]),
        SectionHeader(tr('About')),
        IOSCard(child: Text(trData(d.about), style: T.body.copyWith(color: c.label, height: 1.4))),
        SectionHeader(tr('Details')),
        GroupedList(children: [
          IOSRow(icon: CupertinoIcons.globe, iconColor: c.blue, title: tr('Speaks'), subtitle: d.languages.map(trData).join(', '), chevron: false),
          IOSRow(icon: CupertinoIcons.video_camera_solid, iconColor: c.teal, title: tr('Consultation'), subtitle: [if (d.clinic) tr('In clinic'), if (d.video) tr('Video')].join(' · '), chevron: false),
          IOSRow(icon: CupertinoIcons.clock_fill, iconColor: c.orange, title: nextFreeText(d), subtitle: tr('Mon–Sat, 9 AM to 6 PM'), chevron: false),
        ]),
        const SizedBox(height: 24),
        CupertinoButton.filled(
          onPressed: () => Navigator.of(context).push(CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (_) => AppointmentEditor(initial: Appointment(id: store.newId(), doctorId: d.id, forMember: 'self', at: DateTime.now(), mode: d.clinic ? ApptMode.clinic : ApptMode.video, reason: ''), isNew: true),
          )),
          child: Text(tr('Book appointment')),
        ),
      ]),
    );
  }
}
