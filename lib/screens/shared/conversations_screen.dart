import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/job.dart';
import '../../models/message.dart';
import '../../theme/dashboard_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/dashboard/dashboard_widgets.dart';
import 'chat_screen.dart';

/// List of jobs that have (or can have) a message thread — any job where
/// the current user is the client or worker and a worker has actually been
/// assigned. Shared by Client and Worker; which side of the job the current
/// user is on is worked out per-row.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationEntry {
  final Job job;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime lastActivity;
  final bool workerRepliedToDispute;
  const _ConversationEntry({
    required this.job,
    this.lastMessage,
    required this.unreadCount,
    required this.lastActivity,
    required this.workerRepliedToDispute,
  });
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Future<List<_ConversationEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_ConversationEntry>> _load() async {
    final userId = supabase.auth.currentUser!.id;

    final jobRows = await supabase
        .from('jobs')
        .select(
          '*, client:profiles!jobs_client_id_fkey(first_name,last_name), worker:profiles!jobs_worker_id_fkey(first_name,last_name)',
        )
        .or('client_id.eq.$userId,worker_id.eq.$userId')
        .not('worker_id', 'is', null)
        .order('created_at', ascending: false);
    final jobs = (jobRows as List)
        .map((r) => Job.fromMap(r as Map<String, dynamic>))
        .toList();

    if (jobs.isEmpty) return [];

    final jobIds = jobs.map((j) => j.id).toList();
    final msgRows = await supabase
        .from('messages')
        .select()
        .inFilter('job_id', jobIds)
        .order('created_at', ascending: false);
    final messages = (msgRows as List)
        .map((r) => Message.fromMap(r as Map<String, dynamic>))
        .toList();

    final byJob = <String, List<Message>>{};
    for (final m in messages) {
      byJob.putIfAbsent(m.jobId, () => []).add(m);
    }

    // Refund dispute activity lives in a separate table — folded in here so
    // a job with a live dispute sorts by *its* most recent reply, not by
    // whenever the job itself happened to be posted, and so a tile can tell
    // whether the worker has actually replied yet.
    final disputeJobIds = jobs
        .where((j) => j.refundRequestedAt != null)
        .map((j) => j.id)
        .toList();
    final List refundMsgRows = disputeJobIds.isEmpty
        ? const []
        : await supabase
              .from('refund_messages')
              .select('job_id, sender_id, created_at')
              .inFilter('job_id', disputeJobIds);
    final workerIdByJob = {for (final j in jobs) j.id: j.workerId};
    final latestRefundActivity = <String, DateTime>{};
    final workerRepliedByJob = <String, bool>{};
    for (final row in refundMsgRows) {
      final jobId = row['job_id'] as String;
      final createdAt = DateTime.parse(row['created_at'] as String);
      final current = latestRefundActivity[jobId];
      if (current == null || createdAt.isAfter(current)) {
        latestRefundActivity[jobId] = createdAt;
      }
      if (row['sender_id'] == workerIdByJob[jobId]) {
        workerRepliedByJob[jobId] = true;
      }
    }

    final entries = jobs.map((j) {
      final jobMessages = byJob[j.id] ?? const <Message>[];
      final unread = jobMessages
          .where((m) => m.senderId != userId && m.readAt == null)
          .length;
      final last = jobMessages.isNotEmpty ? jobMessages.first : null;

      final candidates = <DateTime>[j.createdAt];
      if (last != null) candidates.add(last.createdAt);
      if (j.refundRequestedAt != null) candidates.add(j.refundRequestedAt!);
      final latestRefund = latestRefundActivity[j.id];
      if (latestRefund != null) candidates.add(latestRefund);

      return _ConversationEntry(
        job: j,
        lastMessage: last,
        unreadCount: unread,
        lastActivity: candidates.reduce((a, b) => a.isAfter(b) ? a : b),
        workerRepliedToDispute: workerRepliedByJob[j.id] ?? false,
      );
    }).toList();

    // Most recent activity first, across regular chat and refund disputes
    // alike.
    entries.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

    return entries;
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser!.id;
    return Scaffold(
      backgroundColor: DashboardColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: DashboardColors.primary),
        title: Text(
          "Messages",
          style: DashboardText.heading(size: 18, color: Colors.black87),
        ),
      ),
      body: RefreshIndicator(
        color: DashboardColors.primary,
        onRefresh: _refresh,
        child: FutureBuilder<List<_ConversationEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: DashboardColors.primary,
                ),
              );
            }
            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: DashboardStateMessage(
                  title: "Couldn't load messages.",
                  message: "${snapshot.error}",
                ),
              );
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: DashboardStateMessage(
                  title: "No conversations yet.",
                  message:
                      "Once a job has a worker assigned, you can message each other here.",
                ),
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final entry = entries[i];
                final isClient = entry.job.clientId == userId;
                final otherName = isClient
                    ? (entry.job.workerName ?? "Worker")
                    : (entry.job.clientName ?? "Client");
                // An active dispute (worker has replied) takes this
                // conversation over entirely — straight to the dispute
                // thread instead of the otherwise-empty regular chat.
                final activeDispute =
                    entry.job.paymentStatus == 'refund_requested' &&
                    entry.workerRepliedToDispute;
                return _ConversationTile(
                  entry: entry,
                  otherName: otherName,
                  onTap: () async {
                    if (activeDispute) {
                      showJobDetailsSheet(context, entry.job);
                      return;
                    }
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(job: entry.job, otherName: otherName),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final _ConversationEntry entry;
  final String otherName;
  final VoidCallback onTap;
  const _ConversationTile({
    required this.entry,
    required this.otherName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = otherName.isNotEmpty ? otherName[0].toUpperCase() : "?";
    final preview = entry.lastMessage?.body ?? "No messages yet. Say hello.";
    // Surfaces an open refund dispute here too, not just in notifications —
    // once resolved it goes back to the normal last-message preview.
    final hasOpenDispute = entry.job.paymentStatus == 'refund_requested';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: DashboardColors.primary,
        child: Text(
          initials,
          style: DashboardText.heading(size: 15, color: Colors.white),
        ),
      ),
      title: Text(
        "${entry.job.category} · ${jobRefNo(entry.job.id)}",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DashboardText.heading(size: 14, color: Colors.black87),
      ),
      subtitle: Text(
        hasOpenDispute
            ? "Refund dispute · $otherName"
            : "$otherName · $preview",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DashboardText.body(
          size: 12,
          weight: hasOpenDispute ? FontWeight.w700 : FontWeight.w400,
          color: hasOpenDispute
              ? DashboardColors.accent
              : DashboardColors.muted,
        ),
      ),
      trailing: entry.unreadCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: DashboardColors.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${entry.unreadCount}",
                style: DashboardText.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }
}
