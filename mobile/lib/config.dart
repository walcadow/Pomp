import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';

/// Sunucunun adresi.
///
/// Öncelik sırası:
///  1. Uygulama içinden kaydedilen adres (Giriş ekranı > "Sunucu ayarı").
///  2. Derlerken verilen adres: flutter build apk --dart-define=API_URL=https://...
///  3. Varsayılan: bilgisayardaki sunucu (Android emülatörü için 10.0.2.2, diğerleri için localhost).
class AppConfig {
  static const String _fromEnv = String.fromEnvironment('API_URL');
  static const String _prefsKey = 'server_url';
  static String? _override;

  /// Uygulama açılırken bir kez çağrılır (main içinde).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.isNotEmpty) _override = saved;
    } catch (_) {
      // Ayar okunamazsa varsayılan adres kullanılır.
    }
  }

  static String get defaultUrl {
    if (_fromEnv.isNotEmpty) return _clean(_fromEnv);
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  static String get apiUrl => _override ?? defaultUrl;

  static bool get hasOverride => _override != null;

  /// Yeni adresi kaydeder. Boş verilirse varsayılana döner.
  static Future<void> setServerUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final value = url == null ? '' : _clean(url);
    if (value.isEmpty) {
      _override = null;
      await prefs.remove(_prefsKey);
    } else {
      _override = value;
      await prefs.setString(_prefsKey, value);
    }
  }

  /// "abc.trycloudflare.com/" gibi yazımları "https://abc.trycloudflare.com" yapar.
  static String normalize(String input) => _clean(input);

  static String _clean(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  static String get termsUrl => '$apiUrl/legal/terms';
  static String get privacyUrl => '$apiUrl/legal/privacy';
}
