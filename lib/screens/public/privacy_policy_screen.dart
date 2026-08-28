import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/site/hanap_widgets.dart';

/// Reached from the landing page footer ("Legal" column). Static content —
/// no backend involved — kept in its own screen (rather than a scroll
/// section like FAQ) since it's long-form reading, not something a visitor
/// browsing the landing page would want inline.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
              Text("Privacy Policy", style: AppText.heading(size: 26)),
              const SizedBox(height: 6),
              Text("Last updated: August 2026", style: AppText.body(size: 12, color: AppColors.textTertiary)),
              const SizedBox(height: 28),
              const _PolicySection(
                title: "Information We Collect",
                body: "When you create a HANAP account, we collect your name, email address, phone number, "
                    "location, and (for workers) your NBI Clearance and skill category. This information is "
                    "used to verify identities and connect clients with the right workers.",
              ),
              const _PolicySection(
                title: "How We Use Your Information",
                body: "Your information is used to operate the platform: matching jobs, processing escrow "
                    "payments, sending notifications, and verifying worker credentials before approval. We do "
                    "not sell your personal information to third parties.",
              ),
              const _PolicySection(
                title: "Payments",
                body: "Payments are processed through PayMongo. HANAP does not store your card, GCash, or "
                    "banking credentials directly; that information is handled entirely by PayMongo's secure "
                    "payment infrastructure.",
              ),
              const _PolicySection(
                title: "Data Security",
                body: "Your data is stored with Supabase and protected with row-level security policies, "
                    "meaning each account can only access the data it's actually authorized to see.",
              ),
              const _PolicySection(
                title: "Your Rights",
                body: "You can update your profile information (including your phone number) at any time from "
                    "your account settings. To request account deletion, contact us using the details below.",
              ),
              const _PolicySection(
                title: "Contact Us",
                body: "Questions about this policy? Reach us at HANAP@gmail.com.",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;
  const _PolicySection({required this.title, required this.body});

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
