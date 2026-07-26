import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../models/categories.dart';
import '../../theme/app_theme.dart';
import '../../widgets/site/hanap_button.dart';
import '../../widgets/site/hanap_dialog.dart';
import 'nbi_upload_screen.dart';

/// Ported from src/views/pages/Register.js — shown as a popup (see
/// showHanapDialog in home_screen.dart), not a full-screen page.
///
/// Email confirmation is required on this Supabase project, so there's no
/// active session right after signUp() — that means we can't upload the
/// worker's NBI Clearance yet (storage policies require auth.uid()). That
/// step happens in NbiUploadScreen, right after their first successful
/// login. This screen's job is just: create the account, then tell them
/// to go check their email.
class RegisterScreen extends StatefulWidget {
  final VoidCallback onSwitchToLogin;
  const RegisterScreen({super.key, required this.onSwitchToLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

enum _Role { client, worker }

class _RegisterScreenState extends State<RegisterScreen> {
  _Role _role = _Role.client;
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _skill = kCategories.first;
  String? _error;
  bool _loading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _locationCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  ({String label, Color color, double pct})? get _passwordStrength {
    final pw = _passCtrl.text;
    if (pw.isEmpty) return null;
    int score = 0;
    if (pw.length >= 8) score++;
    if (pw.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
    if (RegExp(r'[0-9]').hasMatch(pw)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) score++;
    if (score <= 1) return (label: "Weak", color: const Color(0xFFEF4444), pct: 0.25);
    if (score == 2) return (label: "Fair", color: const Color(0xFFF97316), pct: 0.50);
    if (score == 3) return (label: "Strong", color: const Color(0xFFEAB308), pct: 0.75);
    return (label: "Very Strong", color: AppColors.live, pct: 1.0);
  }

  Future<void> _handleSubmit() async {
    if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      setState(() => _error = "First and last name are required.");
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = "Email is required.");
      return;
    }
    if (_locationCtrl.text.trim().isEmpty) {
      setState(() => _error = "Location is required.");
      return;
    }
    if (_passCtrl.text.trim().length < 6) {
      setState(() => _error = "Password must be at least 6 characters.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        data: {
          'role': _role == _Role.worker ? 'worker' : 'client',
          'first_name': _firstNameCtrl.text.trim(),
          'last_name': _lastNameCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
          if (_role == _Role.worker) 'skills': [_skill],
        },
      );

      if (!mounted) return;

      // If email confirmation is OFF in the Supabase project, signUp already
      // returns an active session — no need to wait for a confirmation link.
      if (res.session != null) {
        setState(() => _loading = false);
        if (_role == _Role.worker) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => NbiUploadScreen(userId: res.user!.id)),
          );
        } else {
          Navigator.of(context).pop();
        }
        return;
      }

      setState(() {
        _loading = false;
        _emailSent = true;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Something went wrong. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_emailSent) return _buildEmailSent();

    final isWorker = _role == _Role.worker;

    return HanapDialogCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Create an account", style: AppText.heading(size: 24)),
          const SizedBox(height: 6),
          Text(
            "Join HANAP as a client or skilled worker",
            style: AppText.body(size: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),

          // Role toggle — Client / Worker
          Row(
            children: [
              Expanded(child: _roleButton(_Role.client, "Client", Icons.person)),
              const SizedBox(width: 10),
              Expanded(child: _roleButton(_Role.worker, "Worker", Icons.build)),
            ],
          ),
          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _firstNameCtrl,
                  style: AppText.body(size: 14, color: AppColors.textPrimary),
                  onChanged: (_) => setState(() => _error = null),
                  decoration: hanapInputDecoration(label: "First Name", hint: "Juan"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _lastNameCtrl,
                  style: AppText.body(size: 14, color: AppColors.textPrimary),
                  onChanged: (_) => setState(() => _error = null),
                  decoration: hanapInputDecoration(label: "Last Name", hint: "dela Cruz"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _emailCtrl,
            style: AppText.body(size: 14, color: AppColors.textPrimary),
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() => _error = null),
            decoration: hanapInputDecoration(label: "Email", hint: "you@email.com"),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _locationCtrl,
            style: AppText.body(size: 14, color: AppColors.textPrimary),
            onChanged: (_) => setState(() => _error = null),
            decoration: hanapInputDecoration(label: "Location", hint: "City, Province"),
          ),
          const SizedBox(height: 14),

          if (isWorker) ...[
            DropdownButtonFormField<String>(
              initialValue: _skill,
              isExpanded: true,
              dropdownColor: AppColors.surf2,
              style: AppText.body(size: 14, color: AppColors.textPrimary),
              decoration: hanapInputDecoration(label: "Primary Skill"),
              items: kCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppText.body(size: 14, color: AppColors.textPrimary))))
                  .toList(),
              onChanged: (v) => setState(() => _skill = v ?? _skill),
            ),
            const SizedBox(height: 14),
          ],

          TextField(
            controller: _passCtrl,
            style: AppText.body(size: 14, color: AppColors.textPrimary),
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: hanapInputDecoration(label: "Password", hint: "••••••••"),
          ),
          if (_passwordStrength != null) ...[
            const SizedBox(height: 8),
            Row(
              children: List.generate(4, (i) {
                final s = _passwordStrength!;
                final filled = s.pct >= (i + 1) * 0.25;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: filled ? s.color : AppColors.hairline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 5),
            Text(
              _passwordStrength!.label,
              style: AppText.body(size: 11, weight: FontWeight.w700, color: _passwordStrength!.color),
            ),
          ],
          const SizedBox(height: 14),

          if (isWorker) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.goldBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Text(
                "After you confirm your email and log in, we'll ask you to upload your NBI Clearance before an admin reviews your account.",
                style: AppText.body(size: 12, color: AppColors.gold).copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (_error != null) HanapErrorBanner(message: _error!),

          GoldButton(
            label: "Create Account",
            loadingLabel: "Creating account...",
            loading: _loading,
            onPressed: _handleSubmit,
          ),
          const SizedBox(height: 16),

          Center(
            child: RichText(
              text: TextSpan(
                style: AppText.body(size: 13, color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: "Already have an account? "),
                  TextSpan(
                    text: "Log in here",
                    style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.gold),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.of(context).pop();
                        widget.onSwitchToLogin();
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

  Widget _roleButton(_Role role, String label, IconData icon) {
    final selected = _role == role;
    return OutlinedButton.icon(
      onPressed: () => setState(() {
        _role = role;
        _error = null;
      }),
      icon: Icon(icon, size: 16, color: selected ? Colors.black : AppColors.textPrimary),
      label: Text(
        label,
        style: AppText.heading(size: 13, color: selected ? Colors.black : AppColors.textPrimary),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.gold : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: BorderSide(color: selected ? AppColors.gold : AppColors.hairline, width: selected ? 0 : 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildEmailSent() {
    return HanapDialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.goldBg, shape: BoxShape.circle, border: Border.all(color: AppColors.goldBorder)),
            alignment: Alignment.center,
            child: const Text("📧", style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 20),
          Text("Check your email", style: AppText.heading(size: 20), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            "We sent a confirmation link to ${_emailCtrl.text.trim()}. Click it, then come back and log in.",
            textAlign: TextAlign.center,
            style: AppText.body(size: 14, color: AppColors.textSecondary).copyWith(height: 1.5),
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
