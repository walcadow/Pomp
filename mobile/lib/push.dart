import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'api.dart';
import 'config.dart';

/// Uygulama kapalıyken / arka plandayken gelen bildirimler için.
/// Bildirim içeren mesajları Android ve iOS kendisi gösterir; burada ek bir iş yapmıyoruz.
/// Ayrı bir arka plan işleminde çalıştığı için üst düzey (sınıf dışı) bir fonksiyon olmalı.
@pragma('vm:entry-point')
Future<void> pompFirebaseBackgroundHandler(RemoteMessage message) async {}

/// Anlık bildirimler (Firebase Cloud Messaging).
///
/// Firebase ayarlanmamışsa (google-services.json yoksa) veya uygulama
/// Windows'ta çalışıyorsa hiçbir şey yapmaz; uygulama bildirimler olmadan çalışır.
class PushService {
  static const _channelId = 'pomp_default';
  static const _channelName = 'Mesajlar ve eşleşmeler';
  static const _channelDescription = 'Yeni mesaj ve eşleşme bildirimleri';

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final StreamController<String> _openMatch = StreamController<String>.broadcast();
  final List<StreamSubscription> _subs = [];

  bool _disabled = false;
  bool _localReady = false;
  String? _token;

  /// Kullanıcı bir bildirime dokunduğunda ilgili eşleşmenin id'si gelir.
  Stream<String> get onOpenMatch => _openMatch.stream;

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Giriş yapıldıktan sonra çağrılır. Hata fırlatmaz.
  /// [shouldShow]: uygulama açıkken gelen bildirim gösterilsin mi? (ör. o sohbet zaten açıksa hayır)
  Future<void> start(Api api, {bool Function(String? type, String? matchId)? shouldShow}) async {
    if (_disabled || !_supported) return;
    try {
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp();
        } catch (e) {
          // google-services.json (veya iOS'ta GoogleService-Info.plist) yok: bildirimler kapalı.
          _disabled = true;
          debugPrint('Bildirimler kapalı: Firebase ayarlanmamış ($e).');
          return;
        }
      }

      final messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(pompFirebaseBackgroundHandler);
      _cancelSubs();

      // Android 13+ ve iOS'ta bildirim izni ister.
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Bildirim izni verilmedi.');
        return;
      }

      if (Platform.isIOS) {
        // iOS'ta uygulama açıkken de bildirimi sistem göstersin.
        await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      } else {
        await _initLocal();
      }

      final token = await messaging.getToken();
      if (token != null) await _register(api, token);

      _subs
        ..add(messaging.onTokenRefresh.listen((t) => _register(api, t)))
        ..add(FirebaseMessaging.onMessage.listen((m) => _showForeground(m, shouldShow)))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened));

      // Uygulama kapalıyken bildirime dokunularak açıldıysa.
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpened(initial);
    } catch (e) {
      debugPrint('Bildirimler başlatılamadı: $e');
    }
  }

  /// Çıkış yaparken (api.token silinmeden ÖNCE) çağrılır: bu cihaza artık bildirim gelmez. Hata fırlatmaz.
  Future<void> stop(Api api) async {
    _cancelSubs();
    final token = _token;
    _token = null;
    if (_disabled || !_supported || token == null) return;
    try {
      if (api.token != null) {
        await http
            .delete(
              Uri.parse('${AppConfig.apiUrl}/push/token'),
              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${api.token}'},
              body: jsonEncode({'token': token}),
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('Bildirim anahtarı sunucudan silinemedi: $e');
    }
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Önemli değil; sunucu kaydı zaten silindi.
    }
  }

  Future<void> _register(Api api, String token) async {
    _token = token;
    try {
      await api.put('/push/token', {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'});
    } catch (e) {
      debugPrint('Bildirim anahtarı kaydedilemedi: $e');
    }
  }

  Future<void> _initLocal() async {
    if (_localReady) return;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final matchId = response.payload;
        if (matchId != null && matchId.isNotEmpty) _openMatch.add(matchId);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ));
    _localReady = true;
  }

  /// Uygulama açıkken gelen bildirimi Android'de kendimiz gösteririz (sistem göstermez).
  Future<void> _showForeground(RemoteMessage m, bool Function(String? type, String? matchId)? shouldShow) async {
    if (!Platform.isAndroid || !_localReady) return;
    final n = m.notification;
    if (n == null) return;
    final type = m.data['type']?.toString();
    final matchId = m.data['matchId']?.toString();
    if (shouldShow != null && !shouldShow(type, matchId)) return;
    try {
      await _local.show(
        id: (matchId ?? m.messageId ?? '').hashCode & 0x7fffffff,
        title: n.title,
        body: n.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: matchId,
      );
    } catch (e) {
      debugPrint('Bildirim gösterilemedi: $e');
    }
  }

  void _handleOpened(RemoteMessage m) {
    final matchId = m.data['matchId']?.toString();
    if (matchId != null && matchId.isNotEmpty) _openMatch.add(matchId);
  }

  void _cancelSubs() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }
}
