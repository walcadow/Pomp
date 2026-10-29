import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../session.dart';
import '../theme.dart';

const reportReasons = {
  'fake': 'Sahte profil',
  'inappropriate_photos': 'Uygunsuz fotoğraflar',
  'harassment': 'Taciz veya rahatsız edici davranış',
  'spam': 'Spam / dolandırıcılık',
  'underage': '18 yaşından küçük olabilir',
  'other': 'Diğer',
};

/// Eşleşmeyi kaldırma, engelleme ve şikâyet menüsü.
/// Kullanıcı bir işlem yaptıysa true döner (sohbet ekranı kapanmalı).
Future<bool> showSafetySheet(BuildContext context, Match match) async {
  final session = context.read<Session>();
  final name = match.user.name;

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.heart_broken_outlined),
          title: const Text('Eşleşmeyi kaldır'),
          onTap: () => Navigator.pop(ctx, 'unmatch'),
        ),
        ListTile(
          leading: const Icon(Icons.block, color: AppColors.nope),
          title: Text('$name kişisini engelle', style: const TextStyle(color: AppColors.nope)),
          onTap: () => Navigator.pop(ctx, 'block'),
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined, color: AppColors.nope),
          title: const Text('Şikâyet et', style: TextStyle(color: AppColors.nope)),
          onTap: () => Navigator.pop(ctx, 'report'),
        ),
      ]),
    ),
  );
  if (action == null || !context.mounted) return false;

  try {
    if (action == 'unmatch') {
      if (!await _confirm(context, 'Eşleşmeyi kaldır?', '$name ile sohbetiniz silinecek.')) return false;
      await session.api.unmatch(match.id);
    } else if (action == 'block') {
      if (!await _confirm(context, '$name engellensin mi?', 'Birbirinizi bir daha görmeyeceksiniz.')) return false;
      await session.api.block(match.user.id);
    } else {
      if (!context.mounted) return false;
      final ok = await showReportDialog(context, match.user.id, name);
      if (!ok) return false;
    }
    session.removeMatch(match.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(action == 'report' ? 'Şikâyetin alındı. Teşekkürler.' : 'Tamam.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Evet', style: TextStyle(color: AppColors.nope)),
        ),
      ],
    ),
  );
  return result == true;
}

/// Şikâyet formu. Gönderildiyse true döner.
Future<bool> showReportDialog(BuildContext context, String userId, String name) async {
  final session = context.read<Session>();
  String? reason;
  final details = TextEditingController();
  bool sending = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('$name kişisini şikâyet et'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<String>(
                groupValue: reason,
                onChanged: (v) => setState(() => reason = v),
                child: Column(
                  children: [
                    for (final r in reportReasons.entries)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: r.key,
                        title: Text(r.value),
                      ),
                  ],
                ),
              ),
              TextField(
                controller: details,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(hintText: 'Ek açıklama (isteğe bağlı)'),
              ),
              const Text('Şikâyet ettiğin kişi otomatik olarak engellenir.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44), backgroundColor: AppColors.nope),
            onPressed: reason == null || sending
                ? null
                : () async {
                    setState(() => sending = true);
                    try {
                      await session.api.report(userId, reason!, details.text.trim());
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setState(() => sending = false);
                      if (ctx.mounted) showError(ctx, e);
                    }
                  },
            child: const Text('Gönder'),
          ),
        ],
      ),
    ),
  );
  details.dispose();
  return result == true;
}
