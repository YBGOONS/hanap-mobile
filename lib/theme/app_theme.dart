import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// HANAP brand system — dark base + gold accent, minimal palette.
/// Ported from the web design spec: black bg, gold primary, Syne/Inter type.
class AppColors {
  AppColors._();

  static const gold = Color(0xFFF5A623);
  static const goldLight = Color(0xFFFFBD47); // hover/press state
  static const bg = Color(0xFF050505); // base background
  static const surf = Color(0xFF080808); // surface 1
  static const surf2 = Color(0xFF060606); // surface 2
  static const live = Color(0xFF4ADE80); // success / live indicator
  static const error = Color(0xFFEF4444);

  static final Color textPrimary = Colors.white.withValues(alpha: 0.88);
  static final Color textSecondary = Colors.white.withValues(alpha: 0.5);
  static final Color textTertiary = Colors.white.withValues(alpha: 0.4);
  static final Color hairline = Colors.white.withValues(alpha: 0.08);
  static final Color borderSubtle = Colors.white.withValues(alpha: 0.18);
  static final Color cardBg = Colors.white.withValues(alpha: 0.02);
  static final Color goldBg = AppColors.gold.withValues(alpha: 0.07);
  static final Color goldBorder = AppColors.gold.withValues(alpha: 0.35);
}

/// Headings use "Syne" (bold, tight tracking); body copy uses "Inter".
class AppText {
  AppText._();

  static TextStyle heading({
    double size = 28,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double letterSpacing = -0.5,
    double? height,
  }) =>
      GoogleFonts.syne(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.textSecondary,
        height: height,
      );

  /// Small uppercase gold label, wide letter-spacing — used above section headings.
  static TextStyle label({double size = 12, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.gold,
        letterSpacing: 2.2,
      );
}

InputDecoration hanapInputDecoration({
  required String label,
  String? hint,
  bool hasError = false,
  Widget? suffixIcon,
}) {
  final radius = BorderRadius.circular(10);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffixIcon,
    labelStyle: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary),
    hintStyle: AppText.body(size: 14, color: AppColors.textTertiary),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AppColors.hairline)),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: hasError ? AppColors.error : AppColors.hairline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: hasError ? AppColors.error : AppColors.gold, width: 1.5),
    ),
  );
}

ThemeData buildHanapTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: AppColors.gold,
      secondary: AppColors.gold,
      surface: AppColors.surf,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
