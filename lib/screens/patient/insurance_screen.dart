import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/patient_models.dart';
import '../../services/patient_store.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';

final _inr = NumberFormat.decimalPattern('en_IN');
String rupees(int v) => '₹${_inr.format(v)}';

Color claimColor(BuildContext context, ClaimStatus s) {
  final c = context.ios;
  return switch (s) { ClaimStatus.submitted => c.blue, ClaimStatus.underReview => c.orange, ClaimStatus.approved => c.green, ClaimStatus.paid => c.teal, ClaimStatus.rejected => c.red };
}

class InsuranceScreen extends StatelessWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.watch<PatientStore>();
    return LargeTitlePage(
      title: 'Insurance',
      previousTitle: 'Back',
      subtitle: 'Policies, cover left and claims',
      trailing: Semantics(
        label: 'Add policy',
        button: true,
        child: Pressable(onTap: () => _editPolicy(context, null), child: Icon(CupertinoIcons.add_circled_solid, color: c.blue, size: 28)),
      ),
      children: [
        if (store.policies.isEmpty)
          EmptyState(icon: CupertinoIcons.shield, color: c.green, title: 'No policy yet', message: 'Add your health insurance to track cover and claims.', action: 'Add a policy', onAction: () => _editPolicy(context, null)),
        for (final (i, p) in store.policies.indexed) FadeIn(delay: i * 60, child: _PolicyCard(p: p)),
        if (store.policies.isNotEmpty) ...[
          SectionHeader('Claims', trailing: 'New claim', onTrailing: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const ClaimEditor()))),
          if (store.claims.isEmpty)
            IOSCard(child: Text('No claims yet.', style: T.sub.copyWith(color: c.label2)))
          else
            for (final (i, cl) in store.claims.indexed) FadeIn(delay: i * 50, child: _ClaimCard(cl: cl)),
        ],
        const SizedBox(height: 8),
        Text('Insurer updates are simulated in the demo. Tap “Simulate insurer update” on a claim to move it forward.', textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
      ],
    );
  }
}

void _editPolicy(BuildContext context, InsurancePolicy? p) => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => PolicyEditor(policy: p)));

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.p});
  final InsurancePolicy p;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.watch<PatientStore>();
    final used = store.usedOf(p);
    final left = (p.sumInsured - used).clamp(0, p.sumInsured);
    final daysLeft = p.validTill.difference(DateTime.now()).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        onTap: () => _editPolicy(context, p),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(colors: [c.green, c.teal], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: c.green.withValues(alpha: .3), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(CupertinoIcons.shield_lefthalf_fill, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(p.insurer, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17))),
              if (p.cashless) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)), child: const Text('Cashless', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
            ]),
            Text(p.plan, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 18),
            const Text('Cover left', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text(rupees(left), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.5, fontFeatures: T.num)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: p.sumInsured == 0 ? 0 : used / p.sumInsured),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: Colors.white24, color: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text('${rupees(used)} used of ${rupees(p.sumInsured)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Text(p.policyNo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 1, fontFeatures: T.num))),
              Text(daysLeft >= 0 ? 'Renews in $daysLeft days' : 'Expired', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Text('Covers ${p.members.map(store.memberName).join(', ')}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.cl});
  final Claim cl;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.read<PatientStore>();
    const steps = [ClaimStatus.submitted, ClaimStatus.underReview, ClaimStatus.approved, ClaimStatus.paid];
    final idx = cl.status == ClaimStatus.rejected ? 1 : steps.indexOf(cl.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IOSCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(cl.title, style: T.headline.copyWith(color: c.label))),
            Pill(claimStatusLabel[cl.status]!, color: claimColor(context, cl.status)),
          ]),
          Text('${cl.hospital} · ${store.memberName(cl.forMember)} · filed ${DateFormat('d MMM').format(cl.filed)}', style: T.footnote.copyWith(color: c.label2)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Amt('Claimed', rupees(cl.amount))),
            Expanded(child: _Amt('Approved', cl.approved == null ? '—' : rupees(cl.approved!))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            for (var i = 0; i < steps.length; i++) ...[
              Expanded(
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i <= idx ? (cl.status == ClaimStatus.rejected && i == idx ? c.red : c.green) : c.fill2),
                    child: i <= idx ? Icon(cl.status == ClaimStatus.rejected && i == idx ? CupertinoIcons.xmark : CupertinoIcons.checkmark_alt, size: 13, color: Colors.white) : null,
                  ),
                  const SizedBox(height: 4),
                  Text(cl.status == ClaimStatus.rejected && i == idx ? 'Rejected' : claimStatusLabel[steps[i]]!, textAlign: TextAlign.center, style: T.caption.copyWith(color: i <= idx ? c.label : c.label3, fontSize: 10.5)),
                ]),
              ),
            ],
          ]),
          if (cl.timeline.any((e) => e.note.isNotEmpty)) ...[
            const SizedBox(height: 10),
            for (final e in cl.timeline.where((e) => e.note.isNotEmpty)) Text('• ${DateFormat('d MMM').format(e.at)}: ${e.note}', style: T.caption.copyWith(color: c.label2)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            if (cl.status != ClaimStatus.paid && cl.status != ClaimStatus.rejected)
              Flexible(child: CupertinoButton(padding: EdgeInsets.zero, onPressed: () => store.advanceClaim(cl), child: Text('Simulate insurer update', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.footnote.copyWith(color: c.blue)))),
            const Spacer(),
            CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => ClaimEditor(claim: cl))), child: Text('Edit', style: T.footnote.copyWith(color: c.blue))),
            const SizedBox(width: 16),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                if (await confirm(context, title: 'Delete claim?', message: cl.title, action: 'Delete')) store.deleteClaim(cl.id);
              },
              child: Text('Delete', style: T.footnote.copyWith(color: c.red)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Amt extends StatelessWidget {
  const _Amt(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: T.caption.copyWith(color: context.ios.label2)),
        Text(value, style: T.title3.copyWith(color: context.ios.label, fontFeatures: T.num)),
      ]);
}

