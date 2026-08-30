import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../widgets/site/hanap_button.dart';
import '../../widgets/site/hanap_dialog.dart';
import '../admin/admin_dashboard_screen.dart';
import '../client/client_dashboard_screen.dart';
import 'nbi_upload_screen.dart';
import 'pending_approval_screen.dart';
import '../worker/worker_dashboard_screen.dart';

/// Ported from src/views/pages/Login.js — shown as a popup (see
/// showHanapDialog in home_screen.dart), not a full-screen page.
///
/// After signInWithPassword, routing depends on the matching `profiles`
/// row (see supabase/schema.sql):
///   - worker, no nbi_clearance_path yet → NbiUploadScreen
///   - worker, status == 'pending'       → PendingApprovalScreen
///   - status == 'rejected'              → sign back out, show message
///   - role == 'admin', not on web       → sign back out, ask them to use a browser
///   - otherwise (active client/worker/admin-on-web) → the matching dashboard
class LoginScreen extends StatefulWidget {
  final VoidCallback onSwitchToRegister;
  final VoidCallback onForgotPassword;
  const LoginScreen({
    super.key,
    required this.onSwitchToRegister,
    required this.onForgotPassword,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  bool _loading = false;
  bool _resending = false;
  String? _error;
  bool _showResend = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (identifier.isEmpty && pass.isEmpty) {
      setState(
        () => _error = "Please fill in your email/username and password.",
      );
      return;
    }
    if (identifier.isEmpty) {
      setState(() => _error = "Email or username is required.");
      return;
    }
    if (pass.isEmpty) {
      setState(() => _error = "Password is required.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _showResend = false;
    });

    try {
      // Not an email → treat it as a username and resolve the real email
      // first (signInWithPassword only takes an email). Same generic
      // "Login failed" message either way below so a wrong username can't
      // be used to probe which ones exist.
      var email = identifier;
      if (!identifier.contains('@')) {
        final resolved = await supabase.rpc(
          'email_for_username',
          params: {'p_username': identifier},
        );
        if (resolved == null || (resolved as String).isEmpty) {
          throw const AuthException('Invalid login credentials');
        }
        email = resolved;
      }

      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: pass,
      );
      final userId = res.user?.id;
      if (userId == null) throw const AuthException('Login failed.');

      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      final role = profile['role'] as String;
      final status = profile['status'] as String;
      final nbiPath = profile['nbi_clearance_path'] as String?;

      if (!mounted) return;

      if (role == 'worker' && nbiPath == null) {
        setState(() => _loading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => NbiUploadScreen(userId: userId)),
        );
        return;
      }

      if (role == 'worker' && status == 'pending') {
        setState(() => _loading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
        );
        return;
      }

      if (status == 'rejected') {
        await supabase.auth.signOut();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error =
              "Your account application wasn't approved. Contact support for details.";
        });
        return;
      }

      if (role == 'admin' && !kIsWeb) {
        // Admin's sidebar layout only makes sense on a wide/web viewport —
        // see supabase/schema.sql for why the 'admin' role can't be
        // self-granted through the app either way.
        await supabase.auth.signOut();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = "Admin accounts require the web version of the app.";
        });
        return;
      }

      setState(() => _loading = false);
      if (!mounted) return;

      final dashboard = switch (role) {
        'admin' => const AdminDashboardScreen(),
        'worker' => const WorkerDashboardScreen(),
        _ => const ClientDashboardScreen(),
      };
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => dashboard),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final unconfirmed = e.message.toLowerCase().contains('confirm');
      setState(() {
        _loading = false;
        _error = unconfirmed
            ? "Please confirm your email before logging in. Check your inbox for the link."
            : e.message;
        _showResend = unconfirmed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Login failed. Please check your credentials.";
      });
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _resending = true);
    try {
      await supabase.auth.resend(type: OtpType.signup, email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Confirmation email sent again. Check your inbox."),
        ),
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

  @override
  Widget build(BuildContext context) {
    final hasEmailError = _error != null && _emailCtrl.text.trim().isEmpty;
    final hasPassError = _error != null && _passCtrl.text.trim().isEmpty;

    return HanapDialogCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: AppText.heading(size: 22),
              children: const [
                TextSpan(text: "han"),
                TextSpan(
                  text: "ap",
                  style: TextStyle(color: AppColors.gold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text("Welcome back", style: AppText.heading(size: 24)),
          const SizedBox(height: 6),
          Text(
            "Sign in to your account and continue working",
            style: AppText.body(size: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 26),

          TextField(
            controller: _emailCtrl,
            style: AppText.body(size: 14, color: AppColors.textPrimary),
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {
              _error = null;
              _showResend = false;
            }),
            decoration: hanapInputDecoration(
              label: "Email or Username",
              hint: "you@email.com or username",
              hasError: hasEmailError,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _passCtrl,
            style: AppText.body(size: 14, color: AppColors.textPrimary),
            obscureText: !_showPass,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _handleLogin(),
            decoration: hanapInputDecoration(
              label: "Password",
              hint: "••••••••",
              hasError: hasPassError,
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
          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onForgotPassword();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                "Forgot password?",
                style: AppText.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          if (_error != null) HanapErrorBanner(message: _error!),
          if (_showResend) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _resending ? null : _resendConfirmation,
                child: Text(
                  _resending ? "Sending..." : "Resend confirmation email",
                  style: AppText.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          GoldButton(
            label: "Login",
            loadingLabel: "Logging in...",
            loading: _loading,
            onPressed: _handleLogin,
          ),
          const SizedBox(height: 18),

          Center(
            child: RichText(
              text: TextSpan(
                style: AppText.body(size: 13, color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: "Don't have an account? "),
                  TextSpan(
                    text: "Sign up here",
                    style: AppText.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.of(context).pop();
                        widget.onSwitchToRegister();
                      },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
