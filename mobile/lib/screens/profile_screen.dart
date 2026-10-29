import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/photo_grid.dart';
import 'user_profile_screen.dart';
import 'verify_email_screen.dart';

const suggestedInterests = [
  'Kahve', 'Kitap', 'Sinema', 'Dizi', 'Müzik', 'Konser', 'Seyahat', 'Yemek', 'Fotoğraf', 'Sanat',
  'Yoga', 'Spor', 'Koşu', 'Futbol', 'Basketbol', 'Bisiklet', 'Yüzme', 'Doğa', 'Kamp', 'Dans',
  'Oyun', 'Yazılım', 'Moda', 'Hayvanlar', 'Kediler', 'Köpekler', 'Şarap', 'Podcast', 'Tarih', 'Festival',
];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().me;
    if (me == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const VerifyEmailBanner(),
          Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
              child: CircleAvatar(
                radius: 64,
                backgroundColor: AppColors.surface,
                backgroundImage: me.firstPhoto == null ? null : NetworkImage(me.firstPhoto!),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text('${me.name}, ${me.age}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Düzenle'),
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Önizle'),
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(user: me))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Güvenliğin için: ilk buluşmayı kalabalık bir yerde yap, para isteyenleri şikâyet et.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late Set<String> _interests;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final me = context.read<Session>().me!;
    _name = TextEditingController(text: me.name);
    _bio = TextEditingController(text: me.bio);
    _interests = {...me.interests};
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = context.read<Session>();
    setState(() => _saving = true);
    try {
      session.setMe(await session.api.updateMe({
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'interests': _interests.toList(),
      }));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili düzenle'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Kaydet', style: TextStyle(fontSize: 16))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Fotoğraflar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('İlk fotoğraf ana fotoğrafındır.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          const PhotoGrid(),
          const SizedBox(height: 24),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Adın')),
          const SizedBox(height: 14),
          TextField(
            controller: _bio,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Hakkımda', alignLabelWithHint: true),
          ),
          const SizedBox(height: 10),
          Text('İlgi alanların (${_interests.length}/10)',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in {...suggestedInterests, ..._interests})
                FilterChip(
                  label: Text(t),
                  selected: _interests.contains(t),
                  onSelected: (on) {
                    if (on && _interests.length >= 10) return showError(context, 'En fazla 10 ilgi alanı seçebilirsin.');
                    setState(() => on ? _interests.add(t) : _interests.remove(t));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late RangeValues _ages;
  late double _distance;
  late Set<String> _interestedIn;
  late String _gender;

  @override
  void initState() {
    super.initState();
    final me = context.read<Session>().me!;
    _ages = RangeValues(me.minAge.toDouble(), me.maxAge.clamp(18, 70).toDouble());
    _distance = me.maxDistanceKm.clamp(1, 200).toDouble();
    _interestedIn = {...me.interestedIn};
    _gender = me.gender;
  }

  Future<void> _save(Map<String, dynamic> data) async {
    final session = context.read<Session>();
    try {
      session.setMe(await session.api.updateMe(data));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteAccount() async {
    final session = context.read<Session>();
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabın silinsin mi?'),
        content: const Text('Profilin, fotoğrafların, eşleşmelerin ve mesajların kalıcı olarak silinir. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hesabımı sil', style: TextStyle(color: AppColors.nope)),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await session.deleteAccount();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Text(text, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    final maxAgeLabel = _ages.end >= 70 ? '70+' : '${_ages.end.round()}';
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          _title('Kimleri görmek istiyorsun?'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              children: [
                for (final g in genderLabels.entries)
                  FilterChip(
                    label: Text(g.value),
                    selected: _interestedIn.contains(g.key),
                    onSelected: (on) {
                      if (!on && _interestedIn.length == 1) return;
                      setState(() => on ? _interestedIn.add(g.key) : _interestedIn.remove(g.key));
                      _save({'interestedIn': _interestedIn.toList()});
                    },
                  ),
              ],
            ),
          ),
          _title('Yaş aralığı: ${_ages.start.round()} – $maxAgeLabel'),
          RangeSlider(
            values: _ages,
            min: 18,
            max: 70,
            divisions: 52,
            onChanged: (v) => setState(() => _ages = v),
            onChangeEnd: (v) => _save({'minAge': v.start.round(), 'maxAge': v.end >= 70 ? 99 : v.end.round()}),
          ),
          _title('En fazla uzaklık: ${_distance.round()} km'),
          Slider(
            value: _distance,
            min: 1,
            max: 200,
            onChanged: (v) => setState(() => _distance = v),
            onChangeEnd: (v) => _save({'maxDistanceKm': v.round()}),
          ),
          _title('Cinsiyetin'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              children: [
                for (final g in genderLabels.entries)
                  ChoiceChip(
                    label: Text(g.value),
                    selected: _gender == g.key,
                    onSelected: (_) {
                      setState(() => _gender = g.key);
                      _save({'gender': g.key});
                    },
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text('Değişiklikler, Keşfet ekranının sağ üstündeki yenile düğmesine bastığında geçerli olur.',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          _title('Hesap'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Kullanım Koşulları'),
            onTap: () => launchUrl(Uri.parse(AppConfig.termsUrl), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Gizlilik ve KVKK'),
            onTap: () => launchUrl(Uri.parse(AppConfig.privacyUrl), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Çıkış yap'),
            onTap: () async {
              await session.logout();
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: AppColors.nope),
            title: const Text('Hesabı sil', style: TextStyle(color: AppColors.nope)),
            onTap: _deleteAccount,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
