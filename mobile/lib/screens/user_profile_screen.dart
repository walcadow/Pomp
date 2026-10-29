import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Eşleşilen kişinin profilini tam ekran gösterir.
class UserProfileScreen extends StatelessWidget {
  final UserProfile user;
  const UserProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(title: Text(user.name)),
      body: ListView(
        children: [
          SizedBox(
            height: height * 0.6,
            child: PageView(
              children: [
                for (final p in user.photos)
                  Image.network(p.url, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppColors.surface)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${user.name}, ${user.age}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                if (user.distanceKm != null)
                  Text('${user.distanceKm} km uzakta', style: const TextStyle(color: AppColors.muted)),
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(user.bio, style: const TextStyle(fontSize: 16, height: 1.45)),
                ],
                if (user.interests.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final t in user.interests) Chip(label: Text(t))],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
