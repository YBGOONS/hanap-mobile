import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../theme/dashboard_theme.dart';
import 'dashboard_widgets.dart';

/// Progress fraction shown per job status — matches the client's job
/// lifecycle in supabase/schema.sql (open → accepted → arrived → in_progress → completed).
double _progressForStatus(String status) => switch (status) {
      'accepted' => 0.25,
      'arrived' => 0.5,
      'in_progress' => 0.75,
      'completed' => 1.0,
      _ => 0.0,
    };

/// The client's single current job — title, worker, budget, location,
/// status, progress bar, and payment-status-driven quick actions (Pay once
/// completed, Request Refund once paid). Rating/"Approve Work" has no
/// backing RPC yet (no ratings table — see project_missing_schema_audit
/// memory), so it isn't shown here; only actions with a real RPC behind
/// them are rendered.
class ActiveJobCard extends StatelessWidget {
  final String jobId;
  final String title;
  final String workerName;
  final double budget;
  final String location;
  final String status;
  final String paymentStatus;
  final VoidCallback onChanged;

  const ActiveJobCard({
    super.key,
    required this.jobId,
    required this.title,
    required this.workerName,
    required this.budget,
    required this.location,
    required this.status,
    required this.paymentStatus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle = dashboardStatusStyle(status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Active Job", style: DashboardText.body(size: 12, weight: FontWeight.w700, color: DashboardColors.muted).copyWith(letterSpacing: 0.6)),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: DashboardText.heading(size: 17, color: Colors.black87))),
              DashboardStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 12),

          _InfoRow(icon: Icons.build_outlined, label: "Worker", value: workerName),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.payments_outlined, label: "Budget", value: "₱${budget.toStringAsFixed(0)}"),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.location_on_outlined, label: "Location", value: location),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progressForStatus(status),
              minHeight: 6,
              backgroundColor: DashboardColors.border,
              valueColor: AlwaysStoppedAnimation(statusStyle.color),
            ),
          ),
          const SizedBox(height: 16),

          _QuickActions(jobId: jobId, status: status, paymentStatus: paymentStatus, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: DashboardColors.muted),
        const SizedBox(width: 8),
        Text("$label: ", style: DashboardText.body(size: 13, color: DashboardColors.muted)),
        Expanded(child: Text(value, style: DashboardText.body(size: 13, weight: FontWeight.w600, color: Colors.black87))),
      ],
    );
  }
}

/// Payment-status-driven actions: Pay once the job is completed and unpaid,
/// Request Refund once it's paid, or an informational note while a refund
/// request is pending/resolved. Nothing shown while the job is still open.
class _QuickActions extends StatefulWidget {
  final String jobId;
  final String status;
  final String paymentStatus;
  final VoidCallback onChanged;

  const _QuickActions({required this.jobId, required this.status, required this.paymentStatus, required this.onChanged});

  @override
  State<_QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<_QuickActions> {
  bool _loading = false;

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      await supabase.rpc('mark_job_paid', params: {'job_id': widget.jobId});
      widget.onChanged();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestRefund() async {
    final reason = await showReasonDialog(
      context,
      title: "Request a refund",
      hint: "Why are you requesting a refund?",
      confirmLabel: "Submit",
    );
    if (reason == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await supabase.rpc('request_refund', params: {'job_id': widget.jobId, 'reason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refund requested. Waiting for admin review.")));
      widget.onChanged();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.paymentStatus == 'refund_requested') {
      return const _StatusNote(icon: Icons.hourglass_top, text: "Refund requested — waiting for admin review.", color: DashboardColors.accent);
    }
    if (widget.paymentStatus == 'refunded') {
      return const _StatusNote(icon: Icons.check_circle_outline, text: "This job was refunded.", color: DashboardColors.statusCancelled);
    }

    if (widget.status == 'completed' && widget.paymentStatus == 'unpaid') {
      return SizedBox(
        width: double.infinity,
        height: 42,
        child: ElevatedButton(
          onPressed: _loading ? null : _pay,
          style: ElevatedButton.styleFrom(
            backgroundColor: DashboardColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text("Pay Now", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
        ),
      );
    }

    if (widget.paymentStatus == 'paid') {
      return SizedBox(
        width: double.infinity,
        height: 42,
        child: OutlinedButton(
          onPressed: _loading ? null : _requestRefund,
          style: OutlinedButton.styleFrom(
            foregroundColor: DashboardColors.primary,
            side: const BorderSide(color: DashboardColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: DashboardColors.primary))
              : Text("Request Refund", style: DashboardText.body(size: 12, weight: FontWeight.w700)),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _StatusNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _StatusNote({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: DashboardText.body(size: 12, weight: FontWeight.w600, color: color))),
        ],
      ),
    );
  }
}

class EmptyActiveJobState extends StatelessWidget {
  const EmptyActiveJobState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.work_outline, size: 28, color: DashboardColors.muted),
          const SizedBox(height: 10),
          Text("No active job right now", style: DashboardText.heading(size: 14, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(
            "Post a job to find a worker.",
            style: DashboardText.body(size: 12, color: DashboardColors.muted),
          ),
        ],
      ),
    );
  }
}
