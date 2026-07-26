import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Primary CTA — solid gold, black text, bold Syne label.
/// Presses scale down slightly and lighten (goldLight) instead of a web hover.
class GoldButton extends StatefulWidget {
  final String label;
  final String loadingLabel;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;

  const GoldButton({
    super.key,
    required this.label,
    this.loadingLabel = "Please wait...",
    this.loading = false,
    this.icon,
    required this.onPressed,
  });

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _pressed = false;

  bool get _enabled => !widget.loading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      onTap: _enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: !_enabled
                ? AppColors.gold.withValues(alpha: 0.35)
                : (_pressed ? AppColors.goldLight : AppColors.gold),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _enabled && !_pressed
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: widget.loading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    ),
                    const SizedBox(width: 10),
                    Text(widget.loadingLabel, style: AppText.heading(size: 15, color: Colors.black)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 16, color: Colors.black),
                      const SizedBox(width: 8),
                    ],
                    Text(widget.label, style: AppText.heading(size: 15, color: Colors.black)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary CTA — transparent, thin border. Press → border/text goes gold.
class HanapOutlineButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const HanapOutlineButton({super.key, required this.label, required this.onPressed, this.icon});

  @override
  State<HanapOutlineButton> createState() => _HanapOutlineButtonState();
}

class _HanapOutlineButtonState extends State<HanapOutlineButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _pressed && widget.onPressed != null;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.gold : AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 16, color: active ? AppColors.gold : AppColors.textPrimary),
              const SizedBox(width: 8),
            ],
            Text(widget.label, style: AppText.heading(size: 14, color: active ? AppColors.gold : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// Inline error banner — dark translucent red, replaces the old light-theme version.
class HanapErrorBanner extends StatelessWidget {
  final String message;
  const HanapErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.error),
      ),
    );
  }
}
