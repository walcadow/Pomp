import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets/photo_grid.dart';

/// Kayıttan sonra: en az bir fotoğraf ve konum izni olmadan keşfete geçilmez.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _locating = false;
  String? _locationError;

  Future<void> _enableLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    final error = await context.read<Session>().updateLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _locationError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final me = session.me!;
    final hasPhoto = me.photos.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hoş geldin, ${me.name}'),
        actions: [TextButton(onPressed: session.logout, child: const Text('Çıkış'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          const Text('Profilini tamamlayalım.', style: TextStyle(color: AppColors.muted, fontSize: 16)),
          const SizedBox(height: 24),
          _StepTitle(done: hasPhoto, number: 1, text: 'En az bir fotoğraf ekle'),
          const SizedBox(height: 12),
          const PhotoGrid(),
          const SizedBox(height: 32),
          _StepTitle(done: me.hasLocation, number: 2, text: 'Konum iznini aç'),
          const SizedBox(height: 8),
          const Text(
            'Yakınındaki kişileri gösterebilmek için yaklaşık konumunu kullanıyoruz. '
            'Diğer kullanıcılar yalnızca aradaki mesafeyi görür, tam konumunu asla görmez.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (me.hasLocation)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle, color: AppColors.like),
              title: Text('Konum alındı'),
            )
          else
            OutlinedButton.icon(
              onPressed: _locating ? null : _enableLocation,
              icon: _locating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.location_on_outlined),
              label: const Text('Konumumu kullan'),
            ),
          if (_locationError != null) ...[
            const SizedBox(height: 8),
            Text(_locationError!, style: const TextStyle(color: AppColors.nope)),
          ],
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  final bool done;
  final int number;
  final String text;
  const _StepTitle({required this.done, required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: done ? AppColors.like : AppColors.primary,
          child: done
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
