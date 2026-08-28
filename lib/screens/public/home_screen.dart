import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../../models/categories.dart';
import '../../theme/app_theme.dart';
import '../../widgets/site/hanap_button.dart';
import '../../widgets/site/hanap_dialog.dart';
import '../../widgets/site/hanap_widgets.dart';
import '../../widgets/site/particle_background.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'register_screen.dart';
import 'terms_of_service_screen.dart';

/// Adapted from src/views/pages/Home.js. The web version's Three.js
/// particle-field hero is approximated here with a lightweight
/// CustomPainter starfield (see widgets/site/particle_background.dart),
/// spanning the whole page instead of just the hero — cheap enough to run
/// behind a scrolling page on mobile. Same brand feel otherwise: dark bg
/// (#050505) + gold accent, minimal palette.
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
  final _faqKey = GlobalKey();

  late final Future<List<StatEntry>> _statsFuture = _loadStats();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final scrolled = _scrollCtrl.offset > 12;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    });
  }

  /// Real counts from `public.public_stats()` (see supabase/schema.sql) —
  /// a security-definer RPC, since a signed-out visitor can't select from
  /// jobs/profiles directly under RLS. Falls back to the old placeholder
  /// numbers if the call fails (e.g. offline), so the section never renders
  /// blank/broken for a visitor who just hasn't got a connection.
  Future<List<StatEntry>> _loadStats() async {
    try {
      final rows = await supabase.rpc('public_stats') as List;
      final row = rows.first as Map<String, dynamic>;
      return [
        StatEntry("${row['jobs_posted']}", "Jobs Posted", live: true),
        StatEntry("${row['verified_workers']}", "Verified Workers"),
        StatEntry("${(row['satisfaction_pct'] as num).toInt()}%", "Satisfaction"),
        StatEntry("${row['cities_covered']}", "Cities Covered"),
      ];
    } catch (_) {
      return const [
        StatEntry("0", "Jobs Posted", live: true),
        StatEntry("0", "Verified Workers"),
        StatEntry("0%", "Satisfaction"),
        StatEntry("0", "Cities Covered"),
      ];
    }
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
  /// `alignment: 0.5` centers the target section in the viewport instead of
  /// just nudging it to the nearest edge, which on a short section (like
  /// FAQ or a single "Process" step) could otherwise land it half-visible
  /// right at the top or bottom edge of the screen.
  void _closeMenuAndScrollTo(GlobalKey key) {
    setState(() => _menuOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, alignment: 0.5);
      }
    });
  }

  /// Same idea, for the footer's links — no mobile menu overlay to close
  /// first since the footer is always part of the normal page flow.
  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, alignment: 0.5);
    }
  }

  void _scrollToTop() {
    _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  Future<void> _openGithub() async {
    await launchUrl(Uri.parse('https://github.com/YBGOONS/hanap-mobile'), mode: LaunchMode.externalApplication);
  }

  Future<void> _openEmail() async {
    await launchUrl(Uri(scheme: 'mailto', path: 'HANAP@gmail.com'));
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
  }

  void _openTerms() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              SliverToBoxAdapter(child: _buildHero(context)),
              SliverToBoxAdapter(child: KeyedSubtree(key: _statsKey, child: _buildStats())),
              SliverToBoxAdapter(child: _buildCategories()),
              SliverToBoxAdapter(child: KeyedSubtree(key: _featuresKey, child: _buildFeatures())),
              SliverToBoxAdapter(child: KeyedSubtree(key: _howItWorksKey, child: _buildHowItWorks())),
              SliverToBoxAdapter(child: KeyedSubtree(key: _faqKey, child: _buildFaq())),
              SliverToBoxAdapter(child: KeyedSubtree(key: _contactKey, child: _buildFooterCta(context))),
              SliverToBoxAdapter(child: _buildFooter(context)),
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
            "HANAP connects you with verified local skilled workers (carpenters, electricians, plumbers, and more) with secure escrow payments and real-time job tracking.",
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
      child: FutureBuilder<List<StatEntry>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final stats = snapshot.data ??
              const [
                StatEntry("—", "Jobs Posted", live: true),
                StatEntry("—", "Verified Workers"),
                StatEntry("—", "Satisfaction"),
                StatEntry("—", "Cities Covered"),
              ];
          return StatsGrid(stats: stats).fadeSlideIn();
        },
      ),
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
      ("⚡", "Real-Time Tracking", "From Accepted to Completed, you always know the job status."),
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

  // ── FAQ ────────────────────────────────────────────────────────────────
  Widget _buildFaq() {
    const faqs = [
      FaqEntry("Is HANAP free to use?", "Yes, creating an account and posting jobs is completely free. HANAP only charges a small 10% service fee on completed, paid jobs."),
      FaqEntry(
          "How does payment work?", "Payments go through PayMongo and are held in HANAP's escrow until you confirm the job is done. The worker only gets paid once you're satisfied."),
      FaqEntry("How are workers verified?", "Every worker submits a valid NBI Clearance, which our admin team reviews and approves before they can accept jobs."),
      FaqEntry("What if I'm not satisfied with the work?", "You can request a refund with photo evidence directly from the job details. Our admin team reviews every request."),
      FaqEntry("Can I cancel a job after posting it?", "Yes, you can edit or delete a job posting anytime before a worker accepts it."),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            label: "Support",
            headingFirstLine: "Frequently asked",
            headingGoldWord: "questions",
          ).fadeSlideIn(),
          const SizedBox(height: 24),
          for (var i = 0; i < faqs.length; i++) FaqTile(entry: faqs[i]).fadeSlideIn(delay: (i * 60).ms),
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

  // ── FOOTER ─────────────────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.hairline))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HanapWordmark(size: 22),
          const SizedBox(height: 10),
          Text("A simplified way to find and hire verified skilled workers.", style: AppText.body(size: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            children: [
              InkWell(
                onTap: _openEmail,
                child: Text("HANAP@gmail.com", style: AppText.body(size: 13, color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 14),
              InkWell(
                onTap: _openGithub,
                borderRadius: BorderRadius.circular(6),
                child: Icon(Icons.code, size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 40,
            runSpacing: 28,
            children: [
              _FooterColumn(
                title: "Product",
                links: [
                  (label: "About", onTap: _scrollToTop),
                  (label: "Demo", onTap: () => _scrollTo(_howItWorksKey)),
                ],
              ),
              _FooterColumn(
                title: "Support",
                links: [
                  (label: "FAQ", onTap: () => _scrollTo(_faqKey)),
                ],
              ),
              _FooterColumn(
                title: "Legal",
                links: [
                  (label: "Privacy Policy", onTap: _openPrivacyPolicy),
                  (label: "Terms of Service", onTap: _openTerms),
                ],
              ),
            ],
          ),
          const SizedBox(height: 36),
          Container(height: 1, color: AppColors.hairline),
          const SizedBox(height: 20),
          Text("© 2026 HANAP. All rights reserved.", style: AppText.body(size: 11.5, color: AppColors.textTertiary)),
          const SizedBox(height: 4),
          Text("A solo project made by Giovanni Lopez", style: AppText.body(size: 11.5, color: AppColors.textTertiary)),
        ],
      ),
    ).fadeSlideIn();
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<({String label, VoidCallback onTap})> links;
  const _FooterColumn({required this.title, required this.links});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          for (final link in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: link.onTap,
                child: Text(link.label, style: AppText.body(size: 13, color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
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
