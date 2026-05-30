import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/welcome_screen.dart';
import 'screens/outdoor_screen.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const IndoorNavigationApp());
}

class IndoorNavigationApp extends StatefulWidget {
  const IndoorNavigationApp({super.key});

  @override
  State<IndoorNavigationApp> createState() => _IndoorNavigationAppState();
}

class _IndoorNavigationAppState extends State<IndoorNavigationApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _authSubscription;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _lastUserId = Supabase.instance.client.auth.currentSession?.user.id;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final currentUserId = session?.user.id;

      if (currentUserId != _lastUserId) {
        setState(() {
          _lastUserId = currentUserId;
        });

        if (currentUserId != null) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OutdoorScreen()),
            (route) => false,
          );
        } else {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine start screen based on existing session
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4FC3F7),
          brightness: Brightness.dark,
        ),
      ),
      home: session != null ? const OutdoorScreen() : const WelcomeScreen(),
    );
  }
}