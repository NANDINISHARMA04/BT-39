import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
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
      title: tr('Insurance'),
      previousTitle: tr('Back'),
      subtitle: tr('Policies, cover left and claims'),
      trailing: Semantics(
        label: tr('Add policy'),
        button: true,
        child: Pressable(onTap: () => _editPolicy(context, null), child: Icon(CupertinoIcons.add_circled_solid, color: c.blue, size: 28)),
      ),
      children: [
        if (store.policies.isEmpty)
          EmptyState(icon: CupertinoIcons.shield, title: tr('No policy yet'), message: tr('Add your health insurance to track cover and claims.'), action: tr('Add a policy'), onAction: () => _editPolicy(context, null)),
        for (final (i, p) in store.policies.indexed) FadeIn(delay: i * 60, child: _PolicyCard(p: p)),
        if (store.policies.isNotEmpty) ...[
          SectionHeader(tr('Claims'), trailing: tr('New claim'), onTrailing: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const ClaimEditor()))),
          if (store.claims.isEmpty)
            IOSCard(child: Text(tr('No claims yet.'), style: T.sub.copyWith(color: c.label2)))
          else
            for (final (i, cl) in store.claims.indexed) FadeIn(delay: i * 50, child: _ClaimCard(cl: cl)),
        ],
        const SizedBox(height: 8),
        Text(tr('Insurer updates are simulated in the demo. Tap “Simulate insurer update” on a claim to move it forward.'), textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label3)),
      ],
    );
  }
}

void _editPolicy(BuildContext context, InsurancePolicy? p) => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => PolicyEditor(policy: p)));

