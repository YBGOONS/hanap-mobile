import 'package:flutter/material.dart';
import '../../theme/dashboard_theme.dart';

/// Fixed-look gradient header used at the top of every dashboard —
/// navy → #0a2d6b, rounded 14, matches the React DashboardShell header.
class DashboardHeaderCard extends StatelessWidget {
  final String title;
  final String greetingName;
  final String subtitle;
  final Widget? action;

  const DashboardHeaderCard({
    super.key,
    required this.title,
    required this.greetingName,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DashboardColors.primary, DashboardColors.primaryGradientEnd],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DashboardText.body(size: 13, weight: FontWeight.w600, color: Colors.white70)),
                const SizedBox(height: 6),
                Text("Welcome back, $greetingName!", style: DashboardText.heading(size: 20, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, style: DashboardText.body(size: 13, color: Colors.white70)),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// White stat card with a left accent border — Active / Completed / Open.
class DashboardStatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color accentColor;
  final IconData? icon;

  const DashboardStatCard({super.key, required this.value, required this.label, required this.accentColor, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: accentColor),
            const SizedBox(height: 10),
          ],
          Text(value, style: DashboardText.heading(size: 26, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: DashboardText.body(size: 11, weight: FontWeight.w700, color: DashboardColors.muted).copyWith(letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

/// Maps a public.jobs `status` value to a display label + color, shared by
/// every dashboard's job lists.
({String label, Color color}) dashboardStatusStyle(String status) {
  switch (status) {
    case 'open':
      return (label: 'Open', color: DashboardColors.statOpen);
    case 'accepted':
      return (label: 'Accepted', color: DashboardColors.accent);
    case 'arrived':
      return (label: 'Arrived', color: DashboardColors.statusArrived);
    case 'in_progress':
      return (label: 'In Progress', color: DashboardColors.statusInProgress);
    case 'completed':
      return (label: 'Completed', color: DashboardColors.statusCompleted);
    case 'cancelled':
      return (label: 'Cancelled', color: DashboardColors.statusCancelled);
    default:
      return (label: status, color: DashboardColors.muted);
  }
}

class DashboardStatusBadge extends StatelessWidget {
  final String status;
  const DashboardStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = dashboardStatusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        style.label.toUpperCase(),
        style: DashboardText.body(size: 10, weight: FontWeight.w700, color: style.color).copyWith(letterSpacing: 0.4),
      ),
    );
  }
}

/// Shared loading/error placeholder for any dashboard tab's data fetch —
/// reused across Client/Worker/Admin as each gets wired to real Supabase data.
class DashboardStateMessage extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? action;
  const DashboardStateMessage({super.key, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: DashboardText.heading(size: 15, color: Colors.black87), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: DashboardText.body(size: 12, color: DashboardColors.muted), textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Compact row for the "Recent Jobs" list — title/location left, status right.
class RecentJobListItem extends StatelessWidget {
  final String title;
  final String location;
  final String status;

  const RecentJobListItem({super.key, required this.title, required this.location, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DashboardColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DashboardText.heading(size: 14, weight: FontWeight.w700, color: Colors.black87)),
                const SizedBox(height: 3),
                Text(location, style: DashboardText.body(size: 12, color: DashboardColors.muted)),
              ],
            ),
          ),
          DashboardStatusBadge(status: status),
        ],
      ),
    );
  }
}

/// Generic "not built yet" placeholder for a dashboard bottom-nav tab.
class DashboardComingSoonTab extends StatelessWidget {
  final String label;
  const DashboardComingSoonTab({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("$label — coming soon", style: DashboardText.body(size: 14, color: DashboardColors.muted)),
    );
  }
}

/// Prompts for a short reason via a dialog — the Flutter equivalent of the
/// React source's `window.prompt()` (used e.g. for "Can't do this job").
/// Returns the trimmed text, or null if cancelled/dismissed.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  String? hint,
  String confirmLabel = "Submit",
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          final canSubmit = controller.text.trim().isNotEmpty;
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(title, style: DashboardText.heading(size: 17, color: Colors.black87)),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              style: DashboardText.body(size: 14, color: Colors.black87),
              decoration: dashboardInputDecoration(label: "Reason", hint: hint),
              onChanged: (_) => setState(() {}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text("Cancel", style: DashboardText.body(size: 14, weight: FontWeight.w600, color: DashboardColors.muted)),
              ),
              ElevatedButton(
                onPressed: canSubmit ? () => Navigator.of(dialogContext).pop(controller.text.trim()) : null,
                style: ElevatedButton.styleFrom(backgroundColor: DashboardColors.accent, foregroundColor: Colors.white),
                child: Text(confirmLabel, style: DashboardText.body(size: 14, weight: FontWeight.w700)),
              ),
            ],
          );
        },
      );
    },
  );
}
