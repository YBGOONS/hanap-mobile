import 'package:flutter/material.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../widgets/site/hanap_button.dart';
import 'home_screen.dart';

/// Shown to a worker after they've logged in and submitted their NBI
/// Clearance, while their account is still `status = 'pending'` in
/// `profiles` (waiting on an admin to approve them).
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  Future<void> _backToHome(BuildContext context) async {
    await supabase.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.3,
            colors: [Color(0xFF141410), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                decoration: BoxDecoration(
                  color: AppColors.surf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: AppColors.goldBg, shape: BoxShape.circle, border: Border.all(color: AppColors.goldBorder)),
                      alignment: Alignment.center,
                      child: const Text("⏳", style: TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(height: 20),
                    Text("Pending Approval", style: AppText.heading(size: 20), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(
                      "Your worker account and NBI Clearance are under review.",
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.goldBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: Text(
                        "An admin needs to approve your account before you can log in. Please check back later.",
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.gold),
                      ),
                    ),
                    const SizedBox(height: 24),
                    GoldButton(
                      label: "Back to Home",
                      onPressed: () => _backToHome(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
