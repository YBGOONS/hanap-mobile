import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import 'hanap_button.dart';

/// Below this width, the Home page's navbar collapses to the hamburger
/// menu and its sections stop being width-capped — i.e. the real mobile
/// app, always. At/above it (a wide browser window), the navbar shows
/// inline links + CTAs and section content centers with a max width
/// instead of stretching edge-to-edge.
const double siteWideBreakpoint = 860.0;

/// Small entrance animation used across scroll sections — approximates the
/// web's scroll-triggered fade+slide-in (IntersectionObserver) as a
/// play-on-build transition, which is the practical mobile equivalent.
extension EntranceAnimation on Widget {
  Widget fadeSlideIn({Duration delay = Duration.zero}) {
    return animate(delay: delay)
        .fadeIn(duration: 450.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, duration: 450.ms, curve: Curves.easeOut);
  }
}

/// The "hanap" wordmark — plain white "han" + gold "ap" — used in the navbar,
/// the footer, and both legal pages' top bar. Pulled out on its own so it
/// stays pixel-identical everywhere it appears.
class HanapWordmark extends StatelessWidget {
  final double size;
  const HanapWordmark({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppText.heading(size: size),
        children: const [
          TextSpan(text: "han"),
          TextSpan(
            text: "ap",
            style: TextStyle(color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

/// Small glowing/pulsing dot — used in badges and "live" stat indicators.
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulsingDot({super.key, this.color = AppColors.live, this.size = 8});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.5,
      height: widget.size * 2.5,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0) * 0.6,
                child: Container(
                  width: widget.size * (1 + t * 1.5),
                  height: widget.size * (1 + t * 1.5),
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rounded pill with a glowing dot indicator — translucent gold bg + thin gold border.
class BadgePill extends StatelessWidget {
  final String text;
  final bool showDot;
  final Color dotColor;
  const BadgePill({
    super.key,
    required this.text,
    this.showDot = true,
    this.dotColor = AppColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.goldBg,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            PulsingDot(color: dotColor, size: 6),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: AppText.body(
              size: 12,
              weight: FontWeight.w600,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Feature card — subtle bg + hairline border, presses toward gold w/ glow shadow.
class FeatureCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String description;
  final VoidCallback? onTap;
  const FeatureCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.description,
    this.onTap,
  });

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap != null) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _pressed ? AppColors.goldBg : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed ? AppColors.goldBorder : AppColors.hairline,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 14),
            Text(
              widget.title,
              style: AppText.heading(size: 15, letterSpacing: -0.2),
            ),
            const SizedBox(height: 6),
            Text(
              widget.description,
              style: AppText.body(
                size: 12.5,
                color: AppColors.textSecondary,
              ).copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// One stat's value/label. [live] shows a pulsing "LIVE" indicator above the number.
class StatEntry {
  final String value;
  final String label;
  final bool live;
  const StatEntry(this.value, this.label, {this.live = false});
}

/// Number that counts up from 0 with an ease-out-cubic curve when it first builds.
class AnimatedStatValue extends StatelessWidget {
  final String value; // e.g. "312+", "98%"
  final TextStyle style;
  const AnimatedStatValue({
    super.key,
    required this.value,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^(\d+)(.*)$').firstMatch(value);
    if (match == null) return Text(value, style: style);
    final target = int.parse(match.group(1)!);
    final suffix = match.group(2)!;
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: target),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) => Text("$val$suffix", style: style),
    );
  }
}

/// Grid of stat cards divided by 1px hairline separators (table-like).
class StatsGrid extends StatelessWidget {
  final List<StatEntry> stats;
  final int columns;
  const StatsGrid({super.key, required this.stats, this.columns = 2});

  @override
  Widget build(BuildContext context) {
    final rows = <List<StatEntry>>[
      for (var i = 0; i < stats.length; i += columns)
        stats.sublist(
          i,
          (i + columns > stats.length) ? stats.length : i + columns,
        ),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++)
            Row(
              children: [
                for (var c = 0; c < rows[r].length; c++)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 22,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          right: c != rows[r].length - 1
                              ? BorderSide(color: AppColors.hairline)
                              : BorderSide.none,
                          bottom: r != rows.length - 1
                              ? BorderSide(color: AppColors.hairline)
                              : BorderSide.none,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (rows[r][c].live) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const PulsingDot(size: 5),
                                const SizedBox(width: 5),
                                Text("LIVE", style: AppText.label(size: 9)),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          AnimatedStatValue(
                            value: rows[r][c].value,
                            style: AppText.heading(
                              size: 26,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rows[r][c].label.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: AppText.body(
                              size: 10.5,
                              weight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ).copyWith(letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Small uppercase gold label above a 2-line heading; the last line glows gold.
class SectionHeading extends StatelessWidget {
  final String label;
  final String headingFirstLine;
  final String headingGoldWord;
  final CrossAxisAlignment align;
  const SectionHeading({
    super.key,
    required this.label,
    required this.headingFirstLine,
    required this.headingGoldWord,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final textAlign = align == CrossAxisAlignment.center
        ? TextAlign.center
        : TextAlign.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label.toUpperCase(), style: AppText.label(), textAlign: textAlign),
        const SizedBox(height: 10),
        RichText(
          textAlign: textAlign,
          text: TextSpan(
            style: AppText.heading(size: 26, height: 1.2),
            children: [
              TextSpan(text: "$headingFirstLine\n"),
              TextSpan(
                text: headingGoldWord,
                style:
                    AppText.heading(
                      size: 26,
                      height: 1.2,
                      color: AppColors.gold,
                    ).copyWith(
                      shadows: [
                        Shadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One numbered step; used inside [StepList].
class StepEntry {
  final String title;
  final String description;
  const StepEntry(this.title, this.description);
}

/// Numbered circle badges connected by a vertical gradient line (timeline/stepper).
class StepList extends StatelessWidget {
  final List<StepEntry> steps;
  const StepList({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.goldBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.goldBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        "${i + 1}",
                        style: AppText.heading(size: 14, color: AppColors.gold),
                      ),
                    ),
                    if (i != steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.goldBorder,
                                AppColors.hairline,
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == steps.length - 1 ? 0 : 28,
                      top: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: AppText.heading(size: 16, letterSpacing: -0.2),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          steps[i].description,
                          style: AppText.body(
                            size: 13,
                            color: AppColors.textSecondary,
                          ).copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Navbar that's transparent by default and becomes a solid, blurred
/// (glassmorphism) bar once [scrolled] is true (also forced solid while
/// [menuOpen], so it reads as one seamless surface with the menu overlay
/// beneath it). The right side is a bordered hamburger/close toggle —
/// Login/Register live inside the mobile menu now, not the bar itself.
class GlassNavBar extends StatelessWidget {
  final bool scrolled;
  final bool menuOpen;
  final VoidCallback onMenuTap;
  final VoidCallback onFeatures;
  final VoidCallback onHowItWorks;
  final VoidCallback onStats;
  final VoidCallback onContact;
  final VoidCallback onLogin;
  final VoidCallback onGetStarted;

  const GlassNavBar({
    super.key,
    required this.scrolled,
    required this.menuOpen,
    required this.onMenuTap,
    required this.onFeatures,
    required this.onHowItWorks,
    required this.onStats,
    required this.onContact,
    required this.onLogin,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    final solid = scrolled || menuOpen;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: solid ? 16 : 0,
          sigmaY: solid ? 16 : 0,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: solid ? 14 : 18,
          ),
          decoration: BoxDecoration(
            color: solid
                ? AppColors.bg.withValues(alpha: 0.85)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: solid ? AppColors.hairline : Colors.transparent,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= siteWideBreakpoint) {
                  return _buildWide();
                }
                return _buildNarrow();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNarrow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const HanapWordmark(),
        InkWell(
          onTap: onMenuTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              menuOpen ? Icons.close : Icons.menu,
              color: AppColors.gold,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWide() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const HanapWordmark(),
        Row(
          children: [
            _NavLink(label: "Features", onTap: onFeatures),
            _NavLink(label: "How it Works", onTap: onHowItWorks),
            _NavLink(label: "Stats", onTap: onStats),
            _NavLink(label: "Contact", onTap: onContact),
          ],
        ),
        Row(
          children: [
            _NavLink(label: "Log In", onTap: onLogin),
            const SizedBox(width: 16),
            SizedBox(
              width: 150,
              child: GoldButton(label: "Get Started", onPressed: onGetStarted),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: AppText.body(
            size: 14,
            weight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class FaqEntry {
  final String question;
  final String answer;
  const FaqEntry(this.question, this.answer);
}

/// One expandable FAQ row — "+" turns into "x" when opened, tapping either
/// state toggles it. Only this row's own answer shows/hides; siblings are
/// independent (no accordion-style "only one open at a time" behavior,
/// since there's no reason a user couldn't want two answers open together).
class FaqTile extends StatefulWidget {
  final FaqEntry entry;
  const FaqTile({super.key, required this.entry});

  @override
  State<FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _open ? AppColors.goldBorder : AppColors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.entry.question,
                      style: AppText.body(
                        size: 14.5,
                        weight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: _open ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.add, color: AppColors.gold, size: 20),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.entry.answer,
                style: AppText.body(
                  size: 13.5,
                  color: AppColors.textSecondary,
                ).copyWith(height: 1.55),
              ),
            ),
            crossFadeState: _open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }
}
