import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../session.dart';
import '../theme.dart';

/// Profil fotoğraflarını ekleme / silme ızgarası (en fazla 6).
class PhotoGrid extends StatefulWidget {
  const PhotoGrid({super.key});
  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  static const _max = 6;
  bool _uploading = false;

  Future<void> _add() async {
    final session = context.read<Session>();
    // Bilgisayarda kamera seçeneği yok: doğrudan dosya seçme penceresini aç.
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final source = !isMobile ? ImageSource.gallery : await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galeriden seç'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Fotoğraf çek'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (source == null) return;

    // Fotoğrafı küçültüp JPG olarak alıyoruz: hem hızlı yüklenir hem de her telefonda çalışır.
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1080, maxHeight: 1440, imageQuality: 85);
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      session.setMe(await session.api.uploadPhoto(file.path));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _remove(String photoId) async {
    final session = context.read<Session>();
    try {
      session.setMe(await session.api.deletePhoto(photoId));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = context.watch<Session>().me?.photos ?? const [];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _max,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, i) {
        if (i < photos.length) {
          final photo = photos[i];
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(photo.url, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppColors.surface)),
              ),
              if (i == 0)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Ana', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              Positioned(
                right: 4,
                bottom: 4,
                child: GestureDetector(
                  onTap: () => _remove(photo.id),
                  child: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.close, size: 16, color: AppColors.nope),
                  ),
                ),
              ),
            ],
          );
        }
        final isNext = i == photos.length;
        return GestureDetector(
          onTap: isNext && !_uploading ? _add : null,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isNext ? AppColors.primary : Colors.transparent, width: 1.5),
            ),
            child: Center(
              child: isNext && _uploading
                  ? const CircularProgressIndicator(strokeWidth: 2.5)
                  : Icon(Icons.add_rounded, color: isNext ? AppColors.primary : AppColors.muted, size: 30),
            ),
          ),
        );
      },
    );
  }
}
