import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../session.dart';
import '../theme.dart';
import 'verify_email_screen.dart' show CodeField, DevEmailHint;

/// Şifremi unuttum: e-posta adresine sıfırlama kodu gönderir.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return showError(context, 'Geçerli bir e-posta girin.');
    setState(() => _busy = true);
    try {
      await context.read<Session>().api.forgotPassword(email);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifremi unuttum')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Hesabınızın e-posta adresini girin. Size yeni şifre belirlemeniz için 6 haneli bir kod göndereceğiz.',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Kod gönder'),
          ),
        ],
      ),
    );
  }
}

/// Kodu ve yeni şifreyi alır; başarılı olursa kullanıcıyı giriş yapmış olarak ana ekrana götürür.
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const _cooldownSeconds = 60;

  final _code = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  bool _sending = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Kod az önce gönderildi; tekrar göndermek için 60 saniye beklenir.
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = _cooldownSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await context.read<Session>().api.forgotPassword(widget.email);
      if (!mounted) return;
      setState(_startCooldown);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni kod gönderildi.'), behavior: SnackBarBehavior.floating),
      );
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? _validate() {
    if (_code.text.trim().length != 6) return 'E-postadaki 6 haneli kodu girin.';
    if (_password.text.length < 8) return 'Şifre en az 8 karakter olmalı.';
    if (_password.text != _repeat.text) return 'Şifreler aynı değil.';
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) return showError(context, problem);
    setState(() => _busy = true);
    try {
      await context.read<Session>().resetPassword(widget.email, _code.text.trim(), _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifreniz değiştirildi.'), behavior: SnackBarBehavior.floating),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni şifre')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.ink),
              children: [
                TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(
                  text: ' ile kayıtlı bir hesap varsa 6 haneli bir kod gönderdik. '
                      'Kodu ve yeni şifrenizi girin. E-postayı göremiyorsanız spam klasörüne bakın.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          CodeField(controller: _code),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: _hide,
            decoration: InputDecoration(
              labelText: 'Yeni şifre (en az 8 karakter)',
              suffixIcon: IconButton(
                icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _repeat,
            obscureText: _hide,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Yeni şifre (tekrar)'),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Şifreyi değiştir'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _cooldown > 0 || _sending ? null : _resend,
            child: Text(_cooldown > 0 ? 'Kodu tekrar gönder ($_cooldown sn)' : 'Kodu tekrar gönder'),
          ),
          const DevEmailHint(),
        ],
      ),
    );
  }
}
