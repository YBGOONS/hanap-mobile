import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HanapApp());
}

/// Shorthand used across screens, e.g. `supabase.auth.signInWithPassword(...)`.
final supabase = Supabase.instance.client;

class HanapApp extends StatelessWidget {
  const HanapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HANAP',
      debugShowCheckedModeBanner: false,
      theme: buildHanapTheme(),
      home: const SplashScreen(),
    );
  }
}
