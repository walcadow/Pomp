import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

/// Sunucuyla konuşan tüm istekler burada.
class Api {
  String? token;
  void Function()? onUnauthorized;

  Api({this.token});

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.apiUrl}$path').replace(queryParameters: query);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiException(0, 'Sunucuya ulaşılamadı. İnternet bağlantınızı ve sunucunun açık olduğunu kontrol edin.');
    } on Exception {
      throw ApiException(0, 'Sunucuya ulaşılamadı. Bağlantınızı kontrol edip tekrar deneyin.');
    }

    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401 && token != null) onUnauthorized?.call();
    final message = (body is Map && body['error'] is String) ? body['error'] as String : 'Bir hata oluştu (${res.statusCode}).';
    throw ApiException(res.statusCode, message);
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) =>
      _send(() => http.get(_uri(path, query), headers: _headers));
  Future<dynamic> post(String path, [Object? data]) =>
      _send(() => http.post(_uri(path), headers: _headers, body: jsonEncode(data ?? {})));
  Future<dynamic> patch(String path, Object data) =>
      _send(() => http.patch(_uri(path), headers: _headers, body: jsonEncode(data)));
  Future<dynamic> put(String path, Object data) =>
      _send(() => http.put(_uri(path), headers: _headers, body: jsonEncode(data)));
  Future<dynamic> delete(String path) => _send(() => http.delete(_uri(path), headers: _headers));

  // ---- Giriş / kayıt ----
  Future<(String, UserProfile)> login(String email, String password) async {
    final j = await post('/auth/login', {'email': email, 'password': password});
    return (j['token'] as String, UserProfile.fromJson(Map<String, dynamic>.from(j['user'] as Map)));
  }

  Future<(String, UserProfile)> register(Map<String, dynamic> data) async {
    final j = await post('/auth/register', data);
    return (j['token'] as String, UserProfile.fromJson(Map<String, dynamic>.from(j['user'] as Map)));
  }

  // ---- Profil ----
  Future<UserProfile> me() async => UserProfile.fromJson(Map<String, dynamic>.from(await get('/me') as Map));

  Future<UserProfile> updateMe(Map<String, dynamic> data) async =>github
      UserProfile.fromJson(Map<String, dynamic>.from(await patch('/me', data) as Map));

  Future<void> updateLocation(double lat, double lng) => put('/me/location', {'lat': lat, 'lng': lng});

  Future<UserProfile> uploadPhoto(String filePath) async {
    return _send(() async {
      final req = http.MultipartRequest('POST', _uri('/me/photos'));
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.files.add(await http.MultipartFile.fromPath('photo', filePath));
      return http.Response.fromStream(await req.send());
    }).then((j) => UserProfile.fromJson(Map<String, dynamic>.from(j as Map)));
  }

  Future<UserProfile> deletePhoto(String photoId) async =>
      UserProfile.fromJson(Map<String, dynamic>.from(await delete('/me/photos/$photoId') as Map));

  Future<void> deleteAccount() => delete('/me');

  // ---- Keşfet ----
  Future<List<UserProfile>> discover({List<String> exclude = const []}) async {
    final list = await get('/discover', exclude.isEmpty ? null : {'exclude': exclude.join(',')}) as List;
    return list.map((e) => UserProfile.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Eşleşme olursa Match döner, olmazsa null.
  Future<Match?> swipe(String targetId, bool liked) async {
    final j = await post('/swipes', {'targetId': targetId, 'liked': liked});
    if (j['matched'] == true && j['match'] != null) {
      return Match.fromJson(Map<String, dynamic>.from(j['match'] as Map));
    }
    return null;
  }

  // ---- Eşleşmeler & sohbet ----
  Future<List<Match>> matches() async {
    final list = await get('/matches') as List;
    return list.map((e) => Match.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<ChatMessage>> messages(String matchId, {DateTime? before}) async {
    final list = await get('/matches/$matchId/messages',
        before == null ? null : {'before': before.toUtc().toIso8601String()}) as List;
    return list.map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<ChatMessage> sendMessage(String matchId, String body) async => ChatMessage.fromJson(
      Map<String, dynamic>.from(await post('/matches/$matchId/messages', {'body': body}) as Map));

  Future<void> markRead(String matchId) => post('/matches/$matchId/read');

  Future<void> unmatch(String matchId) => delete('/matches/$matchId');

  // ---- Güvenlik ----
  Future<void> block(String userId) => post('/users/$userId/block');

  Future<void> report(String userId, String reason, String details) =>
      post('/users/$userId/report', {'reason': reason, 'details': details});
}
