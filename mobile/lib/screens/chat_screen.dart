import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/safety_sheet.dart';
import 'matches_screen.dart' show formatTime;
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final Match match;
  const ChatScreen({super.key, required this.match});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = []; // en yeni başta
  final List<StreamSubscription> _subs = [];
  late final Session _session;

  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasOlder = true;
  bool _sending = false;
  bool _otherTyping = false;
  Timer? _typingTimer;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);

  String get _matchId => widget.match.id;

  @override
  void initState() {
    super.initState();
    _session = context.read<Session>();
    _session.openChatMatchId = _matchId;
    _session.markMatchRead(_matchId);

    final rt = _session.realtime;
    _subs
      ..add(rt.onMessage.where((m) => m.matchId == _matchId).listen(_onIncoming))
      ..add(rt.onTyping.where((id) => id == _matchId).listen((_) => _showTyping()))
      ..add(rt.onRead.where((id) => id == _matchId).listen((_) => _markAllMineRead()))
      ..add(rt.onMatchRemoved.where((id) => id == _matchId).listen((_) => _onRemoved()));

    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) _loadOlder();
    });
    _loadInitial();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _typingTimer?.cancel();
    if (_session.openChatMatchId == _matchId) _session.openChatMatchId = null;
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final list = await _session.api.messages(_matchId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _hasOlder = list.length == 50;
        _loading = false;
      });
      _session.api.markRead(_matchId).catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e);
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasOlder || _messages.isEmpty) return;
    _loadingOlder = true;
    try {
      final older = await _session.api.messages(_matchId, before: _messages.last.createdAt);
      if (!mounted) return;
      setState(() {
        _messages.addAll(older.where((o) => !_messages.any((m) => m.id == o.id)));
        _hasOlder = older.length == 50;
      });
    } catch (_) {
      // sessizce geç
    } finally {
      _loadingOlder = false;
    }
  }

  void _onIncoming(ChatMessage msg) {
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() {
      _messages.insert(0, msg);
      if (msg.senderId != _session.me?.id) _otherTyping = false;
    });
    if (msg.senderId != _session.me?.id) {
      _session.api.markRead(_matchId).catchError((_) {});
    }
  }

  void _showTyping() {
    setState(() => _otherTyping = true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _otherTyping = false);
    });
  }

  void _markAllMineRead() {
    final now = DateTime.now();
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        if (m.senderId == _session.me?.id && m.readAt == null) _messages[i] = m.copyWith(readAt: now);
      }
    });
  }

  void _onRemoved() {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu eşleşme artık mevcut değil.'), behavior: SnackBarBehavior.floating),
    );
  }

  void _onChanged(String _) {
    final now = DateTime.now();
    if (now.difference(_lastTypingSent).inSeconds >= 2) {
      _lastTypingSent = now;
      _session.realtime.sendTyping(_matchId);
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await _session.api.sendMessage(_matchId, body);
      _text.clear();
      _onIncoming(msg);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(user: widget.match.user)));
  }

  Future<void> _menu() async {
    final done = await showSafetySheet(context, widget.match);
    if (done && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.match.user;
    final myId = _session.me?.id;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _openProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surface,
                backgroundImage: user.firstPhoto == null ? null : NetworkImage(user.firstPhoto!),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  if (_otherTyping)
                    const Text('yazıyor…', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
        actions: [IconButton(icon: const Icon(Icons.shield_outlined), onPressed: _menu)],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text('${user.name} ile eşleştiniz. İlk mesajı sen gönder! 👋',
                              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 16)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final mine = m.senderId == myId;
                          final showRead = mine && i == 0 && m.readAt != null;
                          return _Bubble(message: m, mine: mine, showRead: showRead);
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      onChanged: _onChanged,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Mesaj yaz…', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool showRead;
  const _Bubble({required this.message, required this.mine, required this.showRead});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: mine ? AppColors.brandGradient : null,
              color: mine ? null : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 4),
                bottomRight: Radius.circular(mine ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(message.body, style: TextStyle(color: mine ? Colors.white : AppColors.ink, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(formatTime(message.createdAt),
                    style: TextStyle(color: mine ? Colors.white70 : AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          if (showRead)
            const Padding(
              padding: EdgeInsets.only(right: 4, bottom: 4),
              child: Text('Görüldü', style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
