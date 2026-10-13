import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/patient_store.dart';
import '../../services/session.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';

IconData roleIcon(Role r) => switch (r) { Role.patient => CupertinoIcons.heart_fill, Role.doctor => CupertinoIcons.person_crop_circle_fill_badge_checkmark, Role.nurse => CupertinoIcons.bandage_fill };

Color roleColor(BuildContext context, Role r) {
  final c = context.ios;
  return switch (r) { Role.patient => c.pink, Role.doctor => c.blue, Role.nurse => c.teal };
}

/// Log in or create an account for one role. Each role asks for what it needs:
/// patients their basics, doctors a medical registration number, nurses a ward.
class RoleAuthScreen extends StatefulWidget {
  const RoleAuthScreen({super.key, required this.role, this.signUp = false});
  final Role role;
  final bool signUp;
  @override
  State<RoleAuthScreen> createState() => _RoleAuthScreenState();
}

class _RoleAuthScreenState extends State<RoleAuthScreen> {
  late bool _signUp = widget.signUp;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController(), _pw = TextEditingController(), _pw2 = TextEditingController();
  final _phone = TextEditingController(), _age = TextEditingController(), _reg = TextEditingController(), _hospital = TextEditingController();
  String _sex = 'F', _specialty = 'Cardiologist', _ward = 'Ward A', _shift = 'Morning';
  bool _consent = false, _busy = false, _showPw = false;
  String? _error;

  Role get role => widget.role;

  @override
  void dispose() {
    for (final x in [_name, _email, _pw, _pw2, _phone, _age, _reg, _hospital]) {
      x.dispose();
    }
    super.dispose();
  }

