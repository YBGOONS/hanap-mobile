import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standard palette for all authenticated dashboards (Client, Worker,
/// Admin) — this is the HANAP React app's real design language, kept
/// separate from app_theme.dart's dark/gold public-site palette until
/// those get a dedicated re-theme pass.
class DashboardColors {
  DashboardColors._();

  static const primary = Color(0xFF001A4D);
  static const primaryGradientEnd = Color(0xFF0A2D6B);
  static const accent = Color(0xFFFF6B35);
  static const bg = Color(0xFFF8F9FA);
  static const border = Color(0xFFE0E0E0);
  static const muted = Color(0xFF6B7280);

  static const statActive = accent;
  static const statCompleted = primary;
  static const statOpen = Color(0xFF1565C0);

  static const statusPending = Color(0xFFF59E0B);
  static const statusArrived = Color(0xFF7C3AED);
  static const statusInProgress = Color(0xFF1565C0);
  static const statusCompleted = Color(0xFF2E7D32);
  static const statusCancelled = Color(0xFF9CA3AF);
}

class DashboardText {
  DashboardText._();

  static TextStyle heading({
    double size = 20,
    FontWeight weight = FontWeight.w800,
    Color color = Colors.black87,
  }) =>
      GoogleFonts.syne(fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.3);

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.black87,
  }) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);
}

/// Light-themed input decoration for dashboard forms (Admin login, etc.) —
/// the DashboardColors equivalent of app_theme.dart's hanapInputDecoration.
InputDecoration dashboardInputDecoration({
  required String label,
  String? hint,
  bool hasError = false,
  Widget? suffixIcon,
}) {
  final radius = BorderRadius.circular(8);
  const errorColor = Color(0xFFC62828);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffixIcon,
    labelStyle: DashboardText.body(size: 13, weight: FontWeight.w600, color: DashboardColors.muted),
    hintStyle: DashboardText.body(size: 14, color: DashboardColors.muted),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: DashboardColors.border)),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: hasError ? errorColor : DashboardColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: hasError ? errorColor : DashboardColors.accent, width: 1.5),
    ),
  );
}
