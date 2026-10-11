import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../services/session.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/common.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.createAccount = false});
  final bool createAccount;
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late bool _create = widget.createAccount;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController(), _pw = TextEditingController();
  bool _busy = false;
  String? _error, _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final s = context.read<Session>();
    final err = _create ? await s.signUp(_name.text, _email.text, _pw.text) : await s.signIn(_email.text, _pw.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == 'CHECK_EMAIL') {
      setState(() => _info = 'Check your email to confirm your account, then sign in.');
    } else if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Type your email first, then tap “Forgot password?”.');
      return;
    }
    final err = await context.read<Session>().resetPassword(_email.text);
    if (!mounted) return;
    setState(() => err == null ? _info = 'If that email has an account, a reset link is on its way.' : _error = err);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: CupertinoNavigationBar(previousPageTitle: 'Welcome', middle: Text(_create ? 'Create account' : 'Sign in'), backgroundColor: c.material),
      body: Form(
        key: _form,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              CupertinoSlidingSegmentedControl<bool>(
                groupValue: _create,
                children: const {false: Text('Sign in'), true: Text('Create account')},
                onValueChanged: (v) => setState(() {
                  _create = v ?? false;
                  _error = _info = null;
                }),
              ),
              if (!AppConfig.supabaseEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: IOSCard(
                    color: c.orange.withValues(alpha: .12),
                    child: Row(children: [
                      Icon(CupertinoIcons.info_circle_fill, color: c.orange),
                      const SizedBox(width: 10),
                      Expanded(child: Text('This build has no Supabase key, so accounts are off. Go back and use Demo Mode, or build with --dart-define=SUPABASE_KEY=… (see README).', style: T.footnote.copyWith(color: c.label))),
                    ]),
                  ),
                ),
              AutofillGroup(
                child: FormGroup(header: _create ? 'Your details' : 'Account', children: [
                  if (_create) FormField2(label: 'Name', controller: _name, hint: 'Full name', autofill: const [AutofillHints.name], validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null),
                  FormField2(
                    label: 'Email',
                    controller: _email,
                    hint: 'you@example.com',
                    keyboard: TextInputType.emailAddress,
                    autofill: const [AutofillHints.email],
                    validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                  ),
                  FormField2(
                    label: 'Password',
                    controller: _pw,
                    hint: _create ? 'At least 8 characters' : 'Password',
                    obscure: true,
                    autofill: [_create ? AutofillHints.newPassword : AutofillHints.password],
                    validator: (v) => _create && (v ?? '').length < 8 ? 'Use at least 8 characters' : ((v ?? '').isEmpty ? 'Enter your password' : null),
                  ),
                ]),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(_error!, style: T.footnote.copyWith(color: c.red))),
              if (_info != null) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(_info!, style: T.footnote.copyWith(color: c.green))),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: _busy ? null : _submit,
                child: _busy ? const CupertinoActivityIndicator(color: Colors.white) : Text(_create ? 'Create account' : 'Sign in'),
              ),
              if (!_create) CupertinoButton(onPressed: _forgot, child: const Text('Forgot password?')),
              const SizedBox(height: 12),
              Text(
                _create
                    ? 'New accounts are patient accounts. Doctors and nurses sign in with the account their ward admin created.'
                    : 'Doctors and nurses on a BT39 ward go straight to the ward screens after signing in.',
                textAlign: TextAlign.center,
                style: T.footnote.copyWith(color: c.label2),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