  void _fillDemo() {
    final (mail, pw, _) = demoAccounts[role]!;
    setState(() {
      _signUp = false;
      _email.text = mail;
      _pw.text = pw;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_signUp && role == Role.patient && !_consent) {
      setState(() => _error = tr('Please agree to share your vitals with your care team. AdaptAlert needs this to alert them.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = context.read<Session>();
    // Accounts live on the BT39 service, so every role signs up and logs in the same way. The service adds "Dr." to a
    // doctor's name and keeps these details with the account.
    final err = _signUp
        ? await s.signUp(
            role: role,
            name: _name.text,
            email: _email.text,
            password: _pw.text,
            consent: _consent,
            details: switch (role) {
              Role.patient => {'age': _age.text.trim(), 'sex': _sex, 'phone': _phone.text.trim()},
              Role.doctor => {'registration': _reg.text.trim(), 'specialty': _specialty, 'hospital': _hospital.text.trim()},
              Role.nurse => {'registration': _reg.text.trim(), 'ward': _ward, 'shift': _shift},
            },
          )
        : await s.signIn(_email.text, _pw.text, as: role);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  int _strength(String p) {
    var s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final col = roleColor(context, role);
    final label = tr(roleLabel[role]!);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: plainBar(context, previousTitle: tr('Welcome'), middle: Text(_signUp ? tr('{role} sign up', {'role': label}) : tr('{role} log in', {'role': label}))),
      body: Form(
        key: _form,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              children: [
                FadeIn(
                  child: Row(children: [
                    IconSquare(roleIcon(role), col, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_signUp ? tr('Create your {role} account', {'role': label}) : tr('Welcome back'), style: T.title2.copyWith(color: c.label)),
                        Text(
                          switch (role) {
                            Role.patient => tr('Your vitals, your alerts and your care in one place.'),
                            Role.doctor => tr('Review alerts, see your ward and teach AdaptAlert.'),
                            Role.nurse => tr('Ward alerts, acknowledgements and triage.'),
                          },
                          style: T.footnote.copyWith(color: c.label2),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                CupertinoSlidingSegmentedControl<bool>(
                  groupValue: _signUp,
                  children: {false: Text(tr('Log in')), true: Text(tr('Sign up'))},
                  onValueChanged: (v) => setState(() {
                    _signUp = v ?? false;
                    _error = null;
                  }),
                ),
                AutofillGroup(
                  child: Column(children: [
                    if (_signUp)
                      FormGroup(header: tr('About you'), children: [
                        FormField2(label: tr('Full name'), controller: _name, hint: role == Role.doctor ? tr('e.g. Kavya Rao') : tr('Your name'), autofill: const [AutofillHints.name], validator: (v) => (v ?? '').trim().isEmpty ? tr('Enter your name') : null),
                        if (role == Role.patient) ...[
                          FormField2(label: tr('Age'), controller: _age, hint: tr('Years'), keyboard: TextInputType.number, validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? tr('Enter your age') : null),
                          FormField2(label: tr('Phone'), controller: _phone, hint: '+91', keyboard: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber]),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: CupertinoSlidingSegmentedControl<String>(groupValue: _sex, children: {'F': Text(tr('Female')), 'M': Text(tr('Male')), 'O': Text(tr('Other'))}, onValueChanged: (v) => setState(() => _sex = v ?? 'F')),
                          ),
                        ],
                        if (role != Role.patient)
                          FormField2(
                            label: role == Role.doctor ? tr('Medical reg. no.') : tr('Nursing reg. no.'),
                            controller: _reg,
                            hint: role == Role.doctor ? tr('e.g. DMC/R/12345') : tr('e.g. DNC-45678'),
                            validator: (v) => (v ?? '').trim().length < 4 ? tr('Enter your registration number') : null,
                          ),
                        if (role == Role.doctor) ...[
                          _Picker(label: tr('Speciality'), value: _specialty, options: specialties, onChanged: (v) => setState(() => _specialty = v)),
                          FormField2(label: tr('Hospital'), controller: _hospital, hint: tr('Where you practise')),
                        ],
                        if (role == Role.nurse) ...[
                          _Picker(label: tr('Ward'), value: _ward, options: const ['Ward A', 'Ward B', 'ICU', 'Cardiac care unit', 'Home care team'], onChanged: (v) => setState(() => _ward = v)),
                          _Picker(label: tr('Shift'), value: _shift, options: const ['Morning', 'Evening', 'Night'], onChanged: (v) => setState(() => _shift = v)),
                        ],
                      ]),
                    FormGroup(header: tr('Account'), children: [
                      FormField2(
                        label: tr('Email'),
                        controller: _email,
                        hint: 'you@example.com',
                        keyboard: TextInputType.emailAddress,
                        autofill: const [AutofillHints.email],
                        validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : tr('Enter a valid email'),
                      ),
                      Row(children: [
                        Expanded(
                          child: FormField2(
                            label: tr('Password'),
                            controller: _pw,
                            hint: _signUp ? tr('At least 8 characters') : tr('Password'),
                            obscure: !_showPw,
                            autofill: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                            validator: (v) => _signUp && (v ?? '').length < 8 ? tr('Use at least 8 characters') : ((v ?? '').isEmpty ? tr('Enter your password') : null),
                          ),
                        ),
                        CupertinoButton(padding: const EdgeInsets.only(right: 12), minimumSize: const Size(44, 44), onPressed: () => setState(() => _showPw = !_showPw), child: Icon(_showPw ? CupertinoIcons.eye_slash : CupertinoIcons.eye, size: 20, color: c.label2)),
                      ]),
                      if (_signUp)
                        FormField2(label: tr('Confirm'), controller: _pw2, hint: tr('Type it again'), obscure: !_showPw, validator: (v) => v != _pw.text ? tr('Passwords don\'t match') : null),
                    ]),
                  ]),
                ),
                if (_signUp)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _pw,
                    builder: (_, v, _) {
                      final s = _strength(v.text);
                      final (text, colr) = s <= 1 ? (tr('Weak'), c.red) : s <= 3 ? (tr('Okay'), c.orange) : (tr('Strong'), c.green);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Row(children: [
                          for (var i = 0; i < 5; i++) Expanded(child: AnimatedContainer(duration: Motion.quick, height: 4, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: i < s ? colr : c.fill2, borderRadius: BorderRadius.circular(2)))),
                          const SizedBox(width: 8),
                          Text(v.text.isEmpty ? '' : text, style: T.caption.copyWith(color: colr, fontWeight: FontWeight.w600)),
                        ]),
                      );
                    },
                  ),
                if (_signUp && role == Role.patient)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                    child: Row(children: [
                      CupertinoCheckbox(value: _consent, onChanged: (v) => setState(() => _consent = v ?? false)),
                      Expanded(child: Text(tr('I agree to share my vitals and alerts with my care team.'), style: T.footnote.copyWith(color: c.label))),
                    ]),
                  ),
                if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(_error!, style: T.footnote.copyWith(color: c.red))),
                const SizedBox(height: 20),
                AppButton(_signUp ? tr('Create {role} account', {'role': label}) : tr('Log in as {role}', {'role': label}), color: col, expand: true, busy: _busy, onTap: _submit),
                const SizedBox(height: 6),
                AppButton(tr('Use the demo {role} account', {'role': label}), kind: ButtonKind.plain, size: ButtonSize.medium, color: col, onTap: _fillDemo),
                Text('${tr('Demo')}: ${demoAccounts[role]!.$1} · ${demoAccounts[role]!.$2}', textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label2)),
                const SizedBox(height: 16),
                Text(
                  role == Role.patient ? tr('Accounts use Supabase sign-in.') : tr('Staff accounts open the ward at once. This is a demo: use made-up data only.'),
                  textAlign: TextAlign.center,
                  style: T.caption.copyWith(color: c.label3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({required this.label, required this.value, required this.options, required this.onChanged});
  final String label, value;
  final List<String> options;
  final void Function(String) onChanged;
  @override
  Widget build(BuildContext context) {
    return IOSRow(
      title: label,
      value: trData(value),
      onTap: () async {
        final v = await showCupertinoModalPopup<String>(
          context: context,
          builder: (ctx) => CupertinoActionSheet(
            title: Text(label),
            actions: [for (final o in options) CupertinoActionSheetAction(isDefaultAction: o == value, onPressed: () => Navigator.pop(ctx, o), child: Text(trData(o)))],
            cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          ),
        );
        if (v != null) onChanged(v);
      },
    );
  }
}
