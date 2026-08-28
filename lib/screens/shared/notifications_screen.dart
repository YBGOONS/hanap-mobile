import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/app_notification.dart';
import '../../models/job.dart';
import '../../theme/dashboard_theme.dart';
import '../../widgets/dashboard/dashboard_widgets.dart';

/// System-event feed (job accepted, status changed, paid, refund
/// requested/resolved) — shared by Client and Worker, since both roles
/// receive the same kind of notification rows, just addressed to them.
/// Tapping a notification marks just that one as read and, if it points at
/// a job, opens that job's details.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() async {
    final userId = supabase.auth.currentUser!.id;
    final rows = await supabase.from('notifications').select().eq('user_id', userId).order('created_at', ascending: false);
    return (rows as List).map((r) => AppNotification.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openNotification(List<AppNotification> items, int index) async {
    final item = items[index];
    if (item.readAt == null) {
      try {
        final updatedRows = await supabase
            .from('notifications')
            .update({'read_at': DateTime.now().toIso8601String()})
            .eq('id', item.id)
            .select();
        // Only reflect it as read locally once the write is actually
        // confirmed — an RLS-filtered zero-row update returns success with
        // an empty list instead of throwing, so checking for a returned
        // row is the only way to catch that silently.
        if (updatedRows.isNotEmpty && mounted) {
          setState(() => items[index] = item.copyWith(readAt: DateTime.now()));
        }
      } catch (_) {
        // Not fatal — still let them open the job even if marking as read failed.
      }
    }

    if (item.jobId == null) return;
    try {
      final row = await supabase
          .from('jobs')
          .select('*, client:profiles!jobs_client_id_fkey(first_name,last_name), worker:profiles!jobs_worker_id_fkey(first_name,last_name), ratings(rating,comment)')
          .eq('id', item.jobId!)
          .maybeSingle();
      if (!mounted) return;
      if (row == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This job is no longer available.")));
        return;
      }
      showJobDetailsSheet(context, Job.fromMap(row));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open that job right now.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: DashboardColors.primary),
        title: Text("Notifications", style: DashboardText.heading(size: 18, color: Colors.black87)),
      ),
      body: RefreshIndicator(
        color: DashboardColors.primary,
        onRefresh: _refresh,
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
            }
            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: DashboardStateMessage(title: "Couldn't load notifications.", message: "${snapshot.error}"),
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: DashboardStateMessage(title: "No notifications yet."),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _NotificationCard(item: items[i], onTap: () => _openNotification(items, i)),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;
  const _NotificationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final wasUnread = item.readAt == null;
    final d = item.createdAt;
    final dateLabel = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: wasUnread ? DashboardColors.accent.withValues(alpha: 0.4) : DashboardColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(color: wasUnread ? DashboardColors.accent : DashboardColors.border, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: DashboardText.heading(size: 14, color: Colors.black87)),
                  if (item.body != null) ...[
                    const SizedBox(height: 3),
                    Text(item.body!, style: DashboardText.body(size: 12, color: DashboardColors.muted).copyWith(height: 1.4)),
                  ],
                  const SizedBox(height: 6),
                  Text(dateLabel, style: DashboardText.body(size: 11, color: DashboardColors.muted)),
                ],
              ),
            ),
            if (item.jobId != null) Icon(Icons.chevron_right, size: 18, color: DashboardColors.muted),
          ],
        ),
      ),
    );
  }
}
