import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/client/payment_result_screen.dart';
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
      // PayMongo redirects the browser straight to /payment-success or
      // /payment-failed after GCash checkout — that's the actual initial
      // route on that fresh page load, so it has to be handled here rather
      // than always falling through to SplashScreen (which owns only '/').
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        if (uri.path == '/payment-success' || uri.path == '/payment-failed') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => PaymentResultScreen(success: uri.path == '/payment-success', jobId: uri.queryParameters['job_id']),
          );
        }
        return MaterialPageRoute(settings: settings, builder: (_) => const SplashScreen());
      },
    );
  }
}
