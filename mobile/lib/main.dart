import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'session.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => Session()..init(),
      child: const PompApp(),
    ),
  );
}

class PompApp extends StatelessWidget {
  const PompApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomp',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

/// Giriş durumuna göre doğru ekranı gösterir.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    switch (session.status) {
      case SessionStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case SessionStatus.offline:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Sunucuya ulaşılamadı.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('İnternet bağlantınızı ve sunucunun açık olduğunu kontrol edin.', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: session.init, child: const Text('Tekrar dene')),
                ],
              ),
            ),
          ),
        );
      case SessionStatus.loggedOut:
        return const WelcomeScreen();
      case SessionStatus.loggedIn:
        final me = session.me!;
        // Profil tamamlanmadıysa (fotoğraf veya konum yok) önce onu tamamlat.
        // Test (debug) sürümünde bu adım atlanır.
        if (!kDebugMode && (me.photos.isEmpty || !me.hasLocation)) return const OnboardingScreen();
        return const HomeScreen();
    }
  }
}
