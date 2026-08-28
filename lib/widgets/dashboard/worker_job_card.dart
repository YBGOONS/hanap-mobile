import 'package:flutter/material.dart';
import '../../theme/dashboard_theme.dart';
import 'job_step_progress.dart';

String _formatDate(DateTime d) =>
    "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: DashboardColors.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: DashboardText.body(size: 12, color: DashboardColors.muted),
        ),
      ],
    );
  }
}

/// A job in the "Available Jobs" list — white card, urgency pill when the
/// scheduled date is close, an `actions` slot for the Accept button.
class WorkerAvailableJobCard extends StatelessWidget {
  final String title;
  final String description;
  final double? budget;
  final String location;
  final String? clientName;
  final DateTime? scheduledDate;
  final Widget? actions;
  final VoidCallback? onTap;

  const WorkerAvailableJobCard({
    super.key,
    required this.title,
    required this.description,
    this.budget,
    required this.location,
    this.clientName,
    this.scheduledDate,
    this.actions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent =
        scheduledDate != null &&
        scheduledDate!.difference(DateTime.now()).inDays <= 2;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUrgent
                ? DashboardColors.accent.withValues(alpha: 0.4)
                : DashboardColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: DashboardText.heading(
                      size: 15,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (budget != null)
                  Text(
                    "₱${budget!.toStringAsFixed(0)}",
                    style: DashboardText.heading(
                      size: 16,
                      color: DashboardColors.accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DashboardText.body(
                size: 12.5,
                color: DashboardColors.muted,
              ).copyWith(height: 1.4),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _MetaRow(icon: Icons.location_on_outlined, text: location),
                if (clientName != null)
                  _MetaRow(icon: Icons.person_outline, text: clientName!),
                if (scheduledDate != null)
                  _MetaRow(
                    icon: Icons.event_outlined,
                    text: isUrgent
                        ? "${_formatDate(scheduledDate!)} · urgent"
                        : _formatDate(scheduledDate!),
                  ),
              ],
            ),
            if (actions != null) ...[const SizedBox(height: 12), actions!],
          ],
        ),
      ),
    );
  }
}

/// A job in "My Jobs" — same card shell, embeds the 4-step lifecycle
/// tracker and an `actions` slot for status-dependent buttons/messages.
class WorkerMyJobCard extends StatelessWidget {
  final String title;
  final double? budget;
  final String location;
  final String? clientName;
  final String status;
  final int? rating;
  final Widget? actions;
  final VoidCallback? onTap;

  const WorkerMyJobCard({
    super.key,
    required this.title,
    this.budget,
    required this.location,
    this.clientName,
    required this.status,
    this.rating,
    this.actions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DashboardColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: DashboardText.heading(
                      size: 15,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (budget != null)
                  Text(
                    "₱${budget!.toStringAsFixed(0)}",
                    style: DashboardText.heading(
                      size: 16,
                      color: DashboardColors.accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _MetaRow(icon: Icons.location_on_outlined, text: location),
                if (clientName != null)
                  _MetaRow(icon: Icons.person_outline, text: clientName!),
                if (rating != null)
                  _MetaRow(icon: Icons.star, text: "$rating/5"),
              ],
            ),
            const SizedBox(height: 14),
            JobStepProgress(status: status),
            if (actions != null) ...[const SizedBox(height: 14), actions!],
          ],
        ),
      ),
    );
  }
}
