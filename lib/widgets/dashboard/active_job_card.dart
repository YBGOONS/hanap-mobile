import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../../models/job.dart';
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
/// status, progress bar, and the escrow-driven payment/rating actions.
class ActiveJobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onChanged;

  const ActiveJobCard({super.key, required this.job, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final statusStyle = dashboardStatusStyle(job.status);

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
              Expanded(child: Text(job.category, style: DashboardText.heading(size: 17, color: Colors.black87))),
              DashboardStatusBadge(status: job.status),
            ],
          ),
          const SizedBox(height: 12),

          _InfoRow(icon: Icons.build_outlined, label: "Worker", value: job.workerName ?? "—"),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.payments_outlined, label: "Budget", value: "₱${(job.budget ?? 0).toStringAsFixed(0)}"),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.location_on_outlined, label: "Location", value: job.location),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progressForStatus(job.status),
              minHeight: 6,
              backgroundColor: DashboardColors.border,
              valueColor: AlwaysStoppedAnimation(statusStyle.color),
            ),
          ),
          const SizedBox(height: 16),

          JobPaymentActions(job: job, onChanged: onChanged),
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

/// Escrow-driven payment/rating actions for a job, shared by [ActiveJobCard]
/// (Dashboard tab's spotlighted job) and the client's My Jobs list — a
/// client can have more than one accepted-unpaid job at once, and only one
/// gets the Dashboard spotlight, so every job card needs this, not just the
/// spotlighted one.
///
/// Flow: Pay Now (accepted+unpaid) → escrow, arrival code shown, Request
/// Refund available throughout → worker completes with photos → client
/// reviews and either Confirms (releases payment, then can rate) or
/// Requests a Refund instead (dispute). A denied refund auto-releases to
/// the worker — the dispute is fully resolved either way, nothing is left
/// stuck in escrow.
class JobPaymentActions extends StatefulWidget {
  final Job job;
  final VoidCallback onChanged;

  const JobPaymentActions({super.key, required this.job, required this.onChanged});

  @override
  State<JobPaymentActions> createState() => _JobPaymentActionsState();
}

class _JobPaymentActionsState extends State<JobPaymentActions> {
  bool _loading = false;
  bool _rating = false;

