import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/job.dart';
import '../../models/message.dart';
import '../../theme/dashboard_theme.dart';
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
  const _ConversationEntry({required this.job, this.lastMessage, required this.unreadCount});
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
        .select('*, client:profiles!jobs_client_id_fkey(first_name,last_name), worker:profiles!jobs_worker_id_fkey(first_name,last_name)')
        .or('client_id.eq.$userId,worker_id.eq.$userId')
        .not('worker_id', 'is', null)
        .order('created_at', ascending: false);
    final jobs = (jobRows as List).map((r) => Job.fromMap(r as Map<String, dynamic>)).toList();

    if (jobs.isEmpty) return [];

    final jobIds = jobs.map((j) => j.id).toList();
    final msgRows = await supabase.from('messages').select().inFilter('job_id', jobIds).order('created_at', ascending: false);
    final messages = (msgRows as List).map((r) => Message.fromMap(r as Map<String, dynamic>)).toList();

    final byJob = <String, List<Message>>{};
    for (final m in messages) {
      byJob.putIfAbsent(m.jobId, () => []).add(m);
    }

    final entries = jobs.map((j) {
      final jobMessages = byJob[j.id] ?? const <Message>[];
      final unread = jobMessages.where((m) => m.senderId != userId && m.readAt == null).length;
      final last = jobMessages.isNotEmpty ? jobMessages.first : null;
      return _ConversationEntry(job: j, lastMessage: last, unreadCount: unread);
    }).toList();

    // Most recent activity first — falls back to job creation time for
    // threads with no messages sent yet.
    entries.sort((a, b) {
      final aTime = a.lastMessage?.createdAt ?? a.job.createdAt;
      final bTime = b.lastMessage?.createdAt ?? b.job.createdAt;
      return bTime.compareTo(aTime);
    });

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
        title: Text("Messages", style: DashboardText.heading(size: 18, color: Colors.black87)),
      ),
      body: RefreshIndicator(
        color: DashboardColors.primary,
        onRefresh: _refresh,
        child: FutureBuilder<List<_ConversationEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
            }
            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: DashboardStateMessage(title: "Couldn't load messages.", message: "${snapshot.error}"),
              );
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: DashboardStateMessage(
                  title: "No conversations yet.",
                  message: "Once a job has a worker assigned, you can message each other here.",
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
                final otherName = isClient ? (entry.job.workerName ?? "Worker") : (entry.job.clientName ?? "Client");
                return _ConversationTile(
                  entry: entry,
                  otherName: otherName,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(job: entry.job, otherName: otherName)));
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
  const _ConversationTile({required this.entry, required this.otherName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = otherName.isNotEmpty ? otherName[0].toUpperCase() : "?";
    final preview = entry.lastMessage?.body ?? "No messages yet. Say hello.";
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: DashboardColors.primary,
        child: Text(initials, style: DashboardText.heading(size: 15, color: Colors.white)),
      ),
      title: Text(otherName, style: DashboardText.heading(size: 14, color: Colors.black87)),
      subtitle: Text(
        "${entry.job.category} · $preview",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DashboardText.body(size: 12, color: DashboardColors.muted),
      ),
      trailing: entry.unreadCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: DashboardColors.accent, borderRadius: BorderRadius.circular(20)),
              child: Text("${entry.unreadCount}", style: DashboardText.body(size: 11, weight: FontWeight.w700, color: Colors.white)),
            )
          : null,
    );
  }
}
