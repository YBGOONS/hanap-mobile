import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';
import '../theme/app_theme.dart';
import 'admin/admin_dashboard_screen.dart';
import 'client/client_dashboard_screen.dart';
import 'public/home_screen.dart';
import 'public/nbi_upload_screen.dart';
import 'public/pending_approval_screen.dart';
import 'worker/worker_dashboard_screen.dart';

/// First thing shown on app boot — kicks off Supabase.initialize() itself
/// (rather than main() awaiting it before runApp()) so this branded splash
/// is guaranteed to actually render, instead of betting on how fast the
/// native pre-Flutter browser loader is. Holds for a minimum duration so
/// the glitch/dot animation is visible even when init finishes instantly.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey),
      Future.delayed(const Duration(milliseconds: 1600)),
    ]);
    if (!mounted) return;

    // A refresh reloads the whole web app from scratch — Supabase persists
    // the session in local storage, but nothing was routing back into it,
    // so every refresh dumped a logged-in user onto the public homepage
    // (looked exactly like being logged out, even though the session was
    // still valid). Mirrors LoginScreen._handleLogin's role-based routing
    // since a refresh never goes through that flow.
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      return;
    }

    try {
      final userId = session.user.id;
      final profile = await Supabase.instance.client.from('profiles').select().eq('id', userId).single();
      final role = profile['role'] as String;
      final status = profile['status'] as String;
      final nbiPath = profile['nbi_clearance_path'] as String?;
      if (!mounted) return;

      if (role == 'worker' && nbiPath == null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => NbiUploadScreen(userId: userId)));
        return;
      }
      if (role == 'worker' && status == 'pending') {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PendingApprovalScreen()));
        return;
      }
      if (status == 'rejected' || (role == 'admin' && !kIsWeb)) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
        return;
      }

      final dashboard = switch (role) {
        'admin' => const AdminDashboardScreen(),
        'worker' => const WorkerDashboardScreen(),
        _ => const ClientDashboardScreen(),
      };
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => dashboard));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GlitchLogo(),
            const SizedBox(height: 28),
            const _LoadingDots(),
          ],
        ),
      ),
    );
  }
}

/// "HANAP" wordmark with a subtle chromatic-aberration wobble — a red and a
/// cyan ghost copy drift a couple pixels around the solid white/gold text.
class _GlitchLogo extends StatefulWidget {
  const _GlitchLogo();

  @override
  State<_GlitchLogo> createState() => _GlitchLogoState();
}

class _GlitchLogoState extends State<_GlitchLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppText.heading(size: 44).copyWith(letterSpacing: -1);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * math.pi * 2;
        final dx = math.sin(t * 2) * 2.2;
        final dy = math.cos(t * 3) * 1.3;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(offset: Offset(-dx, dy), child: _wordmark(style, const Color(0xFFFF3B4E).withValues(alpha: 0.55))),
            Transform.translate(offset: Offset(dx, -dy), child: _wordmark(style, const Color(0xFF3BD8FF).withValues(alpha: 0.55))),
            _wordmark(style, null),
          ],
        );
      },
    );
  }

  Widget _wordmark(TextStyle style, Color? solidColor) {
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: "HAN", style: solidColor != null ? TextStyle(color: solidColor) : null),
          TextSpan(text: "AP", style: TextStyle(color: solidColor ?? AppColors.gold)),
        ],
      ),
    );
  }
}

/// Three dots, one at a time smoothly brightening gold as a "wave" passes
/// through them left to right, looping.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final progress = _c.value * 3;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i != 0) const SizedBox(width: 8),
              _Dot(highlight: (1 - (progress - i).abs()).clamp(0.0, 1.0)),
            ],
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  final double highlight;
  const _Dot({required this.highlight});

  @override
  Widget build(BuildContext context) {
    final size = 6.0 + highlight * 3.0;
    final color = Color.lerp(Colors.white.withValues(alpha: 0.25), AppColors.gold, highlight)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: highlight > 0.4 ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.5 * highlight), blurRadius: 8)] : null,
      ),
    );
  }
}
