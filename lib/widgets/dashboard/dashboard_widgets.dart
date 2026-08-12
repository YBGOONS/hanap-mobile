import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../theme/dashboard_theme.dart';
import '../../utils/formatters.dart';

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

/// Star-rating + comment picker shown when a client rates a completed job's
/// worker. Only collects the input — the caller is responsible for calling
/// the `rate_job` RPC and refreshing, same division of labor as
/// [showReasonDialog].
Future<({int rating, String comment})?> showRatingDialog(
  BuildContext context, {
  String title = "Rate this worker",
}) {
  var selected = 5;
  final controller = TextEditingController();
  return showDialog<({int rating, String comment})>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(title, style: DashboardText.heading(size: 17, color: Colors.black87)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return IconButton(
                      onPressed: () => setState(() => selected = star),
                      icon: Icon(
                        star <= selected ? Icons.star : Icons.star_border,
                        color: DashboardColors.accent,
                        size: 30,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  style: DashboardText.body(size: 14, color: Colors.black87),
                  decoration: dashboardInputDecoration(label: "Comment (optional)"),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text("Cancel", style: DashboardText.body(size: 14, weight: FontWeight.w600, color: DashboardColors.muted)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop((rating: selected, comment: controller.text.trim())),
                style: ElevatedButton.styleFrom(backgroundColor: DashboardColors.accent, foregroundColor: Colors.white),
                child: Text("Submit", style: DashboardText.body(size: 14, weight: FontWeight.w700)),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Reason + required photo evidence for a refund request. Only collects the
/// input (same division of labor as [showReasonDialog]/[showRatingDialog])
/// — the caller uploads the file to the refund-evidence bucket and calls
/// request_refund with the resulting path.
Future<({String reason, PlatformFile file})?> showRefundRequestDialog(BuildContext context) {
  final controller = TextEditingController();
  PlatformFile? file;
  return showDialog<({String reason, PlatformFile file})>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          final canSubmit = controller.text.trim().isNotEmpty && file != null;
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text("Request a refund", style: DashboardText.heading(size: 17, color: Colors.black87)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 3,
                  style: DashboardText.body(size: 14, color: Colors.black87),
                  decoration: dashboardInputDecoration(label: "Reason", hint: "Why are you requesting a refund?"),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png'],
                      withData: true,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      setState(() => file = result.files.first);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: file != null ? DashboardColors.accent.withValues(alpha: 0.08) : DashboardColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: file != null ? DashboardColors.accent : DashboardColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          file != null ? Icons.check_circle : Icons.camera_alt_outlined,
                          size: 18,
                          color: file != null ? DashboardColors.accent : DashboardColors.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            file?.name ?? "Attach photo evidence (required)",
                            overflow: TextOverflow.ellipsis,
                            style: DashboardText.body(
                              size: 13,
                              weight: file != null ? FontWeight.w600 : FontWeight.w400,
                              color: file != null ? Colors.black87 : DashboardColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text("Cancel", style: DashboardText.body(size: 14, weight: FontWeight.w600, color: DashboardColors.muted)),
              ),
              ElevatedButton(
                onPressed: canSubmit ? () => Navigator.of(dialogContext).pop((reason: controller.text.trim(), file: file!)) : null,
                style: ElevatedButton.styleFrom(backgroundColor: DashboardColors.accent, foregroundColor: Colors.white),
                child: Text("Submit", style: DashboardText.body(size: 14, weight: FontWeight.w700)),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Generic Yes/No confirmation dialog — for destructive or otherwise
/// consequential one-tap actions (deleting a record, etc). Returns true only
/// if the user tapped the confirm button.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = "Confirm",
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: DashboardText.heading(size: 17, color: Colors.black87)),
      content: Text(message, style: DashboardText.body(size: 13, color: DashboardColors.muted).copyWith(height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text("Cancel", style: DashboardText.body(size: 14, weight: FontWeight.w600, color: DashboardColors.muted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: destructive ? const Color(0xFFC62828) : DashboardColors.primary, foregroundColor: Colors.white),
          child: Text(confirmLabel, style: DashboardText.body(size: 14, weight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Booking summary shown right before a client pays — labor fee, HANAP's
/// 10% service fee, and the total, so there's no surprise before money
/// moves into escrow. Returns true if the client confirmed.
Future<bool> showBookingSummaryDialog(
  BuildContext context, {
  required String workerName,
  required String category,
  required DateTime? scheduledDate,
  required double budget,
}) async {
  final fee = double.parse((budget * 0.10).toStringAsFixed(2));
  final total = budget + fee;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text("Booking Summary", style: DashboardText.heading(size: 17, color: Colors.black87)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(icon: Icons.build_outlined, label: "Worker", value: workerName),
          _DetailRow(icon: Icons.category_outlined, label: "Service", value: category),
          if (scheduledDate != null) _DetailRow(icon: Icons.event_outlined, label: "Schedule", value: _detailDate(scheduledDate)),
          const Divider(height: 24),
          _SummaryLine(label: "Labor Fee", value: budget),
          _SummaryLine(label: "HANAP Service Fee (10%)", value: fee),
          const Divider(height: 20),
          _SummaryLine(label: "TOTAL", value: total, bold: true),
          const SizedBox(height: 8),
          Text(
            "Held in HANAP escrow until you confirm the job is done.",
            style: DashboardText.body(size: 11, color: DashboardColors.muted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text("Cancel", style: DashboardText.body(size: 14, weight: FontWeight.w600, color: DashboardColors.muted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: DashboardColors.primary, foregroundColor: Colors.white),
          child: Text("Confirm & Pay ₱${total.toStringAsFixed(0)}", style: DashboardText.body(size: 14, weight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _SummaryLine({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? DashboardText.heading(size: 15, color: Colors.black87)
        : DashboardText.body(size: 13, color: Colors.black87);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bold ? style : style.copyWith(color: DashboardColors.muted)),
          Text("₱${value.toStringAsFixed(0)}", style: style),
        ],
      ),
    );
  }
}

String _detailDate(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

String _paymentDetailLabel(String status) => switch (status) {
      'paid' => 'In Escrow',
      'refund_requested' => 'Refund Requested',
      'refunded' => 'Refunded',
      'released' => 'Released',
      _ => status,
    };

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: DashboardColors.muted),
          const SizedBox(width: 8),
          Text("$label: ", style: DashboardText.body(size: 13, color: DashboardColors.muted)),
          Expanded(child: Text(value, style: DashboardText.body(size: 13, weight: FontWeight.w600, color: Colors.black87))),
        ],
      ),
    );
  }
}

/// Full job details in a bottom sheet — tapped from a job card in either
/// dashboard's "My Jobs" list. Read-only; the card itself still owns any
/// action buttons (Cancel/Pay/Rate/etc.), this is purely informational so a
/// tap always does something useful even on jobs with no actions to take.
void showJobDetailsSheet(BuildContext context, Job job) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: DashboardColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(job.category, style: DashboardText.heading(size: 19, color: Colors.black87))),
                    DashboardStatusBadge(status: job.status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  jobRefNo(job.id),
                  style: DashboardText.body(size: 11.5, weight: FontWeight.w600, color: DashboardColors.muted),
                ),
                const SizedBox(height: 12),
                Text(
                  job.description,
                  style: DashboardText.body(size: 14, color: Colors.black87).copyWith(height: 1.5),
                ),
                const SizedBox(height: 18),
                if (job.budget != null) _DetailRow(icon: Icons.payments_outlined, label: "Budget", value: "₱${job.budget!.toStringAsFixed(0)}"),
                _DetailRow(icon: Icons.location_on_outlined, label: "Location", value: job.location),
                if (job.scheduledDate != null) _DetailRow(icon: Icons.event_outlined, label: "Scheduled", value: _detailDate(job.scheduledDate!)),
                if (job.clientName != null) _DetailRow(icon: Icons.person_outline, label: "Client", value: job.clientName!),
                if (job.workerName != null) _DetailRow(icon: Icons.build_outlined, label: "Worker", value: job.workerName!),
                _DetailRow(icon: Icons.calendar_today_outlined, label: "Posted", value: _detailDate(job.createdAt)),
                if (job.paymentStatus != 'unpaid')
                  _DetailRow(icon: Icons.account_balance_wallet_outlined, label: "Payment", value: _paymentDetailLabel(job.paymentStatus)),
                if (job.serviceFee != null)
                  _DetailRow(icon: Icons.receipt_long_outlined, label: "Total Paid", value: "₱${job.totalCharged.toStringAsFixed(0)}"),
                if (job.rating != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: DashboardColors.accent),
                      const SizedBox(width: 6),
                      Text("${job.rating}/5 rating", style: DashboardText.body(size: 13, weight: FontWeight.w600, color: Colors.black87)),
                    ],
                  ),
                  if (job.ratingComment != null && job.ratingComment!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('"${job.ratingComment}"', style: DashboardText.body(size: 13, color: DashboardColors.muted).copyWith(fontStyle: FontStyle.italic)),
                  ],
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
