import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/categories.dart';
import '../../theme/app_theme.dart';
import '../../widgets/site/hanap_button.dart';
import '../../widgets/site/hanap_dialog.dart';
import '../../widgets/site/hanap_widgets.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Adapted from src/views/pages/Home.js.
/// The web version has a Three.js particle-field hero — not practical
/// (or needed) on mobile, so this uses a native gradient hero instead,
/// keeping the same brand feel: dark bg (#050505) + gold accent, minimal palette.
///
/// TODO(supabase): connect StatsGrid to Supabase (counts from the
/// "jobs" and "profiles" tables) — similar to fetchStats() in the old Home.js.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollCtrl = ScrollController();
  bool _scrolled = false;
  bool _menuOpen = false;

  final _featuresKey = GlobalKey();
  final _howItWorksKey = GlobalKey();
  final _statsKey = GlobalKey();
  final _contactKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final scrolled = _scrollCtrl.offset > 12;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _openLogin() => showHanapDialog(context, (_) => LoginScreen(onSwitchToRegister: _openRegister));
  void _openRegister() => showHanapDialog(context, (_) => RegisterScreen(onSwitchToLogin: _openLogin));

  void _toggleMenu() => setState(() => _menuOpen = !_menuOpen);

  /// Closes the mobile menu, then scrolls to [key] once the overlay's gone
  /// and the underlying CustomScrollView has its normal layout back.
  void _closeMenuAndScrollTo(GlobalKey key) {
    setState(() => _menuOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              SliverToBoxAdapter(child: _buildHero(context)),
              SliverToBoxAdapter(child: KeyedSubtree(key: _statsKey, child: _buildStats())),
              SliverToBoxAdapter(child: _buildCategories()),
              SliverToBoxAdapter(child: KeyedSubtree(key: _featuresKey, child: _buildFeatures())),
              SliverToBoxAdapter(child: KeyedSubtree(key: _howItWorksKey, child: _buildHowItWorks())),
              SliverToBoxAdapter(child: KeyedSubtree(key: _contactKey, child: _buildFooterCta(context))),
            ],
          ),
          if (_menuOpen)
            Positioned.fill(
              child: _MobileMenuOverlay(
                onFeatures: () => _closeMenuAndScrollTo(_featuresKey),
                onHowItWorks: () => _closeMenuAndScrollTo(_howItWorksKey),
                onStats: () => _closeMenuAndScrollTo(_statsKey),
                onContact: () => _closeMenuAndScrollTo(_contactKey),
                onGetStarted: () {
                  setState(() => _menuOpen = false);
                  _openRegister();
                },
                onLogin: () {
                  setState(() => _menuOpen = false);
                  _openLogin();
                },
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GlassNavBar(scrolled: _scrolled, menuOpen: _menuOpen, onMenuTap: _toggleMenu),
          ),
        ],
      ),
    );
  }

  // ── HERO ───────────────────────────────────────────────────────────────
  Widget _buildHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 96, 20, 48),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.2,
          colors: [Color(0xFF141410), AppColors.bg],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BadgePill(text: "Connecting Clients with Skilled Workers").fadeSlideIn(),
          const SizedBox(height: 20),

          RichText(
            text: TextSpan(
              style: AppText.heading(size: 36).copyWith(height: 1.05, letterSpacing: -1),
              children: [
                const TextSpan(text: "Find Workers.\n"),
                TextSpan(
                  text: "Faster.\n",
                  style: TextStyle(color: AppColors.gold, shadows: [Shadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 24)]),
                ),
                const TextSpan(text: "Hire with\n"),
                TextSpan(
                  text: "Confidence.",
                  style: TextStyle(color: AppColors.gold, shadows: [Shadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 24)]),
                ),
              ],
            ),
          ).fadeSlideIn(delay: 80.ms),
          const SizedBox(height: 20),
          Text(
            "HANAP connects you with verified local skilled workers — carpenters, electricians, plumbers, and more — with secure escrow payments and real-time job tracking.",
            style: AppText.body(size: 15, color: AppColors.textSecondary).copyWith(height: 1.6),
          ).fadeSlideIn(delay: 140.ms),
          const SizedBox(height: 28),

          GoldButton(label: "Start Hiring Free →", onPressed: _openRegister).fadeSlideIn(delay: 200.ms),
        ],
      ),
    );
  }

  // ── STATS ──────────────────────────────────────────────────────────────
  Widget _buildStats() {
    return Container(
      color: AppColors.surf,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: const StatsGrid(
        stats: [
          StatEntry("312+", "Jobs Posted", live: true),
          StatEntry("94+", "Verified Workers"),
          StatEntry("98%", "Satisfaction"),
          StatEntry("11+", "Cities Covered"),
        ],
      ).fadeSlideIn(),
    );
  }

  // ── CATEGORIES ─────────────────────────────────────────────────────────
  Widget _buildCategories() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            label: "Services",
            headingFirstLine: "Categories of",
            headingGoldWord: "work",
          ).fadeSlideIn(),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kCategories
                .take(10)
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Text(c, style: AppText.body(size: 13, color: AppColors.textPrimary)),
                    ))
                .toList(),
          ).fadeSlideIn(delay: 100.ms),
        ],
      ),
    );
  }

  // ── FEATURES ───────────────────────────────────────────────────────────
  Widget _buildFeatures() {
    final features = [
      ("🛡️", "Verified Workers", "Every worker goes through an NBI clearance check before approval."),
      ("⚡", "Real-Time Tracking", "From Accepted to Completed — you always know the job status."),
      ("📍", "Near You", "Find workers near your location, fast and convenient."),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            label: "Why Hanap",
            headingFirstLine: "Built for fast,",
            headingGoldWord: "safe work",
          ).fadeSlideIn(),
          const SizedBox(height: 18),
          ...List.generate(features.length, (i) {
            final f = features[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == features.length - 1 ? 0 : 12),
              child: FeatureCard(emoji: f.$1, title: f.$2, description: f.$3).fadeSlideIn(delay: (i * 80).ms),
            );
          }),
        ],
      ),
    );
  }

  // ── HOW IT WORKS ───────────────────────────────────────────────────────
  Widget _buildHowItWorks() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            label: "Process",
            headingFirstLine: "Three steps",
            headingGoldWord: "and you're done",
          ).fadeSlideIn(),
          const SizedBox(height: 24),
          const StepList(
            steps: [
              StepEntry("Post a job", "Enter the category, budget, location, and date."),
              StepEntry("Choose a worker", "Browse nearby, verified workers."),
              StepEntry("Track the progress", "From Accepted to Completed, in real time."),
            ],
          ).fadeSlideIn(delay: 100.ms),
        ],
      ),
    );
  }

  // ── FOOTER CTA ─────────────────────────────────────────────────────────
  Widget _buildFooterCta(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: AppText.heading(size: 22),
              children: [
                const TextSpan(text: "Ready to "),
                TextSpan(
                  text: "get started?",
                  style: AppText.heading(size: 22, color: AppColors.gold).copyWith(
                    shadows: [Shadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 16)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Join HANAP as a client or worker today.",
            style: AppText.body(size: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          GoldButton(label: "Create Account", onPressed: _openRegister),
        ],
      ),
    ).fadeSlideIn();
  }
}

/// Full-screen dark overlay shown below the navbar when the hamburger is
/// tapped — nav links that scroll to a section, plus Get Started/Log In
/// (which live here instead of the navbar itself now).
class _MobileMenuOverlay extends StatelessWidget {
  final VoidCallback onFeatures;
  final VoidCallback onHowItWorks;
  final VoidCallback onStats;
  final VoidCallback onContact;
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;

  const _MobileMenuOverlay({
    required this.onFeatures,
    required this.onHowItWorks,
    required this.onStats,
    required this.onContact,
    required this.onGetStarted,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuLink(label: "Features", onTap: onFeatures),
              _MenuLink(label: "How it Works", onTap: onHowItWorks),
              _MenuLink(label: "Stats", onTap: onStats),
              _MenuLink(label: "Contact", onTap: onContact),
              const SizedBox(height: 24),
              SizedBox(width: 260, child: GoldButton(label: "Get Started Free →", onPressed: onGetStarted)),
              const SizedBox(height: 12),
              SizedBox(width: 260, child: HanapOutlineButton(label: "Log In", onPressed: onLogin)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MenuLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
        child: Text(label, style: AppText.heading(size: 22, color: Colors.white.withValues(alpha: 0.85))),
      ),
    );
  }
}
