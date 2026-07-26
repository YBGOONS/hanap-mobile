import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../models/job.dart';
import '../../theme/dashboard_theme.dart';
import '../../widgets/dashboard/active_job_card.dart';
import '../../widgets/dashboard/dashboard_widgets.dart';
import '../public/home_screen.dart';
import '../public/post_job_screen.dart';
import '../shared/conversations_screen.dart';
import '../shared/notifications_screen.dart';

/// Client Dashboard — mobile adaptation of the React DashboardShell.
///
/// The sidebar becomes a bottom nav; "Jobs" opens a bottom sheet with
/// Post a Job / My Jobs (My Jobs switches tab, Post a Job pushes a route
/// and refreshes the Dashboard tab on success). "Inbox" opens a sheet with
/// Messages (per-job chat, shared/conversations_screen.dart +
/// shared/chat_screen.dart) and Notifications (shared/notifications_screen.dart).
class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

enum _Tab { dashboard, myJobs, workers, profile }

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  _Tab _tab = _Tab.dashboard;
  int _dashboardRefreshTick = 0;
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _checkUnread();
  }

  Future<void> _checkUnread() async {
    final userId = supabase.auth.currentUser!.id;

    final notifRows = await supabase.from('notifications').select('id').eq('user_id', userId).isFilter('read_at', null).limit(1);
    if ((notifRows as List).isNotEmpty) {
      if (mounted) setState(() => _hasUnread = true);
      return;
    }

    final jobRows = await supabase.from('jobs').select('id').or('client_id.eq.$userId,worker_id.eq.$userId').not('worker_id', 'is', null);
    final jobIds = (jobRows as List).map((r) => r['id'] as String).toList();
    if (jobIds.isEmpty) {
      if (mounted) setState(() => _hasUnread = false);
      return;
    }

    final msgRows =
        await supabase.from('messages').select('id').inFilter('job_id', jobIds).neq('sender_id', userId).isFilter('read_at', null).limit(1);
    if (mounted) setState(() => _hasUnread = (msgRows as List).isNotEmpty);
  }

  void _openJobsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ActionSheet(
        items: [
          (icon: Icons.add_circle_outline, label: "Post a Job", onTap: _postJob),
          (icon: Icons.list_alt_outlined, label: "My Jobs", onTap: () => setState(() => _tab = _Tab.myJobs)),
        ],
      ),
    );
  }

  Future<void> _postJob() async {
    final posted = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PostJobScreen()));
    if (posted == true) setState(() => _dashboardRefreshTick++);
  }

  void _openInboxSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ActionSheet(
        items: [
          (icon: Icons.chat_bubble_outline, label: "Messages", onTap: () => _openInboxScreen(const ConversationsScreen())),
          (icon: Icons.notifications_outlined, label: "Notifications", onTap: () => _openInboxScreen(const NotificationsScreen())),
        ],
      ),
    );
  }

  Future<void> _openInboxScreen(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _checkUnread();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardColors.bg,
      body: SafeArea(
        child: switch (_tab) {
          _Tab.dashboard => _DashboardTab(key: ValueKey(_dashboardRefreshTick)),
          _Tab.myJobs => const _MyJobsTab(),
          _Tab.workers => const _WorkersTab(),
          _Tab.profile => const _ProfileTab(),
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: DashboardColors.primary,
        unselectedItemColor: DashboardColors.muted,
        currentIndex: switch (_tab) {
          _Tab.dashboard => 0,
          _Tab.myJobs => 1,
          _Tab.workers => 2,
          _Tab.profile => 4,
        },
        onTap: (i) {
          switch (i) {
            case 0:
              setState(() => _tab = _Tab.dashboard);
            case 1:
              _openJobsSheet();
            case 2:
              setState(() => _tab = _Tab.workers);
            case 3:
              _openInboxSheet();
            case 4:
              setState(() => _tab = _Tab.profile);
          }
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Dashboard"),
          const BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: "Jobs"),
          const BottomNavigationBarItem(icon: Icon(Icons.engineering_outlined), label: "Workers"),
          BottomNavigationBarItem(icon: _InboxIcon(hasUnread: _hasUnread), label: "Inbox"),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }
}

/// Small unread-badge dot on the Inbox tab icon — sample `true` for now.
class _InboxIcon extends StatelessWidget {
  final bool hasUnread;
  const _InboxIcon({required this.hasUnread});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chat_bubble_outline),
        if (hasUnread)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: DashboardColors.accent, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}

