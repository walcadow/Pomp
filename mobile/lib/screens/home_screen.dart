import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../session.dart';
import 'chat_screen.dart';
import 'discover_screen.dart';
import 'matches_screen.dart';
import 'profile_screen.dart';

/// Alt menülü ana ekran: Keşfet, Mesajlar, Profil.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  StreamSubscription<String>? _openMatchSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Bildirime dokunulunca ilgili sohbeti aç.
    _openMatchSub = context.read<Session>().push.onOpenMatch.listen(_openChat);
  }

  @override
  void dispose() {
    _openMatchSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openChat(String matchId) async {
    final session = context.read<Session>();
    if (!session.matches.any((m) => m.id == matchId)) await session.loadMatches();
    if (!mounted) return;
    final index = session.matches.indexWhere((m) => m.id == matchId);
    if (index == -1 || session.openChatMatchId == matchId) return;
    setState(() => _tab = 1);
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(match: session.matches[index])));
  }

  // Uygulamaya geri dönülünce konumu ve eşleşmeleri tazele.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final session = context.read<Session>();
      session.updateLocation();
      session.loadMatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.select<Session, int>((s) => s.unreadTotal);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          DiscoverScreen(onOpenMatches: () => setState(() => _tab = 1)),
          const MatchesScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.chat_bubble_outline)),
            selectedIcon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.chat_bubble)),
            label: 'Mesajlar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