/// The policy as a card in a wallet: the one coloured card on this page.
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
      child: AccentCard(
        color: c.green,
        to: c.teal,
        onTap: () => _editPolicy(context, p),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(CupertinoIcons.shield_lefthalf_fill, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(p.insurer, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17))),
            if (p.cashless) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(R.pill)), child: Text(tr('Cashless'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
          Text(p.plan, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 18),
          Text(tr('Cover left'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(rupees(left), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.5, fontFeatures: T.num)),
          const SizedBox(height: 8),
          ProgressBar(value: p.sumInsured == 0 ? 0 : used / p.sumInsured, height: 8, color: Colors.white, track: Colors.white24),
          const SizedBox(height: 6),
          Text(tr('{used} used of {total}', {'used': rupees(used), 'total': rupees(p.sumInsured)}), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text(p.policyNo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 1, fontFeatures: T.num))),
            Text(daysLeft >= 0 ? tr('Renews in {n} days', {'n': daysLeft}) : tr('Expired'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          Text(tr('Covers {names}', {'names': p.members.map((id) => trData(store.memberName(id))).join(', ')}), style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
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
            Expanded(child: Text(trData(cl.title), style: T.headline.copyWith(color: c.label))),
            Pill(tr(claimStatusLabel[cl.status]!), color: claimColor(context, cl.status)),
          ]),
          Text('${cl.hospital} · ${trData(store.memberName(cl.forMember))} · ${tr('filed {date}', {'date': DateFormat('d MMM').format(cl.filed)})}', style: T.footnote.copyWith(color: c.label2)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Amt(tr('Claimed'), rupees(cl.amount))),
            Expanded(child: _Amt(tr('Approved'), cl.approved == null ? '—' : rupees(cl.approved!))),
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
                  Text(cl.status == ClaimStatus.rejected && i == idx ? tr('Rejected') : tr(claimStatusLabel[steps[i]]!), textAlign: TextAlign.center, style: T.caption.copyWith(color: i <= idx ? c.label : c.label3, fontSize: 10.5)),
                ]),
              ),
            ],
          ]),
          if (cl.timeline.any((e) => e.note.isNotEmpty)) ...[
            const SizedBox(height: 10),
            for (final e in cl.timeline.where((e) => e.note.isNotEmpty)) Text('• ${DateFormat('d MMM').format(e.at)}: ${trData(e.note)}', style: T.caption.copyWith(color: c.label2)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            if (cl.status != ClaimStatus.paid && cl.status != ClaimStatus.rejected)
              Flexible(child: AppButton(tr('Simulate insurer update'), kind: ButtonKind.plain, size: ButtonSize.small, onTap: () => store.advanceClaim(cl))),
            const Spacer(),
            AppButton(tr('Edit'), kind: ButtonKind.plain, size: ButtonSize.small, onTap: () => Navigator.of(context).push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => ClaimEditor(claim: cl)))),
            AppButton(
              tr('Delete'),
              kind: ButtonKind.plain,
              size: ButtonSize.small,
              destructive: true,
              onTap: () async {
                if (await confirm(context, title: tr('Delete claim?'), message: trData(cl.title), action: tr('Delete'))) store.deleteClaim(cl.id);
              },
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
    return PlainPage(
      title: p == null ? tr('Add policy') : tr('Edit policy'),
      leading: BarButton(tr('Cancel'), onTap: () => Navigator.pop(context)),
      trailing: BarButton(
        tr('Save'),
        bold: true,
        onTap: () {
          final sum = int.tryParse(_sum.text.replaceAll(RegExp(r'[^0-9]'), ''));
          if (_insurer.text.trim().isEmpty || _no.text.trim().isEmpty || sum == null) return toast(context, tr('Fill in insurer, policy number and sum insured'));
          store.upsertPolicy(InsurancePolicy(
            id: p?.id ?? store.newId(), insurer: _insurer.text.trim(), plan: _plan.text.trim(), policyNo: _no.text.trim(), sumInsured: sum, validTill: _valid,
            members: _members.toList(), cashless: _cashless, premium: int.tryParse(_premium.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
          ));
          Navigator.pop(context);
          toast(context, p == null ? tr('Policy added') : tr('Policy updated'));
        },
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        FormGroup(header: tr('Policy'), children: [
          FormField2(label: tr('Insurer'), controller: _insurer, hint: tr('e.g. Star Health')),
          FormField2(label: tr('Plan'), controller: _plan, hint: tr('Plan name')),
          FormField2(label: tr('Policy no.'), controller: _no, hint: tr('From your policy card')),
          FormField2(label: tr('Sum insured'), controller: _sum, hint: '₹', keyboard: TextInputType.number),
          FormField2(label: tr('Premium'), controller: _premium, hint: tr('₹ per year'), keyboard: TextInputType.number),
          IOSRow(
            title: tr('Valid till'),
            value: DateFormat('d MMM y').format(_valid),
            onTap: () => showPicker(
              context,
              title: tr('Valid till'),
              picker: CupertinoDatePicker(mode: CupertinoDatePickerMode.date, initialDateTime: _valid, onDateTimeChanged: (d) => setState(() => _valid = d)),
            ),
          ),
          IOSRow(title: tr('Cashless network'), trailing: CupertinoSwitch(value: _cashless, onChanged: (v) => setState(() => _cashless = v)), chevron: false),
        ]),
        FormGroup(header: tr('Who is covered'), children: [
          for (final (id, name) in [('self', tr('Me')), ...store.family.map((m) => (m.id, m.name))])
            IOSRow(
              title: name,
              trailing: _members.contains(id) ? Icon(CupertinoIcons.checkmark_alt, color: c.blue) : null,
              chevron: false,
              onTap: () => setState(() => _members.contains(id) ? _members.remove(id) : _members.add(id)),
            ),
        ]),
        if (p != null) ...[
          const SizedBox(height: 24),
          AppButton(
            tr('Delete policy'),
            kind: ButtonKind.plain,
            destructive: true,
            onTap: () async {
              if (await confirm(context, title: tr('Delete policy?'), message: tr('Its claims will be deleted too.'), action: tr('Delete'))) {
                store.deletePolicy(p!.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ],
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
    return PlainPage(
      title: cl == null ? tr('New claim') : tr('Edit claim'),
      leading: BarButton(tr('Cancel'), onTap: () => Navigator.pop(context)),
      trailing: BarButton(
        cl == null ? tr('Submit') : tr('Save'),
        bold: true,
        onTap: () {
          final amt = int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
          if (_policy == null || _title.text.trim().isEmpty || amt == null) return toast(context, tr('Add a title, amount and policy'));
          final claim = cl ?? Claim(id: store.newId(), policyId: _policy!, title: '', hospital: '', amount: 0, forMember: _for, timeline: [ClaimEvent(ClaimStatus.submitted, DateTime.now())]);
          store.upsertClaim(claim
            ..policyId = _policy!
            ..title = _title.text.trim()
            ..hospital = _hospital.text.trim()
            ..amount = amt
            ..forMember = _for
            ..recordIds = _recs.toList());
          Navigator.pop(context);
          toast(context, cl == null ? tr('Claim submitted') : tr('Claim updated'), cl == null ? tr('You\'ll see updates from the insurer here.') : null);
        },
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        FormGroup(header: tr('Claim'), children: [
          FormField2(label: tr('For'), controller: _title, hint: tr('e.g. Hospital stay, OPD visit')),
          FormField2(label: tr('Hospital'), controller: _hospital, hint: tr('Hospital or clinic')),
          FormField2(label: tr('Amount'), controller: _amount, hint: '₹', keyboard: TextInputType.number),
          IOSRow(
            title: tr('Policy'),
            value: store.policies.where((p) => p.id == _policy).map((p) => p.insurer).firstOrNull ?? tr('None'),
            onTap: () async {
              final v = await showCupertinoModalPopup<String>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  actions: [for (final p in store.policies) CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, p.id), child: Text('${p.insurer} · ${p.policyNo}'))],
                  cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
                ),
              );
              if (v != null) setState(() => _policy = v);
            },
          ),
          IOSRow(
            title: tr('Patient'),
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
        ]),
        FormGroup(header: tr('Attach records'), footer: tr('Bills, discharge summary and reports from your vault.'), children: [
          if (store.records.isEmpty) IOSRow(title: tr('No records in your vault yet'), chevron: false),
          for (final r in store.records)
            IOSRow(
              title: trData(r.title),
              subtitle: trData(r.category),
              trailing: _recs.contains(r.id) ? Icon(CupertinoIcons.checkmark_alt, color: c.blue) : null,
              chevron: false,
              onTap: () => setState(() => _recs.contains(r.id) ? _recs.remove(r.id) : _recs.add(r.id)),
            ),
        ]),
      ],
    );
  }
}
