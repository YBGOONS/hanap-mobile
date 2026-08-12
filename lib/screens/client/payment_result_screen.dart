import 'dart:async';
import 'package:flutter/material.dart';
import '../../main.dart';
import 'client_dashboard_screen.dart';

const _gcashBlue = Color(0xFF0037A5);
const _gcashBlueDark = Color(0xFF001E66);

/// Landing page after a PayMongo GCash redirect (success or failed) — this
/// is a fresh page load in a new browser context (PayMongo navigates the
/// tab here directly), not a continuation of whatever screen the client
/// was on before checkout, so there's no navigator stack to pop back into.
/// Styled like an actual GCash "Sent" receipt since that's the payment
/// experience the client just went through. Shows a countdown then a hard
/// redirect into My Jobs.
class PaymentResultScreen extends StatefulWidget {
  final bool success;
  final String? jobId;
  const PaymentResultScreen({super.key, required this.success, this.jobId});

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  int _secondsLeft = 15;
  Timer? _timer;
  Future<Map<String, dynamic>?>? _jobFuture;

  @override
  void initState() {
    super.initState();
    if (widget.success && widget.jobId != null) {
      _jobFuture = _loadJob(widget.jobId!);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        _redirect();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  Future<Map<String, dynamic>?> _loadJob(String jobId) async {
    try {
      return await supabase
          .from('jobs')
          .select('category, budget, paymongo_source_id, worker:profiles!jobs_worker_id_fkey(first_name,last_name)')
          .eq('id', jobId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _redirect() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ClientDashboardScreen(openMyJobs: true)),
      (route) => false,
    );
  }

  String _maskName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return name;
    final first = parts.first;
    final masked = first.length <= 3 ? first : '${first.substring(0, 2)}${'•' * (first.length - 3)}${first.substring(first.length - 1)}';
    final lastInitial = parts.length > 1 && parts.last.isNotEmpty ? ' ${parts.last[0].toUpperCase()}.' : '';
    return '${masked.toUpperCase()}$lastInitial';
  }

  String _refNo(String? sourceId) {
    if (sourceId == null) return '—';
    final digits = sourceId.codeUnits.fold<int>(0, (a, b) => a + b).toString().padLeft(12, '0');
    return '${digits.substring(0, 4)} ${digits.substring(4, 8)} ${digits.substring(8, 12)}';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
    ];
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} ${hour12.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.success) return _buildFailed();

    return Scaffold(
      backgroundColor: _gcashBlue,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _jobFuture,
          builder: (context, snapshot) {
            final job = snapshot.data;
            final budget = (job?['budget'] as num?)?.toDouble() ?? 0;
            final fee = double.parse((budget * 0.10).toStringAsFixed(2));
            final total = budget + fee;
            final workerName = _fullName(job?['worker']) ?? 'Your Worker';

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "HANAP Payment",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: _gcashBlue, size: 34),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 380),
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      children: [
                        Text(
                          _maskName(workerName),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _gcashBlue, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job?['category'] as String? ?? '',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Sent via GCash",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        _receiptRow("Labor Fee", "₱${budget.toStringAsFixed(2)}"),
                        const SizedBox(height: 10),
                        _receiptRow("HANAP Service Fee", "₱${fee.toStringAsFixed(2)}"),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        _receiptRow("Total Amount Sent", "₱${total.toStringAsFixed(2)}", bold: true),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        _receiptRow("Ref No.", _refNo(job?['paymongo_source_id'] as String?), small: true),
                        const SizedBox(height: 8),
                        _receiptRow("Date", _formatDate(DateTime.now()), small: true),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: _gcashBlue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_clock_outlined, size: 16, color: _gcashBlue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Held in HANAP escrow until you confirm the job is done.",
                                  style: TextStyle(color: _gcashBlueDark, fontSize: 11.5, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    "Redirecting to My Jobs in $_secondsLeft...",
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _redirect,
                    child: const Text("Go now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false, bool small = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: small ? 12 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            color: bold ? _gcashBlue : Colors.black87,
            fontSize: bold ? 17 : (small ? 12 : 13),
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String? _fullName(dynamic profile) {
    if (profile is! Map) return null;
    final first = profile['first_name'] as String?;
    final last = profile['last_name'] as String?;
    if ((first == null || first.isEmpty) && (last == null || last.isEmpty)) return null;
    return '${first ?? ''} ${last ?? ''}'.trim();
  }

  Widget _buildFailed() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: const Color(0xFFC62828).withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.error_outline, size: 48, color: Color(0xFFC62828)),
                ),
                const SizedBox(height: 20),
                const Text("Payment Failed", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
                const SizedBox(height: 8),
                Text(
                  "The payment didn't go through. You can try again from My Jobs.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                ),
                const SizedBox(height: 28),
                Text("Redirecting in $_secondsLeft...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 10),
                TextButton(onPressed: _redirect, child: const Text("Go now")),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
