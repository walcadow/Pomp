import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../theme.dart';

/// Sunucu adresini değiştirme penceresi. Adres kaydedildiyse true döner.
Future<bool> showServerSettings(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => const _ServerDialog(),
  );
  return result == true;
}

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();
  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final TextEditingController _url;
  bool _testing = false;
  String? _status;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: AppConfig.apiUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  /// Adresin /health ucunu dener.
  Future<bool> _test(String url) async {
    setState(() {
      _testing = true;
      _status = null;
    });
    var ok = false;
    try {
      final res = await http.get(Uri.parse('$url/health')).timeout(const Duration(seconds: 10));
      ok = res.statusCode == 200 && (jsonDecode(res.body) as Map)['ok'] == true;
    } catch (_) {
      ok = false;
    }
    if (mounted) {
      setState(() {
        _testing = false;
        _ok = ok;
        _status = ok ? 'Bağlantı başarılı ✓' : 'Bu adreste sunucuya ulaşılamadı.';
      });
    }
    return ok;
  }

  Future<void> _save() async {
    final url = AppConfig.normalize(_url.text);
    if (url.isEmpty) return;
    final ok = await _test(url);
    if (!ok || !mounted) return;
    await AppConfig.setServerUrl(url);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _reset() async {
    await AppConfig.setServerUrl(null);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sunucu adresi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TUNEL.bat penceresinde yazan https://...trycloudflare.com adresini buraya yapıştırın.',
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'https://ornek.trycloudflare.com'),
          ),
          if (_testing) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!, style: TextStyle(color: _ok ? AppColors.like : AppColors.nope)),
          ],
        ],
      ),
      actions: [
        if (AppConfig.hasOverride)
          TextButton(onPressed: _testing ? null : _reset, child: const Text('Varsayılan')),
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        TextButton(onPressed: _testing ? null : _save, child: const Text('Kaydet')),
      ],
    );
  }
}
