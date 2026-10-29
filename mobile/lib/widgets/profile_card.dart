import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Kaydırılan profil kartı. Fotoğrafın sağına/soluna dokununca sonraki/önceki fotoğraf açılır.
class ProfileCard extends StatefulWidget {
  final UserProfile user;
  const ProfileCard({super.key, required this.user});
  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final photos = u.photos;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: LayoutBuilder(
        builder: (context, box) => GestureDetector(
          onTapUp: (d) {
            if (photos.length < 2) return;
            setState(() {
              if (d.localPosition.dx > box.maxWidth / 2) {
                _photo = (_photo + 1).clamp(0, photos.length - 1);
              } else {
                _photo = (_photo - 1).clamp(0, photos.length - 1);
              }
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.ink),
              if (photos.isNotEmpty)
                Image.network(
                  photos[_photo].url,
                  key: ValueKey(photos[_photo].url),
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
                ),
              // Alt kısımda yazıların okunması için karartma
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.5, 1],
                    colors: [Colors.transparent, Color(0xDD000000)],
                  ),
                ),
              ),
              if (photos.length > 1)
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      for (var i = 0; i < photos.length; i++)
                        Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i == _photo ? Colors.white : Colors.white38,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: u.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: '  ${u.age}', style: const TextStyle(fontWeight: FontWeight.w400)),
                      ]),
                      style: const TextStyle(color: Colors.white, fontSize: 30),
                    ),
                    if (u.distanceKm != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Text('${u.distanceKm} km uzakta', style: const TextStyle(color: Colors.white70)),
                        ]),
                      ),
                    if (u.bio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(u.bio,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35)),
                      ),
                    if (u.interests.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in u.interests.take(5))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
