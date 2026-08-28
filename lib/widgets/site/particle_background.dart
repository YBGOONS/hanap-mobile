import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Slow-drifting starfield behind the whole landing page — the mobile
/// equivalent of the old web version's Three.js particle-field hero
/// (see home_screen.dart's doc comment), just spread across the full page
/// instead of only the hero, and done with a plain CustomPainter instead of
/// a 3D engine so it stays cheap enough to run behind a scrolling page.
/// `IgnorePointer`-wrapped so it never intercepts taps meant for the
/// content in front of it.
class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 120))..repeat();
    final rnd = math.Random(7);
    _particles = List.generate(55, (_) {
      return _Particle(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        angle: rnd.nextDouble() * 2 * math.pi,
        speed: 0.015 + rnd.nextDouble() * 0.035,
        radius: 0.8 + rnd.nextDouble() * 1.8,
        opacity: 0.15 + rnd.nextDouble() * 0.35,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ParticlePainter(particles: _particles, t: _controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  final double x, y, angle, speed, radius, opacity;
  const _Particle({required this.x, required this.y, required this.angle, required this.speed, required this.radius, required this.opacity});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  const _ParticlePainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dx = (p.x + math.cos(p.angle) * p.speed * t) % 1.0;
      final dy = (p.y + math.sin(p.angle) * p.speed * t) % 1.0;
      final nx = dx < 0 ? dx + 1 : dx;
      final ny = dy < 0 ? dy + 1 : dy;
      final paint = Paint()..color = AppColors.gold.withValues(alpha: p.opacity);
      canvas.drawCircle(Offset(nx * size.width, ny * size.height), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => oldDelegate.t != t;
}