class PolicyEditor extends StatefulWidget {
  const PolicyEditor({super.key, this.policy});
  final InsurancePolicy? policy;
  @override
  State<PolicyEditor> createState() => _PolicyEditorState();
}

class _PolicyEditorState extends State<PolicyEditor> {
  late final p = widget.policy;
  late final _insurer = TextEditingController(text: p?.insurer ?? ''), _plan = TextEditingController(text: p?.plan ?? ''), _no = TextEditingController(text: p?.policyNo ?? '');
  late final _sum = TextEditingController(text: p == null ? '' : '${p!.sumInsured}'), _premium = TextEditingController(text: p == null || p!.premium == 0 ? '' : '${p!.premium}');
  late DateTime _valid = p?.validTill ?? DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day);
  late bool _cashless = p?.cashless ?? true;
  late final Set<String> _members = {...(p?.members ?? ['self'])};

  @override
  void dispose() {
    for (final x in [_insurer, _plan, _no, _sum, _premium]) {
      x.dispose();
    }
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
        middle: Text(p == null ? 'Add policy' : 'Edit policy'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            final sum = int.tryParse(_sum.text.replaceAll(RegExp(r'[^0-9]'), ''));
            if (_insurer.text.trim().isEmpty || _no.text.trim().isEmpty || sum == null) return toast(context, 'Fill in insurer, policy number and sum insured');
            store.upsertPolicy(InsurancePolicy(
              id: p?.id ?? store.newId(), insurer: _insurer.text.trim(), plan: _plan.text.trim(), policyNo: _no.text.trim(), sumInsured: sum, validTill: _valid,
              members: _members.toList(), cashless: _cashless, premium: int.tryParse(_premium.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
            ));
            Navigator.pop(context);
            toast(context, p == null ? 'Policy added' : 'Policy updated');
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        FormGroup(header: 'Policy', children: [
          FormField2(label: 'Insurer', controller: _insurer, hint: 'e.g. Star Health'),
          FormField2(label: 'Plan', controller: _plan, hint: 'Plan name'),
          FormField2(label: 'Policy no.', controller: _no, hint: 'From your policy card'),
          FormField2(label: 'Sum insured', controller: _sum, hint: '₹', keyboard: TextInputType.number),
          FormField2(label: 'Premium', controller: _premium, hint: '₹ per year', keyboard: TextInputType.number),
          IOSRow(
            title: 'Valid till',
            trailing: Text(DateFormat('d MMM y').format(_valid), style: T.sub.copyWith(color: c.label2)),
            onTap: () => showCupertinoModalPopup(
              context: context,
              builder: (_) => Container(height: 260, color: c.card, child: CupertinoDatePicker(mode: CupertinoDatePickerMode.date, initialDateTime: _valid, onDateTimeChanged: (d) => setState(() => _valid = d))),
            ),
          ),
          IOSRow(title: 'Cashless network', trailing: CupertinoSwitch(value: _cashless, onChanged: (v) => setState(() => _cashless = v)), chevron: false),
        ]),
        FormGroup(header: 'Who is covered', children: [
          for (final (id, name) in [('self', 'Me'), ...store.family.map((m) => (m.id, m.name))])
            IOSRow(
              title: name,
              trailing: _members.contains(id) ? Icon(CupertinoIcons.checkmark_alt, color: c.blue) : null,
              chevron: false,
              onTap: () => setState(() => _members.contains(id) ? _members.remove(id) : _members.add(id)),
            ),
        ]),
        if (p != null) ...[
          const SizedBox(height: 24),
          CupertinoButton(
            onPressed: () async {
              if (await confirm(context, title: 'Delete policy?', message: 'Its claims will be deleted too.', action: 'Delete')) {
                store.deletePolicy(p!.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text('Delete policy', style: TextStyle(color: c.red)),
          ),
        ],
      ]),
    );
  }
}

class ClaimEditor extends StatefulWidget {
  const ClaimEditor({super.key, this.claim});
  final Claim? claim;
  @override
  State<ClaimEditor> createState() => _ClaimEditorState();
}

class _ClaimEditorState extends State<ClaimEditor> {
  late final cl = widget.claim;
  late final _title = TextEditingController(text: cl?.title ?? ''), _hospital = TextEditingController(text: cl?.hospital ?? ''), _amount = TextEditingController(text: cl == null ? '' : '${cl!.amount}');
  late String? _policy = cl?.policyId;
  late String _for = cl?.forMember ?? 'self';
  late final Set<String> _recs = {...(cl?.recordIds ?? [])};

  @override
  void dispose() {
    _title.dispose();
    _hospital.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final store = context.read<PatientStore>();
    _policy ??= store.policies.firstOrNull?.id;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(
        backgroundColor: c.material,
        leading: CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        middle: Text(cl == null ? 'New claim' : 'Edit claim'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            final amt = int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
            if (_policy == null || _title.text.trim().isEmpty || amt == null) return toast(context, 'Add a title, amount and policy');
            final claim = cl ?? Claim(id: store.newId(), policyId: _policy!, title: '', hospital: '', amount: 0, forMember: _for, timeline: [ClaimEvent(ClaimStatus.submitted, DateTime.now())]);
            store.upsertClaim(claim
              ..policyId = _policy!
              ..title = _title.text.trim()
              ..hospital = _hospital.text.trim()
              ..amount = amt
              ..forMember = _for
              ..recordIds = _recs.toList());
            Navigator.pop(context);
            toast(context, cl == null ? 'Claim submitted' : 'Claim updated', cl == null ? 'You\'ll see updates from the insurer here.' : null);
          },
          child: Text(cl == null ? 'Submit' : 'Save', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        FormGroup(header: 'Claim', children: [
          FormField2(label: 'For', controller: _title, hint: 'e.g. Hospital stay, OPD visit'),
          FormField2(label: 'Hospital', controller: _hospital, hint: 'Hospital or clinic'),
          FormField2(label: 'Amount', controller: _amount, hint: '₹', keyboard: TextInputType.number),
          IOSRow(
            title: 'Policy',
            trailing: Text(store.policies.where((p) => p.id == _policy).map((p) => p.insurer).firstOrNull ?? 'None', style: T.sub.copyWith(color: c.label2)),
            onTap: () async {
              final v = await showCupertinoModalPopup<String>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  actions: [for (final p in store.policies) CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, p.id), child: Text('${p.insurer} · ${p.policyNo}'))],
                  cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ),
              );
              if (v != null) setState(() => _policy = v);
            },
          ),
          IOSRow(
            title: 'Patient',
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
        ]),
        FormGroup(header: 'Attach records', footer: 'Bills, discharge summary and reports from your vault.', children: [
          if (store.records.isEmpty) IOSRow(title: 'No records in your vault yet', chevron: false),
          for (final r in store.records)
            IOSRow(
              title: r.title,
              subtitle: r.category,
              trailing: _recs.contains(r.id) ? Icon(CupertinoIcons.checkmark_alt, color: c.blue) : null,
              chevron: false,
              onTap: () => setState(() => _recs.contains(r.id) ? _recs.remove(r.id) : _recs.add(r.id)),
            ),
        ]),
      ]),
    );
  }
}
