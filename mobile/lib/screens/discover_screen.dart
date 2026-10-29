import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/profile_card.dart';
import 'chat_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final VoidCallback onOpenMatches;
  const DiscoverScreen({super.key, required this.onOpenMatches});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  final List<UserProfile> _queue = [];
  final Set<String> _seen = {}; // bu oturumda kaydırılan veya yüklenen profiller
  bool _loading = false;
  String? _error;
  bool _exhausted = false;

  // Kart sürükleme
  Offset _drag = Offset.zero;
  late final AnimationController _anim;
  Animation<Offset>? _flyOut;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _anim.addListener(() {
      if (_flyOut != null) setState(() => _drag = _flyOut!.value);
    });
    _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = context.read<Session>();
    var retry = false;
    try {
      final more = await session.api.discover(exclude: _queue.map((u) => u.id).toList());
      final fresh = more.where((u) => !_seen.contains(u.id)).toList();
      _seen.addAll(fresh.map((u) => u.id));
      setState(() {
        _queue.addAll(fresh);
        _exhausted = fresh.isEmpty;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      // Konum eksikse almayı dene; başarılı olursa listeyi bir kez daha yükle.
      if (e.status == 409) retry = await session.updateLocation() == null;
    } catch (_) {
      setState(() => _error = 'Profiller yüklenemedi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (retry && mounted) _load();
  }

  Future<void> _swipe(bool liked) async {
    if (_queue.isEmpty || _anim.isAnimating) return;
    final width = MediaQuery.of(context).size.width;
    final user = _queue.first;

    _flyOut = Tween<Offset>(begin: _drag, end: Offset((liked ? 1.5 : -1.5) * width, _drag.dy + 60))
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    await _anim.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _queue.removeAt(0);
      _drag = Offset.zero;
      _flyOut = null;
    });
    if (_queue.length < 4 && !_exhausted) _load();

    final session = context.read<Session>();
    try {
      final match = await session.api.swipe(user.id, liked);
      if (match != null && mounted) {
        session.addMatch(match);
        _showMatch(match);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _snapBack() {
    _flyOut = Tween<Offset>(begin: _drag, end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
    _anim.forward(from: 0).then((_) => _flyOut = null);
  }

  void _showMatch(Match match) {
    final me = context.read<Session>().me!;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (r) => AppColors.brandGradient.createShader(r),
              child: const Text("Eşleştiniz!",
                  style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 8),
            Text('Sen ve ${match.user.name} birbirinizi beğendiniz.',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Avatar(url: me.firstPhoto),
                const SizedBox(width: 16),
                _Avatar(url: match.user.firstPhoto),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(match: match)));
              },
              child: const Text('Mesaj gönder'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kaydırmaya devam et', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (r) => AppColors.brandGradient.createShader(r),
          child: const Text('pomp', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _queue.clear();
                      _seen.clear();
                      _exhausted = false;
                    });
                    _load();
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: _buildDeck(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundButton(icon: Icons.close_rounded, color: AppColors.nope, onTap: () => _swipe(false)),
                  const SizedBox(width: 36),
                  _RoundButton(icon: Icons.favorite_rounded, color: AppColors.like, onTap: () => _swipe(true)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeck() {
    if (_queue.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return _EmptyState(
        icon: _error != null ? Icons.wifi_off_rounded : Icons.travel_explore_rounded,
        title: _error ?? 'Şimdilik yakınında yeni kimse yok',
        subtitle: _error != null ? null : 'Profil > Ayarlar bölümünden mesafe veya yaş aralığını genişletebilirsin.',
        onRetry: () {
          _exhausted = false;
          _load();
        },
      );
    }

    final width = MediaQuery.of(context).size.width;
    final progress = (_drag.dx / (width * 0.4)).clamp(-1.0, 1.0);
    final visible = _queue.take(2).toList();

    return Stack(
      children: [
        for (var i = visible.length - 1; i >= 0; i--)
          if (i == 0)
            Positioned.fill(
              child: GestureDetector(
                onPanUpdate: (d) => setState(() => _drag += d.delta),
                onPanEnd: (d) {
                  final vx = d.velocity.pixelsPerSecond.dx;
                  if (_drag.dx > width * 0.3 || vx > 900) {
                    _swipe(true);
                  } else if (_drag.dx < -width * 0.3 || vx < -900) {
                    _swipe(false);
                  } else {
                    _snapBack();
                  }
                },
                child: Transform.translate(
                  offset: _drag,
                  child: Transform.rotate(
                    angle: progress * math.pi / 14,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ProfileCard(key: ValueKey(visible[0].id), user: visible[0]),
                        if (progress > 0.05)
                          _Stamp(text: 'BEĞEN', color: AppColors.like, opacity: progress, left: true),
                        if (progress < -0.05)
                          _Stamp(text: 'GEÇ', color: AppColors.nope, opacity: -progress, left: false),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Transform.scale(
                scale: 0.95 + 0.05 * progress.abs(),
                child: ProfileCard(key: ValueKey(visible[i].id), user: visible[i]),
              ),
            ),
      ],
    );
  }
}

class _Stamp extends StatelessWidget {
  final String text;
  final Color color;
  final double opacity;
  final bool left;
  const _Stamp({required this.text, required this.color, required this.opacity, required this.left});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: left ? 24 : null,
      right: left ? null : 24,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: left ? -0.35 : 0.35,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(text, style: TextStyle(color: color, fontSize: 36, fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 68, height: 68, child: Icon(icon, color: color, size: 36)),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  const _Avatar({this.url});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
      child: CircleAvatar(
        radius: 56,
        backgroundColor: AppColors.surface,
        backgroundImage: url == null ? null : NetworkImage(url!),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onRetry;
  const _EmptyState({required this.icon, required this.title, this.subtitle, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: OutlinedButton(onPressed: onRetry, child: const Text('Yenile')),
            ),
          ],
        ),
      ),
    );
  }
}
