import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/site/hanap_widgets.dart';

/// Reached from the landing page footer ("Legal" column) — see
/// privacy_policy_screen.dart for the sibling page and its rationale.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: BackButton(color: AppColors.gold),
        actions: const [Padding(padding: EdgeInsets.only(right: 20), child: HanapWordmark())],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Terms of Service", style: AppText.heading(size: 26)),
              const SizedBox(height: 6),
              Text("Last updated: August 2026", style: AppText.body(size: 12, color: AppColors.textTertiary)),
              const SizedBox(height: 28),
              const _TermsSection(
                title: "Acceptance of Terms",
                body: "By creating a HANAP account, you agree to these Terms of Service. If you don't agree "
                    "with any part of these terms, please don't use the platform.",
              ),
              const _TermsSection(
                title: "User Responsibilities",
                body: "Clients agree to provide accurate job details and pay for confirmed, completed work. "
                    "Workers agree to complete jobs in good faith and to provide accurate information, "
                    "including a valid NBI Clearance, during registration.",
              ),
              const _TermsSection(
                title: "Payments & Escrow",
                body: "Payments made through HANAP are held in escrow until the client confirms a job is "
                    "complete. HANAP retains a 10% service fee on released payments; the worker receives the "
                    "full posted labor fee. Refund requests are reviewed by HANAP administrators.",
              ),
              const _TermsSection(
                title: "Worker Verification",
                body: "Workers must submit a valid NBI Clearance for admin review before accepting jobs. HANAP "
                    "reserves the right to reject or suspend any worker account that fails verification.",
              ),
              const _TermsSection(
                title: "Prohibited Conduct",
                body: "Users may not post fraudulent jobs, misrepresent their identity or qualifications, or "
                    "attempt to bypass HANAP's escrow system to arrange payment outside the platform.",
              ),
              const _TermsSection(
                title: "Limitation of Liability",
                body: "HANAP facilitates connections between clients and workers but is not a party to the "
                    "service performed. HANAP is not liable for the quality of work performed by a worker, "
                    "beyond the escrow and refund protections described in these terms.",
              ),
              const _TermsSection(
                title: "Changes to These Terms",
                body: "We may update these terms as HANAP evolves. Continued use of the platform after a "
                    "change means you accept the updated terms.",
              ),
              const _TermsSection(
                title: "Contact Us",
                body: "Questions about these terms? Reach us at HANAP@gmail.com.",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String body;
  const _TermsSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.heading(size: 16, color: AppColors.gold)),
          const SizedBox(height: 8),
          Text(body, style: AppText.body(size: 13.5, color: AppColors.textSecondary).copyWith(height: 1.6)),
        ],
      ),
    );
  }
}
