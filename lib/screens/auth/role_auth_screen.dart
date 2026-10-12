import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
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
      setState(() => _error = 'Please agree to share your vitals with your care team. AdaptAlert needs this to alert them.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = context.read<Session>();
    String? err;
    if (AppConfig.supabaseEnabled) {
      err = _signUp ? await s.signUp(_name.text, _email.text, _pw.text) : await s.signIn(_email.text, _pw.text);
      if (err == 'CHECK_EMAIL') err = 'Check your email to confirm your account, then log in.';
    } else if (_signUp) {
      final name = role == Role.doctor && !_name.text.trim().toLowerCase().startsWith('dr') ? 'Dr. ${_name.text.trim()}' : _name.text.trim();
      err = await s.localSignUp(
        role: role,
        name: name,
        email: _email.text,
        password: _pw.text,
        details: switch (role) {
          Role.patient => {'age': _age.text.trim(), 'sex': _sex, 'phone': _phone.text.trim()},
          Role.doctor => {'registration': _reg.text.trim(), 'specialty': _specialty, 'hospital': _hospital.text.trim()},
          Role.nurse => {'registration': _reg.text.trim(), 'ward': _ward, 'shift': _shift},
        },
      );
    } else {
      err = await s.localSignIn(_email.text, _pw.text, as: role);
    }
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
    final label = roleLabel[role]!;
    String? required(String? v, String what) => (v ?? '').trim().isEmpty ? 'Enter $what' : null;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(previousPageTitle: 'Welcome', middle: Text('$label ${_signUp ? 'sign up' : 'log in'}'), backgroundColor: c.material),
      body: Form(
        key: _form,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 40), children: [
              FadeIn(
                child: Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [col, Color.lerp(col, Colors.black, .2)!])),
                    child: Icon(roleIcon(role), color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_signUp ? 'Create your $label account' : 'Welcome back', style: T.title2.copyWith(color: c.label)),
                      Text(
                        switch (role) {
                          Role.patient => 'Your vitals, your alerts and your care in one place.',
                          Role.doctor => 'Review alerts, see your ward and teach AdaptAlert.',
                          Role.nurse => 'Ward alerts, acknowledgements and triage.',
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
                children: const {false: Text('Log in'), true: Text('Sign up')},
                onValueChanged: (v) => setState(() {
                  _signUp = v ?? false;
                  _error = null;
                }),
              ),
              AutofillGroup(
                child: Column(children: [
                  if (_signUp)
                    FormGroup(header: 'About you', children: [
                      FormField2(label: 'Full name', controller: _name, hint: role == Role.doctor ? 'e.g. Kavya Rao' : 'Your name', autofill: const [AutofillHints.name], validator: (v) => required(v, 'your name')),
                      if (role == Role.patient) ...[
                        FormField2(label: 'Age', controller: _age, hint: 'Years', keyboard: TextInputType.number, validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter your age' : null),
                        FormField2(label: 'Phone', controller: _phone, hint: '+91', keyboard: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber]),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: CupertinoSlidingSegmentedControl<String>(groupValue: _sex, children: const {'F': Text('Female'), 'M': Text('Male'), 'O': Text('Other')}, onValueChanged: (v) => setState(() => _sex = v ?? 'F')),
                        ),
                      ],
                      if (role != Role.patient)
                        FormField2(
                          label: role == Role.doctor ? 'Medical reg. no.' : 'Nursing reg. no.',
                          controller: _reg,
                          hint: role == Role.doctor ? 'e.g. DMC/R/12345' : 'e.g. DNC-45678',
                          validator: (v) => (v ?? '').trim().length < 4 ? 'Enter your registration number' : null,
                        ),
                      if (role == Role.doctor) ...[
                        _Picker(label: 'Speciality', value: _specialty, options: specialties, onChanged: (v) => setState(() => _specialty = v)),
                        FormField2(label: 'Hospital', controller: _hospital, hint: 'Where you practise'),
                      ],
                      if (role == Role.nurse) ...[
                        _Picker(label: 'Ward', value: _ward, options: const ['Ward A', 'Ward B', 'ICU', 'Cardiac care unit', 'Home care team'], onChanged: (v) => setState(() => _ward = v)),
                        _Picker(label: 'Shift', value: _shift, options: const ['Morning', 'Evening', 'Night'], onChanged: (v) => setState(() => _shift = v)),
                      ],
                    ]),
                  FormGroup(header: 'Account', children: [
                    FormField2(
                      label: 'Email',
                      controller: _email,
                      hint: 'you@example.com',
                      keyboard: TextInputType.emailAddress,
                      autofill: const [AutofillHints.email],
                      validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                    ),
                    Row(children: [
                      Expanded(
                        child: FormField2(
                          label: 'Password',
                          controller: _pw,
                          hint: _signUp ? 'At least 8 characters' : 'Password',
                          obscure: !_showPw,
                          autofill: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                          validator: (v) => _signUp && (v ?? '').length < 8 ? 'Use at least 8 characters' : ((v ?? '').isEmpty ? 'Enter your password' : null),
                        ),
                      ),
                      CupertinoButton(padding: const EdgeInsets.only(right: 12), onPressed: () => setState(() => _showPw = !_showPw), child: Icon(_showPw ? CupertinoIcons.eye_slash : CupertinoIcons.eye, size: 20, color: c.label2)),
                    ]),
                    if (_signUp)
                      FormField2(label: 'Confirm', controller: _pw2, hint: 'Type it again', obscure: !_showPw, validator: (v) => v != _pw.text ? 'Passwords don\'t match' : null),
                  ]),
                ]),
              ),
              if (_signUp)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _pw,
                  builder: (_, v, _) {
                    final s = _strength(v.text);
                    final (text, colr) = s <= 1 ? ('Weak', c.red) : s <= 3 ? ('Okay', c.orange) : ('Strong', c.green);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(children: [
                        for (var i = 0; i < 5; i++) Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 250), height: 4, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: i < s ? colr : c.fill2, borderRadius: BorderRadius.circular(2)))),
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
                    Expanded(child: Text('I agree to share my vitals and alerts with my care team.', style: T.footnote.copyWith(color: c.label))),
                  ]),
                ),
              if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(_error!, style: T.footnote.copyWith(color: c.red))),
              const SizedBox(height: 20),
              CupertinoButton(
                color: col,
                onPressed: _busy ? null : _submit,
                child: _busy ? const CupertinoActivityIndicator(color: Colors.white) : Text(_signUp ? 'Create $label account' : 'Log in as $label', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              if (!AppConfig.supabaseEnabled) ...[
                const SizedBox(height: 10),
                CupertinoButton(onPressed: _fillDemo, child: Text('Use the demo $label account')),
                Text('Demo: ${demoAccounts[role]!.$1} · ${demoAccounts[role]!.$2}', textAlign: TextAlign.center, style: T.caption.copyWith(color: c.label2)),
              ],
              const SizedBox(height: 16),
              Text(
                AppConfig.supabaseEnabled
                    ? (role == Role.patient ? 'Accounts use Supabase sign-in.' : 'Staff accounts also need a ward assignment from the BT39 admin.')
                    : 'Accounts are stored on this device. Passwords are never stored, only a salted SHA-256 hash.',
                textAlign: TextAlign.center,
                style: T.caption.copyWith(color: c.label3),
              ),
            ]),
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
    final c = context.ios;
    return IOSRow(
      title: label,
      trailing: Text(value, style: T.sub.copyWith(color: c.label2)),
      onTap: () async {
        final v = await showCupertinoModalPopup<String>(
          context: context,
          builder: (ctx) => CupertinoActionSheet(
            title: Text(label),
            actions: [for (final o in options) CupertinoActionSheetAction(isDefaultAction: o == value, onPressed: () => Navigator.pop(ctx, o), child: Text(o))],
            cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ),
        );
        if (v != null) onChanged(v);
      },
    );
  }
}