  Future<void> _pay() async {
    final job = widget.job;
    final confirmed = await showBookingSummaryDialog(
      context,
      workerName: job.workerName ?? "Worker",
      category: job.category,
      scheduledDate: job.scheduledDate,
      budget: job.budget ?? 0,
    );
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);
    try {
      // Real GCash checkout via PayMongo (see supabase/functions/create-gcash-payment)
      // — this only opens the checkout, it doesn't mark the job paid.
      // paymongo-webhook does that once PayMongo confirms the charge, so
      // the client needs to pull-to-refresh after finishing checkout.
      final response = await supabase.functions.invoke('create-gcash-payment', body: {'job_id': job.id});
      final data = response.data as Map<String, dynamic>?;
      final checkoutUrl = data?['checkout_url'] as String?;
      if (checkoutUrl == null) {
        throw Exception(data?['error'] ?? 'Could not start payment.');
      }
      await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Finish the GCash payment in the new tab, then pull down here to refresh.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payment failed: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestRefund() async {
    final result = await showRefundRequestDialog(context);
    if (result == null || !mounted) return;

    final bytes = result.file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not read that photo. Please try again.")));
      return;
    }

    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final ext = (result.file.extension ?? 'jpg').toLowerCase();
      final path = '$userId/${widget.job.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage.from('refund-evidence').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

      await supabase.rpc('request_refund', params: {'job_id': widget.job.id, 'reason': result.reason, 'photo_url': path});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refund requested. Waiting for admin review.")));
      widget.onChanged();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on StorageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmCompletion() async {
    setState(() => _loading = true);
    try {
      await supabase.rpc('confirm_completion', params: {'job_id': widget.job.id});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment released to your worker!")));
      widget.onChanged();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rateWorker() async {
    final result = await showRatingDialog(context);
    if (result == null || !mounted) return;

    setState(() => _rating = true);
    try {
      await supabase.rpc('rate_job', params: {'job_id': widget.job.id, 'rating': result.rating, 'comment': result.comment.isEmpty ? null : result.comment});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks for rating!")));
      widget.onChanged();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _rating = false);
    }
  }

  Widget _payButton() {
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

  Widget _otpNote() {
    final otp = widget.job.arrivalOtp ?? "----";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DashboardColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DashboardColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_clock_outlined, size: 15, color: DashboardColors.primary),
              const SizedBox(width: 6),
              Text("Arrival Code", style: DashboardText.body(size: 12, weight: FontWeight.w700, color: DashboardColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(otp, style: DashboardText.heading(size: 26, color: DashboardColors.primary).copyWith(letterSpacing: 6)),
          const SizedBox(height: 4),
          Text("Share this with your worker when they arrive.", style: DashboardText.body(size: 11, color: DashboardColors.muted)),
        ],
      ),
    );
  }

  Widget _rateWorkerButton() {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton.icon(
        onPressed: _rating ? null : _rateWorker,
        icon: _rating
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: DashboardColors.accent))
            : const Icon(Icons.star_border, size: 18, color: DashboardColors.accent),
        label: Text("Rate Worker", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: DashboardColors.accent)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: DashboardColors.accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _requestRefundButton() {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton(
        onPressed: _loading ? null : _requestRefund,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFC62828),
          side: const BorderSide(color: Color(0xFFC62828)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC62828)))
            : Text("Request Refund", style: DashboardText.body(size: 12, weight: FontWeight.w700)),
      ),
    );
  }

  Widget _completionReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton(
            onPressed: _loading ? null : _confirmCompletion,
            style: ElevatedButton.styleFrom(
              backgroundColor: DashboardColors.statusCompleted,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text("Confirm & Release Payment", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 8),
        _requestRefundButton(),
      ],
    );
  }

  Widget _receipt() {
    final job = widget.job;
    final labor = job.budget ?? 0;
    final fee = job.serviceFee ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: DashboardColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: DashboardColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Receipt", style: DashboardText.body(size: 12, weight: FontWeight.w700, color: DashboardColors.muted)),
          const SizedBox(height: 8),
          _ReceiptLine(label: "Worker's Labor Fee", value: labor),
          _ReceiptLine(label: "HANAP Service Fee (10%)", value: fee),
          const Divider(height: 18),
          _ReceiptLine(label: "Total Paid", value: labor + fee, bold: true),
          const SizedBox(height: 6),
          Text("Worker received ₱${labor.toStringAsFixed(0)} — payment released.", style: DashboardText.body(size: 11, color: DashboardColors.statusCompleted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

    if (job.paymentStatus == 'refunded') {
      return _StatusNote(
        icon: Icons.assignment_return_outlined,
        text: job.refundAdminMessage == null ? "This job was refunded." : "Refunded: ${job.refundAdminMessage}",
        color: DashboardColors.statusCancelled,
      );
    }
    if (job.paymentStatus == 'refund_requested') {
      return const _StatusNote(icon: Icons.hourglass_top, text: "Refund requested — waiting for admin review.", color: DashboardColors.accent);
    }
    // Payment happens right after acceptance — before the worker can even
    // mark themselves 'arrived' (see verify_arrival_otp in schema.sql).
    if (job.status == 'accepted' && job.paymentStatus == 'unpaid') {
      return _payButton();
    }
    if (job.status == 'completed' && job.paymentStatus == 'paid') {
      return _completionReview();
    }
    if (job.paymentStatus == 'paid') {
      // Escrowed, job still in progress — refund is always available as a
      // dispute path, and the arrival code is shown until the worker uses it.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (job.status == 'accepted') ...[
            _otpNote(),
            const SizedBox(height: 10),
          ],
          _requestRefundButton(),
        ],
      );
    }
    if (job.paymentStatus == 'released') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _receipt(),
          const SizedBox(height: 10),
          job.rating != null
              ? const _StatusNote(icon: Icons.star, text: "You rated this job — booking complete.", color: DashboardColors.accent)
              : _rateWorkerButton(),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _ReceiptLine extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _ReceiptLine({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold ? DashboardText.heading(size: 14, color: Colors.black87) : DashboardText.body(size: 12.5, color: Colors.black87);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
