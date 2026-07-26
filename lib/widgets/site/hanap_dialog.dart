import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Opens [builder]'s content as a centered modal card over a dimmed
/// backdrop — used for Login/Register instead of full-screen pages.
Future<T?> showHanapDialog<T>(BuildContext context, WidgetBuilder builder) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: builder(dialogContext),
      ),
    ),
  );
}

/// Shared card chrome for dialog content (Login/Register) — dark surface,
/// hairline border, and a small close (X) so tap-outside isn't the only
/// way to dismiss it.
class HanapDialogCard extends StatelessWidget {
  final Widget child;
  const HanapDialogCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 12, 20, 28),
        decoration: BoxDecoration(
          color: AppColors.surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
