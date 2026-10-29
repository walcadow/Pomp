import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'push.dart';
import 'realtime.dart';

enum SessionStatus { loading, loggedOut, loggedIn, offline }

/// Uygulamanın genel durumu: kim giriş yaptı, eşleşmeler, okunmamış mesajlar.
class Session extends ChangeNotifier {
  static const _tokenKey = 'auth_token';

  final Api api = Api();
  final Realtime realtime = Realtime();
  final PushService push = PushService();

  SessionStatus status = SessionStatus.loading;
  UserProfile? me;
  List<Match> matches = [];
  bool matchesLoaded = false;

  /// Şu an açık olan sohbet (bu sohbete gelen mesajlar "okunmamış" sayılmaz).
  String? openChatMatchId;

  final List<StreamSubscription> _subs = [];

  Session() {
    api.onUnauthorized = logout;
  }

  int get unreadTotal => matches.fold(0, (sum, m) => sum + m.unread);

  Future<void> init() async {
    status = SessionStatus.loading;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) {
      status = SessionStatus.loggedOut;
      notifyListeners();
      return;
    }
    api.token = token;
    try {
      me = await api.me();
      _startSession(token);
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await logout();
      } else {
        status = SessionStatus.offline;
        notifyListeners();
      }
    }
  }

  Future<void> login(String email, String password) async {
    final (token, user) = await api.login(email, password);
    await _saveToken(token);
    me = user;
    _startSession(token);
  }

  Future<void> register(Map<String, dynamic> data) async {
    final (token, user) = await api.register(data);
    await _saveToken(token);
    me = user;
    _startSession(token);
  }

  /// Şifre sıfırlama kodu ile yeni şifre belirler ve giriş yapar.
  Future<void> resetPassword(String email, String code, String password) async {
    final (token, user) = await api.resetPassword(email, code, password);
    await _saveToken(token);
    me = user;
    _startSession(token);
  }

  Future<void> _saveToken(String token) async {
    api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  void _startSession(String token) {
    status = SessionStatus.loggedIn;
    realtime.connect(token);
    _listen();
    notifyListeners();
    loadMatches();
    // Test sürümünde profil tamamlama ekranı atlandığı için konumu otomatik al.
    if (kDebugMode && me != null && !me!.hasLocation) updateLocation();
    // Bildirimler (Firebase ayarlı değilse sessizce kapalı kalır).
    // Açık olan sohbetten gelen mesaj için bildirim gösterme.
    push.start(api, shouldShow: (type, matchId) => matchId == null || matchId != openChatMatchId);
  }

  Future<void> logout() async {
    await push.stop(api);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    realtime.disconnect();
    api.token = null;
    me = null;
    matches = [];
    matchesLoaded = false;
    openChatMatchId = null;
    status = SessionStatus.loggedOut;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await api.deleteAccount();
    await logout();
  }

  void setMe(UserProfile profile) {
    me = profile;
    notifyListeners();
  }

  Future<void> refreshMe() async => setMe(await api.me());

  // ---- Konum ----

  /// Geliştirme sırasında konum alınamazsa kullanılacak konum (İstanbul, Kadıköy).
  static const _devLat = 40.9901;
  static const _devLng = 29.0291;

  /// Konumu alıp sunucuya gönderir. Sorun varsa kullanıcıya gösterilecek mesajı döndürür.
  /// Test (debug) sürümünde konum alınamazsa varsayılan bir konum kullanılır.
  Future<String?> updateLocation() async {
    final error = await _updateDeviceLocation();
    if (error == null || !kDebugMode) return error;
    debugPrint('Konum alınamadı ($error). Geliştirme modu: İstanbul konumu kullanılıyor.');
    try {
      await api.updateLocation(_devLat, _devLng);
      if (me != null && !me!.hasLocation) await refreshMe();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> _updateDeviceLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return Platform.isWindows
          ? 'Windows konum servisi kapalı. Ayarlar > Gizlilik > Konum bölümünden açın.'
          : 'Telefonunuzun konum servisi kapalı. Ayarlardan açın.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Yakınınızdaki kişileri gösterebilmemiz için konum izni gerekiyor.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Konum izni kapalı. Telefon Ayarları > Pomp > Konum bölümünden izin verin.';
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await api.updateLocation(pos.latitude, pos.longitude);
      if (me != null && !me!.hasLocation) await refreshMe();
      return null;
    } catch (_) {
      return 'Konumunuz alınamadı. Tekrar deneyin.';
    }
  }

  // ---- Eşleşmeler ----

  Future<void> loadMatches() async {
    try {
      matches = await api.matches();
      matchesLoaded = true;
      notifyListeners();
    } catch (_) {
      // Ekranda tekrar deneme düğmesi var.
    }
  }

  void addMatch(Match match) {
    if (matches.any((m) => m.id == match.id)) return;
    matches = [match, ...matches];
    notifyListeners();
  }

  void removeMatch(String matchId) {
    matches = matches.where((m) => m.id != matchId).toList();
    notifyListeners();
  }

  void markMatchRead(String matchId) {
    matches = [for (final m in matches) m.id == matchId ? m.copyWith(unread: 0) : m];
    notifyListeners();
  }

  void _listen() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs
      ..clear()
      ..add(realtime.onMatch.listen(addMatch))
      ..add(realtime.onMatchRemoved.listen(removeMatch))
      ..add(realtime.onMessage.listen(_onMessage));
  }

  void _onMessage(ChatMessage msg) {
    final index = matches.indexWhere((m) => m.id == msg.matchId);
    if (index == -1) {
      loadMatches();
      return;
    }
    final m = matches[index];
    final fromOther = msg.senderId != me?.id;
    final isOpen = openChatMatchId == msg.matchId;
    final updated = m.copyWith(
      lastMessage: msg,
      unread: fromOther && !isOpen ? m.unread + 1 : m.unread,
    );
    matches = [updated, ...matches.where((x) => x.id != msg.matchId)];
    notifyListeners();
  }
}
