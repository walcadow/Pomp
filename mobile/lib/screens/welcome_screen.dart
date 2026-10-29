import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import 'password_screens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const Icon(Icons.local_fire_department_rounded, size: 84, color: Colors.white),
                const SizedBox(height: 8),
                const Text('pomp',
                    style: TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2)),
                const SizedBox(height: 8),
                Text('Yakınındaki insanlarla tanış.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 17)),
                const Spacer(flex: 3),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Hesap oluştur'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('Giriş yap'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await context.read<Session>().login(_email.text.trim(), _password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş yap')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: _hide,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Şifre',
              suffixIcon: IconButton(
                icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim())),
              ),
              child: const Text('Şifremi unuttum'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Giriş yap'),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  DateTime? _birthdate;
  String? _gender;
  final Set<String> _interestedIn = {};
  bool _accepted = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Doğum tarihiniz',
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  String? _validate() {
    if (_name.text.trim().length < 2) return 'Adınızı girin.';
    if (!_email.text.contains('@')) return 'Geçerli bir e-posta girin.';
    if (_password.text.length < 8) return 'Şifre en az 8 karakter olmalı.';
    if (_birthdate == null) return 'Doğum tarihinizi seçin.';
    if (_gender == null) return 'Cinsiyetinizi seçin.';
    if (_interestedIn.isEmpty) return 'Kimlerle tanışmak istediğinizi seçin.';
    if (!_accepted) return 'Devam etmek için koşulları onaylayın.';
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) return showError(context, problem);
    setState(() => _busy = true);
    try {
      final b = _birthdate!;
      await context.read<Session>().register({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'birthdate': '${b.year.toString().padLeft(4, '0')}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}',
        'gender': _gender,
        'interestedIn': _interestedIn.toList(),
        'acceptedTerms': true,
      });
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      );

  @override
  Widget build(BuildContext context) {
    final b = _birthdate;
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap oluştur')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Adınız')),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Şifre (en az 8 karakter)'),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickBirthdate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Doğum tarihi', suffixIcon: Icon(Icons.cake_outlined)),
              child: Text(b == null ? 'Seçin' : '${b.day}.${b.month}.${b.year}'),
            ),
          ),
          _label('Cinsiyetiniz'),
          Wrap(
            spacing: 8,
            children: [
              for (final g in genderLabels.entries)
                ChoiceChip(
                  label: Text(g.value),
                  selected: _gender == g.key,
                  onSelected: (_) => setState(() => _gender = g.key),
                ),
            ],
          ),
          _label('Kimlerle tanışmak istiyorsunuz?'),
          Wrap(
            spacing: 8,
            children: [
              for (final g in genderLabels.entries)
                FilterChip(
                  label: Text(g.value),
                  selected: _interestedIn.contains(g.key),
                  onSelected: (on) => setState(() => on ? _interestedIn.add(g.key) : _interestedIn.remove(g.key)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: _accepted, onChanged: (v) => setState(() => _accepted = v ?? false)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(color: AppColors.muted, height: 1.4),
                      children: [
                        const TextSpan(text: '18 yaşından büyük olduğumu onaylıyorum; '),
                        _link('Kullanım Koşulları', AppConfig.termsUrl),
                        const TextSpan(text: "'nı ve "),
                        _link('KVKK Aydınlatma Metni', AppConfig.privacyUrl),
                        const TextSpan(text: "'ni okudum, konum ve profil verilerimin işlenmesine açık rıza veriyorum."),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Kayıt ol'),
          ),
        ],
      ),
    );
  }

  TextSpan _link(String text, String url) => TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
        recognizer: TapGestureRecognizer()
          ..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      );
}
