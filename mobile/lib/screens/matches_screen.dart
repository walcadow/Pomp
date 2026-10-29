import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../session.dart';
import '../theme.dart';
import 'chat_screen.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final matches = session.matches;
    final newMatches = matches.where((m) => m.lastMessage == null).toList();
    final conversations = matches.where((m) => m.lastMessage != null).toList();

    Widget body;
    if (!session.matchesLoaded) {
      body = Center(
        child: FutureBuilder(
          future: Future.delayed(const Duration(seconds: 4)),
          builder: (context, snap) => snap.connectionState == ConnectionState.done
              ? OutlinedButton(onPressed: session.loadMatches, child: const Text('Tekrar dene'))
              : const CircularProgressIndicator(),
        ),
      );
    } else if (matches.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border_rounded, size: 64, color: AppColors.accent),
              SizedBox(height: 16),
              Text('Henüz eşleşme yok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text('Keşfet sekmesinde kaydırmaya devam et. Karşılıklı beğenide burada görünecek.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: session.loadMatches,
        child: ListView(
          children: [
            if (newMatches.isNotEmpty) ...[
              const _SectionTitle('Yeni eşleşmeler'),
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: newMatches.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) {
                    final m = newMatches[i];
                    return GestureDetector(
                      onTap: () => _open(context, m),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.surface,
                              backgroundImage: m.user.firstPhoto == null ? null : NetworkImage(m.user.firstPhoto!),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(m.user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            if (conversations.isNotEmpty) const _SectionTitle('Mesajlar'),
            for (final m in conversations) _ConversationTile(match: m, myId: session.me?.id),
          ],
        ),
      );
    }

    return Scaffold(appBar: AppBar(title: const Text('Mesajlar')), body: body);
  }

  static void _open(BuildContext context, Match m) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(match: m)));
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Text(text,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15)),
      );
}

class _ConversationTile extends StatelessWidget {
  final Match match;
  final String? myId;
  const _ConversationTile({required this.match, required this.myId});

  @override
  Widget build(BuildContext context) {
    final last = match.lastMessage!;
    final mine = last.senderId == myId;
    final unread = match.unread > 0;
    return ListTile(
      onTap: () => MatchesScreen._open(context, match),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.surface,
        backgroundImage: match.user.firstPhoto == null ? null : NetworkImage(match.user.firstPhoto!),
      ),
      title: Text(match.user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        '${mine ? 'Sen: ' : ''}${last.body}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread ? AppColors.ink : AppColors.muted,
          fontWeight: unread ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatTime(last.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          if (unread) ...[
            const SizedBox(height: 4),
            CircleAvatar(
              radius: 10,
              backgroundColor: AppColors.accent,
              child: Text('${match.unread}', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}

String formatTime(DateTime t) {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  if (t.year == now.year && t.month == now.month && t.day == now.day) return '${two(t.hour)}:${two(t.minute)}';
  final yesterday = now.subtract(const Duration(days: 1));
  if (t.year == yesterday.year && t.month == yesterday.month && t.day == yesterday.day) return 'Dün';
  return '${two(t.day)}.${two(t.month)}';
}
