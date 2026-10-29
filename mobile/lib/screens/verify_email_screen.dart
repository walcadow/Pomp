import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../config.dart';
import '../session.dart';
import '../theme.dart';

/// E-posta doğrulama ekranı: 6 haneli kodu girip adresi doğrular.
class VerifyEmailScreen extends StatefulWidget {
  /// true ise ekran açılınca yeni bir kod gönderilir
  /// (son 60 saniyede kod gönderildiyse sunucu yenisini göndermez, sorun değil).
  final bool sendOnOpen;
  const VerifyEmailScreen({super.key, this.sendOnOpen = true});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _cooldownSeconds = 60;

  final _code = TextEditingController();
  bool _busy = false;
  bool _sending = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.sendOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(silentIfThrottled: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    // _send içindeki await'ten sonra çağrılır; ekran bu arada kapatılmış olabilir.
    if (!mounted) return;
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _send({bool silentIfThrottled = false}) async {
    final session = context.read<Session>();
    setState(() => _sending = true);
    try {
      await session.api.sendVerification();
      _startCooldown();
      if (mounted && !silentIfThrottled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yeni kod gönderildi.'), behavior: SnackBarBehavior.floating),
        );
      }
    } on ApiException catch (e) {
      if (e.status == 429) {
        // Kısa süre önce kod gönderilmiş; o kod hâlâ geçerli.
        _startCooldown();
        if (!silentIfThrottled && mounted) showError(context, e);
      } else if (e.status == 400) {
        // Muhtemelen adres zaten doğrulanmış.
        try {
          await session.refreshMe();
        } catch (_) {}
        if (!mounted) return;
        if (session.me?.emailVerified == true) {
          Navigator.of(context).pop();
          return;
        }
        showError(context, e);
      } else if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) return showError(context, 'E-postadaki 6 haneli kodu girin.');
    final session = context.read<Session>();
    setState(() => _busy = true);
    try {
      final profile = await session.api.verifyEmail(code);
      session.setMe(profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta adresiniz doğrulandı.'), behavior: SnackBarBehavior.floating),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<Session>().me?.email ?? 'e-posta adresinize';
    return Scaffold(
      appBar: AppBar(title: const Text('E-posta doğrulama')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.ink),
              children: [
                const TextSpan(text: '6 haneli doğrulama kodu '),
                TextSpan(text: email, style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: ' adresine gönderildi. Kodu aşağıya girin.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'E-postayı göremiyorsanız spam (gereksiz) klasörüne bakın. Kod 15 dakika geçerlidir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          CodeField(controller: _code, onCompleted: _busy ? null : _verify),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Doğrula'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _cooldown > 0 || _sending ? null : () => _send(),
            child: Text(_cooldown > 0 ? 'Kodu tekrar gönder ($_cooldown sn)' : 'Kodu tekrar gönder'),
          ),
          const DevEmailHint(),
        ],
      ),
    );
  }
}

/// 6 haneli kod giriş kutusu (yalnızca rakam).
class CodeField extends StatelessWidget {
  final TextEditingController controller;

  /// 6 hane girildiğinde çağrılır (isteğe bağlı).
  final VoidCallback? onCompleted;
  const CodeField({super.key, required this.controller, this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 12),
      decoration: const InputDecoration(hintText: '······', counterText: ''),
      onChanged: (v) {
        if (v.length == 6) onCompleted?.call();
      },
    );
  }
}

/// Yalnızca test (debug) sürümünde: kodların nerede görüleceğini söyleyen küçük not.
class DevEmailHint extends StatelessWidget {
  const DevEmailHint({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SelectableText(
        'Test modu: e-posta ayarı yoksa kodlar gerçekten gönderilmez. Kodu bilgisayarınızın tarayıcısında '
        'http://localhost:3000/dev/emails adresinde görebilirsiniz '
        '(bu cihazdan: ${AppConfig.apiUrl}/dev/emails).',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    );
  }
}

/// E-posta doğrulanmamışsa gösterilen küçük uyarı kartı.
class VerifyEmailBanner extends StatelessWidget {
  const VerifyEmailBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().me;
    if (me == null || me.emailVerified) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'E-posta adresinizi doğrulayın.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
            ),
            child: const Text('Doğrula'),
          ),
        ],
      ),
    );
  }
}
