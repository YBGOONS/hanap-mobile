import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../widgets/site/hanap_button.dart';
import '../../widgets/site/hanap_dialog.dart';

enum _Step { email, reset, done }

/// Forgot-password flow, shown as a popup like Login/Register.
///
/// Step 1: enter the account email, `resetPasswordForEmail` sends a
/// 6-digit code (Supabase's "Reset Password" email template needs to
/// include `{{ .Token }}` for that code to actually be in the email — the
/// default template only shows a magic link).
/// Step 2: enter that code + a new password. `verifyOTP(type: recovery)`
/// exchanges the code for a real (temporary) session, which is what lets
/// `updateUser` actually change the password — then signs back out so they
/// log in fresh with the new one, same as a normal login.
class ForgotPasswordScreen extends StatefulWidget {
  final VoidCallback onSwitchToLogin;
  const ForgotPasswordScreen({super.key, required this.onSwitchToLogin});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _Step _step = _Step.email;
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  bool _showPass = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = "Email is required.");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await supabase.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _Step.reset;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't send the code right now. Please try again.";
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() => _resending = true);
    try {
      await supabase.auth.resetPasswordForEmail(_emailCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Code sent again. Check your inbox.")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't resend right now. Please try again shortly."),
        ),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _resetPassword() async {
    final otp = _otpCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (otp.isEmpty) {
      setState(() => _error = "Enter the code from your email.");
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = "Password must be at least 6 characters.");
      return;
    }
    if (pass != confirm) {
      setState(() => _error = "Passwords don't match.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await supabase.auth.verifyOTP(
        type: OtpType.recovery,
        email: _emailCtrl.text.trim(),
        token: otp,
      );
      await supabase.auth.updateUser(UserAttributes(password: pass));
      await supabase.auth.signOut();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _Step.done;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message.toLowerCase().contains('token')
            ? "That code is invalid or expired. Request a new one."
            : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Something went wrong. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.email => _buildEmailStep(),
      _Step.reset => _buildResetStep(),
      _Step.done => _buildDone(),
    };
  }

  Widget _buildEmailStep() {
    return HanapDialogCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Forgot password?", style: AppText.heading(size: 22)),
          const SizedBox(height: 6),
          Text(
            "Enter your account email — we'll send a code to reset your password.",
            style: AppText.body(
              size: 14,
              color: AppColors.textSecondary,
            ).copyWith(height: 1.5),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _emailCtrl,
            style: AppText.body(size: 14, color: AppColors.textPrimary),
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _sendCode(),
            decoration: hanapInputDecoration(
              label: "Email",
              hint: "you@email.com",
            ),
          ),
          const SizedBox(height: 18),
          if (_error != null) HanapErrorBanner(message: _error!),
          GoldButton(
            label: "Send Code",
            loadingLabel: "Sending...",
            loading: _loading,
            onPressed: _sendCode,
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onSwitchToLogin();
              },
              child: Text(
                "Back to Login",
                style: AppText.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep() {
    return HanapDialogCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Enter the code", style: AppText.heading(size: 22)),
          const SizedBox(height: 6),
          Text(
            "We sent a 6-digit code to ${_emailCtrl.text.trim()}. Enter it below with your new password.",
            style: AppText.body(
              size: 14,
              color: AppColors.textSecondary,
            ).copyWith(height: 1.5),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _otpCtrl,
            style: AppText.body(
              size: 20,
              color: AppColors.textPrimary,
            ).copyWith(letterSpacing: 4),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            // Supabase's OTP length is a project-level setting, not
            // guaranteed to be 6 — was hardcoded at 6 before, which
            // silently truncated a longer code and made it impossible to
            // ever enter the real one.
            maxLength: 12,
            onChanged: (_) => setState(() => _error = null),
            decoration: hanapInputDecoration(
              label: "Code",
              hint: "Enter the code from your email",
            ).copyWith(counterText: ""),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passCtrl,
            style: AppText.body(size: 14, color: AppColors.textPrimary),
            obscureText: !_showPass,
            onChanged: (_) => setState(() => _error = null),
            decoration: hanapInputDecoration(
              label: "New Password",
              hint: "••••••••",
              suffixIcon: IconButton(
                icon: Icon(
                  _showPass ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirmCtrl,
            style: AppText.body(size: 14, color: AppColors.textPrimary),
            obscureText: !_showConfirm,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _resetPassword(),
            decoration: hanapInputDecoration(
              label: "Confirm New Password",
              hint: "••••••••",
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirm ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _resending ? null : _resendCode,
              child: Text(
                _resending ? "Sending..." : "Resend code",
                style: AppText.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null) HanapErrorBanner(message: _error!),
          GoldButton(
            label: "Reset Password",
            loadingLabel: "Resetting...",
            loading: _loading,
            onPressed: _resetPassword,
          ),
        ],
      ),
    );
  }

  Widget _buildDone() {
    return HanapDialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.goldBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldBorder),
            ),
            alignment: Alignment.center,
            child: const Text("🔑", style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 20),
          Text(
            "Password reset!",
            style: AppText.heading(size: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            "You can now log in with your new password.",
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 14,
              color: AppColors.textSecondary,
            ).copyWith(height: 1.5),
          ),
          const SizedBox(height: 24),
          GoldButton(
            label: "Back to Login",
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSwitchToLogin();
            },
          ),
        ],
      ),
    );
  }
}