class _DashboardData {
  final String firstName;
  final int activeCount;
  final int completedCount;
  final int openCount;
  final Job? activeJob;
  final List<Job> recentJobs;

  const _DashboardData({
    required this.firstName,
    required this.activeCount,
    required this.completedCount,
    required this.openCount,
    required this.activeJob,
    required this.recentJobs,
  });
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab({super.key});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  late Future<_DashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_DashboardData> _load() async {
    final userId = supabase.auth.currentUser!.id;

    final profileRow = await supabase.from('profiles').select('first_name').eq('id', userId).single();

    final jobRows = await supabase
        .from('jobs')
        .select('*, worker:profiles!jobs_worker_id_fkey(first_name,last_name)')
        .eq('client_id', userId)
        .order('created_at', ascending: false);
    final jobs = (jobRows as List).map((r) => Job.fromMap(r as Map<String, dynamic>)).toList();

    Job? activeJob;
    for (final j in jobs) {
      // A completed-but-unresolved job (still needs paying, or a refund
      // request is pending) stays in the spotlight; once refunded it's
      // fully done and just shows in Recent Jobs like any other job.
      final needsAttention =
          j.status == 'accepted' || j.status == 'arrived' || j.status == 'in_progress' || (j.status == 'completed' && j.paymentStatus != 'refunded');
      if (needsAttention) {
        activeJob = j;
        break;
      }
    }

    return _DashboardData(
      firstName: profileRow['first_name'] as String,
      activeCount: jobs.where((j) => j.status == 'accepted' || j.status == 'arrived' || j.status == 'in_progress').length,
      completedCount: jobs.where((j) => j.status == 'completed').length,
      openCount: jobs.where((j) => j.status == 'open').length,
      activeJob: activeJob,
      recentJobs: jobs.take(3).toList(),
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _dataFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: DashboardColors.primary,
      onRefresh: _refresh,
      child: FutureBuilder<_DashboardData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                DashboardStateMessage(title: "Couldn't load the dashboard.", message: "${snapshot.error}"),
              ],
            );
          }

          final data = snapshot.data!;
          final stats = [
            (label: "Active Jobs", value: "${data.activeCount}", color: DashboardColors.statActive),
            (label: "Completed", value: "${data.completedCount}", color: DashboardColors.statCompleted),
            (label: "Open", value: "${data.openCount}", color: DashboardColors.statOpen),
          ];

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardHeaderCard(
                  title: "Client Dashboard",
                  greetingName: data.firstName,
                  subtitle: "Here's your job overview.",
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i != 0) const SizedBox(width: 10),
                      Expanded(
                        child: DashboardStatCard(value: stats[i].value, label: stats[i].label, accentColor: stats[i].color),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                if (data.activeJob != null)
                  ActiveJobCard(
                    jobId: data.activeJob!.id,
                    title: data.activeJob!.category,
                    workerName: data.activeJob!.workerName ?? "—",
                    budget: data.activeJob!.budget ?? 0,
                    location: data.activeJob!.location,
                    status: data.activeJob!.status,
                    paymentStatus: data.activeJob!.paymentStatus,
                    onChanged: _refresh,
                  )
                else
                  const EmptyActiveJobState(),
                const SizedBox(height: 24),

                Text("Recent Jobs", style: DashboardText.heading(size: 15, color: Colors.black87)),
                const SizedBox(height: 10),
                if (data.recentJobs.isEmpty)
                  Text("You haven't posted any jobs yet.", style: DashboardText.body(size: 13, color: DashboardColors.muted))
                else
                  for (final job in data.recentJobs)
                    RecentJobListItem(title: job.category, location: job.location, status: job.status),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  final List<({IconData icon, String label, VoidCallback? onTap})> items;
  const _ActionSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items
              .map((item) => ListTile(
                    leading: Icon(item.icon, color: DashboardColors.primary),
                    title: Text(item.label, style: DashboardText.body(size: 15, weight: FontWeight.w600, color: Colors.black87)),
                    onTap: () {
                      Navigator.of(context).pop();
                      item.onTap?.call();
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ── MY JOBS TAB ──────────────────────────────────────────────────────────

class _MyJobsTab extends StatefulWidget {
  const _MyJobsTab();

  @override
  State<_MyJobsTab> createState() => _MyJobsTabState();
}

class _MyJobsTabState extends State<_MyJobsTab> {
  late Future<List<Job>> _jobsFuture;
  String _statusFilter = 'All';
  String? _cancelingJobId;

  static const _statuses = ['All', 'open', 'accepted', 'arrived', 'in_progress', 'completed', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _jobsFuture = _load();
  }

  Future<List<Job>> _load() async {
    final userId = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('jobs')
        .select('*, worker:profiles!jobs_worker_id_fkey(first_name,last_name)')
        .eq('client_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Job.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _jobsFuture = future);
    await future;
  }

  Future<void> _cancel(Job job) async {
    final reason = await showReasonDialog(
      context,
      title: "Cancel this job?",
      hint: "Why are you cancelling?",
      confirmLabel: "Cancel Job",
    );
    if (reason == null || !mounted) return;

    setState(() => _cancelingJobId = job.id);
    try {
      await supabase.rpc('cancel_open_job', params: {'job_id': job.id, 'reason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Job cancelled.")));
      await _refresh();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _cancelingJobId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: DashboardColors.primary,
      onRefresh: _refresh,
      child: FutureBuilder<List<Job>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
          }
          if (snapshot.hasError) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: DashboardStateMessage(title: "Couldn't load your jobs.", message: "${snapshot.error}"),
            );
          }

          final allJobs = snapshot.data ?? [];
          final jobs = _statusFilter == 'All' ? allJobs : allJobs.where((j) => j.status == _statusFilter).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text("My Jobs", style: DashboardText.heading(size: 18, color: Colors.black87)),
              ),
              if (allJobs.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: _statuses.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final s = _statuses[i];
                      final selected = s == _statusFilter;
                      return ChoiceChip(
                        label: Text(s == 'All' ? s : dashboardStatusStyle(s).label),
                        selected: selected,
                        onSelected: (_) => setState(() => _statusFilter = s),
                        selectedColor: DashboardColors.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: selected ? DashboardColors.primary : DashboardColors.border),
                        labelStyle: DashboardText.body(size: 12, weight: FontWeight.w600, color: selected ? Colors.white : Colors.black87),
                      );
                    },
                  ),
                ),
              Expanded(
                child: jobs.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: DashboardStateMessage(
                          title: allJobs.isEmpty ? "You haven't posted any jobs yet." : "No jobs in this status.",
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: jobs.length,
                        itemBuilder: (context, i) {
                          final job = jobs[i];
                          return _JobHistoryCard(
                            job: job,
                            canceling: _cancelingJobId == job.id,
                            onCancel: job.status == 'open' ? () => _cancel(job) : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JobHistoryCard extends StatelessWidget {
  final Job job;
  final bool canceling;
  final VoidCallback? onCancel;
  const _JobHistoryCard({required this.job, this.canceling = false, this.onCancel});

  String _paymentLabel(String status) => switch (status) {
        'paid' => 'Paid',
        'refund_requested' => 'Refund Requested',
        'refunded' => 'Refunded',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    final statusStyle = dashboardStatusStyle(job.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              Expanded(child: Text(job.category, style: DashboardText.heading(size: 15, color: Colors.black87))),
              if (job.budget != null)
                Text("₱${job.budget!.toStringAsFixed(0)}", style: DashboardText.heading(size: 15, color: DashboardColors.accent)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _MetaText(icon: Icons.location_on_outlined, text: job.location),
              if (job.workerName != null) _MetaText(icon: Icons.build_outlined, text: job.workerName!),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusStyle.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(statusStyle.label, style: DashboardText.body(size: 11, weight: FontWeight.w700, color: statusStyle.color)),
              ),
              if (job.paymentStatus != 'unpaid') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: DashboardColors.muted.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    _paymentLabel(job.paymentStatus),
                    style: DashboardText.body(size: 11, weight: FontWeight.w700, color: DashboardColors.muted),
                  ),
                ),
              ],
            ],
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: canceling ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: DashboardColors.muted,
                  side: BorderSide(color: DashboardColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: canceling
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text("Cancel Job", style: DashboardText.body(size: 13, weight: FontWeight.w600, color: DashboardColors.muted)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: DashboardColors.muted),
        const SizedBox(width: 4),
        Text(text, style: DashboardText.body(size: 12, color: DashboardColors.muted)),
      ],
    );
  }
}

// ── WORKERS TAB ──────────────────────────────────────────────────────────

class _WorkersTab extends StatefulWidget {
  const _WorkersTab();

  @override
  State<_WorkersTab> createState() => _WorkersTabState();
}

class _WorkersTabState extends State<_WorkersTab> {
  late Future<List<Map<String, dynamic>>> _workersFuture;
  String _skillFilter = 'All';

  @override
  void initState() {
    super.initState();
    _workersFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows =
        await supabase.from('profiles').select().eq('role', 'worker').eq('status', 'active').order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _workersFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: DashboardColors.primary,
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _workersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
          }
          if (snapshot.hasError) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: DashboardStateMessage(title: "Couldn't load workers.", message: "${snapshot.error}"),
            );
          }

          final allWorkers = snapshot.data ?? [];
          final skills = <String>{};
          for (final w in allWorkers) {
            final s = (w['skills'] as List?)?.cast<String>() ?? const [];
            skills.addAll(s);
          }
          final skillList = ['All', ...skills.toList()..sort()];
          final workers = _skillFilter == 'All'
              ? allWorkers
              : allWorkers.where((w) => ((w['skills'] as List?)?.cast<String>() ?? const []).contains(_skillFilter)).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text("Workers", style: DashboardText.heading(size: 18, color: Colors.black87)),
              ),
              if (skills.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: skillList.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final s = skillList[i];
                      final selected = s == _skillFilter;
                      return ChoiceChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: (_) => setState(() => _skillFilter = s),
                        selectedColor: DashboardColors.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: selected ? DashboardColors.primary : DashboardColors.border),
                        labelStyle: DashboardText.body(size: 12, weight: FontWeight.w600, color: selected ? Colors.white : Colors.black87),
                      );
                    },
                  ),
                ),
              Expanded(
                child: workers.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: DashboardStateMessage(title: allWorkers.isEmpty ? "No workers yet." : "No workers with this skill."),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: workers.length,
                        itemBuilder: (context, i) => _WorkerCard(worker: workers[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final Map<String, dynamic> worker;
  const _WorkerCard({required this.worker});

  @override
  Widget build(BuildContext context) {
    final firstName = worker['first_name'] as String? ?? '';
    final lastName = worker['last_name'] as String? ?? '';
    final name = "$firstName $lastName".trim();
    final initials = "${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}".toUpperCase();
    final avatarUrl = worker['avatar_url'] as String?;
    final location = worker['location'] as String? ?? '—';
    final available = worker['available'] as bool? ?? false;
    final skills = (worker['skills'] as List?)?.cast<String>() ?? const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: DashboardColors.primary,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null ? Text(initials, style: DashboardText.heading(size: 16, color: Colors.white)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: DashboardText.heading(size: 15, color: Colors.black87))),
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: available ? DashboardColors.statusCompleted : DashboardColors.muted, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      available ? "Available" : "Unavailable",
                      style: DashboardText.body(
                        size: 11,
                        weight: FontWeight.w600,
                        color: available ? DashboardColors.statusCompleted : DashboardColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                _MetaText(icon: Icons.location_on_outlined, text: location),
                if (skills.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: skills
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: DashboardColors.bg, borderRadius: BorderRadius.circular(20)),
                              child: Text(s, style: DashboardText.body(size: 11, color: DashboardColors.muted)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── PROFILE TAB ──────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileStats {
  final int posted;
  final int completed;
  final int active;
  const _ProfileStats({required this.posted, required this.completed, required this.active});
}

class _ProfileData {
  final Map<String, dynamic> profile;
  final _ProfileStats stats;
  const _ProfileData({required this.profile, required this.stats});
}

String _formatMemberSince(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[d.month - 1]} ${d.year}';
}

/// Formats digits into a PH mobile-style "0917 123 4567" grouping as the
/// user types, capped at 11 digits.
class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.substring(0, digits.length > 11 ? 11 : digits.length);
    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 4 || i == 7) buffer.write(' ');
      buffer.write(capped[i]);
    }
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}

class _ProfileTabState extends State<_ProfileTab> {
  late Future<_ProfileData> _profileFuture;
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _uploadingAvatar = false;
  bool _savingInfo = false;
  String? _infoError;
  String? _infoSuccess;
  String? _avatarUrlOverride;

  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _changingPassword = false;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _profileFuture = _load();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<_ProfileData> _load() async {
    final userId = supabase.auth.currentUser!.id;
    final row = await supabase.from('profiles').select().eq('id', userId).single();
    final jobRows = await supabase.from('jobs').select('status').eq('client_id', userId);
    final jobs = (jobRows as List).cast<Map<String, dynamic>>();

    _firstNameCtrl.text = row['first_name'] as String? ?? '';
    _lastNameCtrl.text = row['last_name'] as String? ?? '';
    _phoneCtrl.text = row['phone'] as String? ?? '';
    _addressCtrl.text = row['location'] as String? ?? '';

    return _ProfileData(
      profile: row,
      stats: _ProfileStats(
        posted: jobs.length,
        completed: jobs.where((j) => j['status'] == 'completed').length,
        active: jobs.where((j) => j['status'] == 'accepted' || j['status'] == 'arrived' || j['status'] == 'in_progress').length,
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final path = '$userId/avatar.$ext';

      await supabase.storage.from('avatars').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
      final url = supabase.storage.from('avatars').getPublicUrl(path);
      // Same path every re-upload (upsert), so cache-bust the URL we store —
      // otherwise NetworkImage/browser caching keeps showing the old photo.
      final bustedUrl = "$url?t=${DateTime.now().millisecondsSinceEpoch}";

      await supabase.from('profiles').update({'avatar_url': bustedUrl}).eq('id', userId);

      if (!mounted) return;
      setState(() {
        _avatarUrlOverride = bustedUrl;
        _uploadingAvatar = false;
      });
    } on StorageException catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload failed. Please try again.")));
    }
  }

  Future<void> _saveInfo() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _infoError = "First and last name can't be empty.");
      return;
    }
    if (address.isEmpty) {
      setState(() => _infoError = "Address can't be empty.");
      return;
    }
    setState(() {
      _savingInfo = true;
      _infoError = null;
      _infoSuccess = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').update({
        'first_name': firstName,
        'last_name': lastName,
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'location': address,
      }).eq('id', userId);
      if (!mounted) return;
      setState(() {
        _savingInfo = false;
        _infoSuccess = "Changes saved.";
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _savingInfo = false;
        _infoError = e.message;
      });
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;
    setState(() => _passwordError = null);

    if (current.isEmpty) {
      setState(() => _passwordError = "Enter your current password.");
      return;
    }
    if (newPass.length < 6) {
      setState(() => _passwordError = "New password must be at least 6 characters.");
      return;
    }
    if (newPass != confirm) {
      setState(() => _passwordError = "New passwords don't match.");
      return;
    }

    setState(() => _changingPassword = true);
    try {
      final email = supabase.auth.currentUser!.email!;
      // Verify the current password is actually correct by re-authenticating
      // with it before allowing the change — Supabase's updateUser() would
      // otherwise happily change the password of an already-open session
      // without ever checking the "current" one the user typed.
      await supabase.auth.signInWithPassword(email: email, password: current);
      await supabase.auth.updateUser(UserAttributes(password: newPass));
      if (!mounted) return;
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _changingPassword = false;
        _passwordError = e.message.toLowerCase().contains('invalid login credentials') ? "Current password is incorrect." : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _changingPassword = false;
        _passwordError = "Something went wrong. Please try again.";
      });
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfileData>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
        }
        if (snapshot.hasError) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: DashboardStateMessage(title: "Couldn't load your profile.", message: "${snapshot.error}"),
          );
        }

        final p = snapshot.data!.profile;
        final stats = snapshot.data!.stats;
        final firstName = p['first_name'] as String? ?? '';
        final lastName = p['last_name'] as String? ?? '';
        final initials = "${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}".toUpperCase();
        final avatarUrl = _avatarUrlOverride ?? p['avatar_url'] as String?;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: DashboardColors.primary,
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null ? Text(initials, style: DashboardText.heading(size: 26, color: Colors.white)) : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: DashboardColors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: _uploadingAvatar
                                  ? const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.camera_alt, size: 15, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text("$firstName $lastName", style: DashboardText.heading(size: 18, color: Colors.black87)),
                    Text(
                      "Client · Member since ${_formatMemberSince(p['created_at'] as String?)}",
                      style: DashboardText.body(size: 13, color: DashboardColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: DashboardStatCard(value: "${stats.posted}", label: "Jobs Posted", accentColor: DashboardColors.statOpen)),
                  const SizedBox(width: 10),
                  Expanded(child: DashboardStatCard(value: "${stats.completed}", label: "Completed", accentColor: DashboardColors.statCompleted)),
                  const SizedBox(width: 10),
                  Expanded(child: DashboardStatCard(value: "${stats.active}", label: "Active", accentColor: DashboardColors.statActive)),
                ],
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DashboardColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Personal Info", style: DashboardText.heading(size: 15, color: Colors.black87)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _firstNameCtrl,
                      onChanged: (_) => setState(() {
                        _infoError = null;
                        _infoSuccess = null;
                      }),
                      style: DashboardText.body(size: 14, color: Colors.black87),
                      decoration: dashboardInputDecoration(label: "First Name"),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _lastNameCtrl,
                      onChanged: (_) => setState(() {
                        _infoError = null;
                        _infoSuccess = null;
                      }),
                      style: DashboardText.body(size: 14, color: Colors.black87),
                      decoration: dashboardInputDecoration(label: "Last Name"),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      enabled: false,
                      controller: TextEditingController(text: p['email'] as String? ?? ''),
                      style: DashboardText.body(size: 14, color: Colors.black87),
                      decoration: dashboardInputDecoration(label: "Email"),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_PhoneInputFormatter()],
                      onChanged: (_) => setState(() {
                        _infoError = null;
                        _infoSuccess = null;
                      }),
                      style: DashboardText.body(size: 14, color: Colors.black87),
                      decoration: dashboardInputDecoration(label: "Phone", hint: "0917 123 4567"),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _addressCtrl,
                      onChanged: (_) => setState(() {
                        _infoError = null;
                        _infoSuccess = null;
                      }),
                      style: DashboardText.body(size: 14, color: Colors.black87),
                      decoration: dashboardInputDecoration(label: "Address", hint: "City, Province"),
                    ),
                    if (_infoError != null) ...[
                      const SizedBox(height: 10),
                      Text(_infoError!, style: DashboardText.body(size: 12, color: const Color(0xFFC62828))),
                    ],
                    if (_infoSuccess != null) ...[
                      const SizedBox(height: 10),
                      Text(_infoSuccess!, style: DashboardText.body(size: 12, color: DashboardColors.statusCompleted)),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: _savingInfo ? null : _saveInfo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DashboardColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _savingInfo
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text("Save Changes", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DashboardColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Change Password", style: DashboardText.heading(size: 15, color: Colors.black87)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _currentPassCtrl,
                      obscureText: true,
                      onChanged: (_) => setState(() => _passwordError = null),
                      style: DashboardText.body(size: 14, color: Colors.black87),
                      decoration: dashboardInputDecoration(label: "Current Password"),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _newPassCtrl,
                      obscureText: true,
                      onChanged: (_) => setState(() => _passwordError = null),
                      style: DashboardText.body(size: 14, color: Colors.black87),
                      decoration: dashboardInputDecoration(label: "New Password"),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirmPassCtrl,
                      obscureText: true,
                      onChanged: (_) => setState(() => _passwordError = null),
                      onSubmitted: (_) => _changePassword(),
                      style: DashboardText.body(size: 14, color: Colors.black87),
                      decoration: dashboardInputDecoration(label: "Confirm New Password"),
                    ),
                    if (_passwordError != null) ...[
                      const SizedBox(height: 10),
                      Text(_passwordError!, style: DashboardText.body(size: 12, color: const Color(0xFFC62828))),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: _changingPassword ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DashboardColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _changingPassword
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text("Update Password", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 17, color: Color(0xFFC62828)),
                  label: Text("Log Out", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: const Color(0xFFC62828))),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFC62828))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
