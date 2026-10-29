import 'dart:io' show Platform;

/// Sunucunun adresi.
///
/// Varsayılan olarak bilgisayarınızda çalışan sunucuya bağlanır:
///  - Android emülatörü bilgisayarı 10.0.2.2 adresinden görür.
///  - iOS simülatörü localhost'u kullanabilir.
///
/// Gerçek bir telefonda denerken bilgisayarınızın yerel ağ adresini verin:
///   flutter run --dart-define=API_URL=http://192.168.1.20:3000
class AppConfig {
  static const String _fromEnv = String.fromEnvironment('API_URL');

  static String get apiUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv.replaceAll(RegExp(r'/$'), '');
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  static String get termsUrl => '$apiUrl/legal/terms';
  static String get privacyUrl => '$apiUrl/legal/privacy';
}
