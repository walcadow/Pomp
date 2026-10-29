import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'config.dart';
import 'models.dart';

/// Sunucudan gelen anlık olayları (yeni mesaj, yeni eşleşme, yazıyor...) dinler.
class Realtime {
  io.Socket? _socket;

  final _messages = StreamController<ChatMessage>.broadcast();
  final _matches = StreamController<Match>.broadcast();
  final _matchRemoved = StreamController<String>.broadcast();
  final _typing = StreamController<String>.broadcast(); // matchId
  final _read = StreamController<String>.broadcast(); // matchId

  Stream<ChatMessage> get onMessage => _messages.stream;
  Stream<Match> get onMatch => _matches.stream;
  Stream<String> get onMatchRemoved => _matchRemoved.stream;
  Stream<String> get onTyping => _typing.stream;
  Stream<String> get onRead => _read.stream;

  void connect(String token) {
    disconnect();
    final socket = io.io(
      AppConfig.apiUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    Map<String, dynamic> asMap(dynamic data) => Map<String, dynamic>.from(data as Map);

    socket.on('message:new', (data) => _messages.add(ChatMessage.fromJson(asMap(data))));
    socket.on('match:new', (data) => _matches.add(Match.fromJson(asMap(data))));
    socket.on('match:removed', (data) => _matchRemoved.add(asMap(data)['matchId'] as String));
    socket.on('typing', (data) => _typing.add(asMap(data)['matchId'] as String));
    socket.on('message:read', (data) => _read.add(asMap(data)['matchId'] as String));

    socket.connect();
    _socket = socket;
  }

  void sendTyping(String matchId) => _socket?.emit('typing', {'matchId': matchId});

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
