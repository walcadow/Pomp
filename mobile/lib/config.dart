/// Sunucunun adresi.
///
/// Uygulama her zaman [sunucuAdresi] adresine bağlanır. Bu satırı ORACLE_YUKLE.command
/// sunucu kurulunca otomatik doldurur; elle değiştirmenize gerek yoktur.
///
/// Yalnızca geliştirme için başka bir sunucu denenecekse derlerken verilebilir:
///   flutter run --dart-define=API_URL=http://localhost:3000
class AppConfig {
  static const String sunucuAdresi = 'https://129-159-10-228.sslip.io';

  static const String _fromEnv = String.fromEnvironment('API_URL');

  static String get apiUrl => _clean(_fromEnv.isNotEmpty ? _fromEnv : sunucuAdresi);

  static String _clean(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  static String get termsUrl => '$apiUrl/legal/terms';
  static String get privacyUrl => '$apiUrl/legal/privacy';
}
