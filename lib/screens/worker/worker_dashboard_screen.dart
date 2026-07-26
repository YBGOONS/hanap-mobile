import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../models/categories.dart';
import '../../models/job.dart';
import '../../theme/dashboard_theme.dart';
import '../../widgets/dashboard/dashboard_widgets.dart';
import '../../widgets/dashboard/worker_job_card.dart';
import '../public/home_screen.dart';
import '../shared/conversations_screen.dart';
import '../shared/notifications_screen.dart';

/// Worker Dashboard — mobile adaptation of the React WorkerDashboard,
/// re-themed to DashboardColors and mirroring Client Dashboard's bottom-nav
/// shell pattern. "Available Jobs" and "My Jobs" are `_Tab` cases rather
/// than pushed routes, so the bottom nav's "Jobs" icon stays selected
/// across both sub-views. "Inbox" opens a sheet with Messages (per-job
/// chat) and Notifications, same shared screens Client Dashboard uses.
class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

enum _Tab { dashboard, availableJobs, myJobs, earnings, profile }

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  _Tab _tab = _Tab.dashboard;
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
          (icon: Icons.list_alt_outlined, label: "Available Jobs", onTap: () => setState(() => _tab = _Tab.availableJobs)),
          (icon: Icons.work_outline, label: "My Jobs", onTap: () => setState(() => _tab = _Tab.myJobs)),
        ],
      ),
    );
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
          _Tab.dashboard => const _WorkerDashboardTab(),
          _Tab.availableJobs => _AvailableJobsTab(onAccepted: () => setState(() => _tab = _Tab.myJobs)),
          _Tab.myJobs => const _MyJobsTab(),
          _Tab.earnings => const _EarningsTab(),
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
          _Tab.availableJobs || _Tab.myJobs => 1,
          _Tab.earnings => 2,
          _Tab.profile => 4,
        },
        onTap: (i) {
          switch (i) {
            case 0:
              setState(() => _tab = _Tab.dashboard);
            case 1:
              _openJobsSheet();
            case 2:
              setState(() => _tab = _Tab.earnings);
            case 3:
              _openInboxSheet();
            case 4:
              setState(() => _tab = _Tab.profile);
          }
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Dashboard"),
          const BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: "Jobs"),
          const BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), label: "Earnings"),
          BottomNavigationBarItem(icon: _InboxIcon(hasUnread: _hasUnread), label: "Inbox"),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
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

// ── DASHBOARD TAB ────────────────────────────────────────────────────────

class _WorkerDashboardData {
  final String firstName;
  final bool available;
  final int openCount;
  final int activeCount;
  final int completedCount;

  const _WorkerDashboardData({
    required this.firstName,
    required this.available,
    required this.openCount,
    required this.activeCount,
    required this.completedCount,
  });
}

class _WorkerDashboardTab extends StatefulWidget {
  const _WorkerDashboardTab();

  @override
  State<_WorkerDashboardTab> createState() => _WorkerDashboardTabState();
}

class _WorkerDashboardTabState extends State<_WorkerDashboardTab> {
  late Future<_WorkerDashboardData> _dataFuture;
  bool? _availableOverride;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_WorkerDashboardData> _load() async {
    final userId = supabase.auth.currentUser!.id;

    final profileRow = await supabase.from('profiles').select('first_name, available').eq('id', userId).single();
    final openRows = await supabase.from('jobs').select('id').eq('status', 'open');
    final myRows = await supabase.from('jobs').select('id, status').eq('worker_id', userId);
    final myList = (myRows as List).cast<Map<String, dynamic>>();

    return _WorkerDashboardData(
      firstName: profileRow['first_name'] as String,
      available: profileRow['available'] as bool,
      openCount: (openRows as List).length,
      activeCount: myList.where((j) => j['status'] == 'accepted' || j['status'] == 'arrived' || j['status'] == 'in_progress').length,
      completedCount: myList.where((j) => j['status'] == 'completed').length,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _dataFuture = future;
      _availableOverride = null;
    });
    await future;
  }

  Future<void> _toggleAvailable(bool value) async {
    final userId = supabase.auth.currentUser!.id;
    setState(() {
      _availableOverride = value;
      _toggling = true;
    });
    try {
      await supabase.from('profiles').update({'available': value}).eq('id', userId);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _availableOverride = !value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: DashboardColors.primary,
      onRefresh: _refresh,
      child: FutureBuilder<_WorkerDashboardData>(
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
          final available = _availableOverride ?? data.available;
          final stats = [
            (label: "Available", value: "${data.openCount}", color: DashboardColors.statOpen),
            (label: "Active", value: "${data.activeCount}", color: DashboardColors.statActive),
            (label: "Completed", value: "${data.completedCount}", color: DashboardColors.statCompleted),
          ];

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardHeaderCard(
                  title: "Worker Dashboard",
                  greetingName: data.firstName,
                  subtitle: "Here's your job overview.",
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DashboardColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Available for Jobs", style: DashboardText.heading(size: 14, color: Colors.black87)),
                            const SizedBox(height: 2),
                            Text(
                              available ? "You'll be shown new job postings." : "You won't be shown new job postings.",
                              style: DashboardText.body(size: 12, color: DashboardColors.muted),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: available,
                        onChanged: _toggling ? null : _toggleAvailable,
                        activeThumbColor: DashboardColors.accent,
                      ),
                    ],
                  ),
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
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── AVAILABLE JOBS TAB ───────────────────────────────────────────────────

class _AvailableJobsTab extends StatefulWidget {
  final VoidCallback onAccepted;
  const _AvailableJobsTab({required this.onAccepted});

  @override
  State<_AvailableJobsTab> createState() => _AvailableJobsTabState();
}

class _AvailableJobsTabState extends State<_AvailableJobsTab> {
  late Future<List<Job>> _jobsFuture;
  String _selectedCategory = 'All';
  String? _actingOnJobId;

  @override
  void initState() {
    super.initState();
    _jobsFuture = _load();
  }

  Future<List<Job>> _load() async {
    final userId = supabase.auth.currentUser!.id;
    final profileRow = await supabase.from('profiles').select('skills').eq('id', userId).single();
    final mySkills = ((profileRow['skills'] as List?)?.cast<String>() ?? const []).toSet();

    final rows = await supabase
        .from('jobs')
        .select('*, client:profiles!jobs_client_id_fkey(first_name,last_name)')
        .eq('status', 'open')
        .order('created_at', ascending: false);
    final allJobs = (rows as List).map((r) => Job.fromMap(r as Map<String, dynamic>)).toList();

    // No skills set yet (e.g. hasn't touched the Profile tab) — show
    // everything rather than an empty list that looks broken.
    if (mySkills.isEmpty) return allJobs;
    return allJobs.where((j) => mySkills.contains(j.category)).toList();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _jobsFuture = future);
    await future;
  }

  Future<void> _accept(Job job) async {
    setState(() => _actingOnJobId = job.id);
    try {
      await supabase.rpc('accept_job', params: {'job_id': job.id});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Job accepted! \"${job.category}\" is now in My Jobs.")),
      );
      await _refresh();
      if (!mounted) return;
      widget.onAccepted();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // Most likely cause of a failure here: someone else took the job
      // between this list loading and the tap. Refresh so the now-stale
      // entry disappears instead of sitting there to be retried and fail
      // again with the same confusing message.
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actingOnJobId = null);
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
              child: DashboardStateMessage(title: "Couldn't load the jobs.", message: "${snapshot.error}"),
            );
          }

          final allJobs = snapshot.data ?? [];
          final categories = ['All', ...{for (final j in allJobs) j.category}];
          final jobs = _selectedCategory == 'All' ? allJobs : allJobs.where((j) => j.category == _selectedCategory).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text("Available Jobs", style: DashboardText.heading(size: 18, color: Colors.black87)),
              ),
              if (allJobs.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final cat = categories[i];
                      final selected = cat == _selectedCategory;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
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
                          title: allJobs.isEmpty ? "No open jobs right now" : "No jobs in this category",
                          message: allJobs.isEmpty ? "Check back later for new job postings." : null,
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: jobs.length,
                        itemBuilder: (context, i) {
                          final job = jobs[i];
                          final acting = _actingOnJobId == job.id;
                          return WorkerAvailableJobCard(
                            title: job.category,
                            description: job.description,
                            budget: job.budget,
                            location: job.location,
                            clientName: job.clientName,
                            scheduledDate: job.scheduledDate,
                            actions: SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: ElevatedButton(
                                onPressed: acting ? null : () => _accept(job),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DashboardColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: acting
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text("Accept Job", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
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

// ── MY JOBS TAB ──────────────────────────────────────────────────────────

class _MyJobsTab extends StatefulWidget {
  const _MyJobsTab();

  @override
  State<_MyJobsTab> createState() => _MyJobsTabState();
}

class _MyJobsTabState extends State<_MyJobsTab> {
  late Future<List<Job>> _jobsFuture;
  String? _actingOnJobId;

  @override
  void initState() {
    super.initState();
    _jobsFuture = _load();
  }

  Future<List<Job>> _load() async {
    final userId = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('jobs')
        .select('*, client:profiles!jobs_client_id_fkey(first_name,last_name)')
        .eq('worker_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Job.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _jobsFuture = future);
    await future;
  }

  Future<void> _updateStatus(Job job, String newStatus) async {
    setState(() => _actingOnJobId = job.id);
    try {
      await supabase.rpc('update_job_status', params: {'job_id': job.id, 'new_status': newStatus});
      if (!mounted) return;
      await _refresh();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actingOnJobId = null);
    }
  }

  Future<void> _cancel(Job job) async {
    final reason = await showReasonDialog(
      context,
      title: "Can't do this job?",
      hint: "Why can't you do this job?",
      confirmLabel: "Submit",
    );
    if (reason == null || !mounted) return;

    setState(() => _actingOnJobId = job.id);
    try {
      await supabase.rpc('cancel_job', params: {'job_id': job.id, 'reason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Job returned to the open pool.")));
      await _refresh();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actingOnJobId = null);
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
              child: DashboardStateMessage(title: "Couldn't load the jobs.", message: "${snapshot.error}"),
            );
          }

          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: const DashboardStateMessage(
                title: "You haven't taken any jobs yet",
                message: "Check \"Available Jobs\" to find work.",
              ),
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text("My Jobs", style: DashboardText.heading(size: 18, color: Colors.black87)),
              const SizedBox(height: 12),
              for (final job in jobs) _buildJobCard(job),
            ],
          );
        },
      ),
    );
  }

  Widget _primaryActionWithCancel({required Job job, required bool acting, required String label, required String targetStatus}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton(
            onPressed: acting ? null : () => _updateStatus(job, targetStatus),
            style: ElevatedButton.styleFrom(
              backgroundColor: DashboardColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: acting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(label, style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
          ),
        ),
        TextButton(
          onPressed: acting ? null : () => _cancel(job),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
          child: Text("Can't do this job", style: DashboardText.body(size: 12, weight: FontWeight.w600, color: const Color(0xFFC62828))),
        ),
      ],
    );
  }

  Widget _buildJobCard(Job job) {
    final acting = _actingOnJobId == job.id;
    Widget? actions;

    if (job.status == 'accepted') {
      actions = _primaryActionWithCancel(job: job, acting: acting, label: "Mark Arrived", targetStatus: 'arrived');
    } else if (job.status == 'arrived') {
      actions = _primaryActionWithCancel(job: job, acting: acting, label: "Start Job", targetStatus: 'in_progress');
    } else if (job.status == 'in_progress') {
      final dateReached = job.scheduledDate == null || !job.scheduledDate!.isAfter(DateTime.now());
      if (dateReached) {
        actions = SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton(
            onPressed: acting ? null : () => _updateStatus(job, 'completed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DashboardColors.statusCompleted,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: acting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text("Mark Completed", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
          ),
        );
      } else {
        actions = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: DashboardColors.bg,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: DashboardColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 15, color: DashboardColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Scheduled for ${job.scheduledDate!.year}-${job.scheduledDate!.month.toString().padLeft(2, '0')}-${job.scheduledDate!.day.toString().padLeft(2, '0')}",
                  style: DashboardText.body(size: 12, color: DashboardColors.muted),
                ),
              ),
            ],
          ),
        );
      }
    }

    return WorkerMyJobCard(
      title: job.category,
      budget: job.budget,
      location: job.location,
      clientName: job.clientName,
      status: job.status,
      actions: actions,
    );
  }
}

// ── EARNINGS TAB ─────────────────────────────────────────────────────────

class _EarningsData {
  final int doneCount;
  final int inProgressCount;
  final int totalCount;
  final double totalEarned;
  final List<Map<String, dynamic>> transactions;

  const _EarningsData({
    required this.doneCount,
    required this.inProgressCount,
    required this.totalCount,
    required this.totalEarned,
    required this.transactions,
  });
}

class _EarningsTab extends StatefulWidget {
  const _EarningsTab();

  @override
  State<_EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<_EarningsTab> {
  late Future<_EarningsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_EarningsData> _load() async {
    final userId = supabase.auth.currentUser!.id;
    final jobRows = ((await supabase.from('jobs').select('id, status').eq('worker_id', userId)) as List).cast<Map<String, dynamic>>();

    final txRows = ((await supabase
            .from('transactions')
            .select('type, amount, created_at, job:jobs(category)')
            .eq('worker_id', userId)
            .order('created_at', ascending: false)) as List)
        .cast<Map<String, dynamic>>();

    final earned = txRows.where((t) => t['type'] == 'payment').fold<double>(0, (sum, t) => sum + (t['amount'] as num).toDouble());
    final refunded = txRows.where((t) => t['type'] == 'refund').fold<double>(0, (sum, t) => sum + (t['amount'] as num).toDouble());

    return _EarningsData(
      doneCount: jobRows.where((j) => j['status'] == 'completed').length,
      inProgressCount: jobRows.where((j) => j['status'] == 'accepted' || j['status'] == 'arrived' || j['status'] == 'in_progress').length,
      totalCount: jobRows.length,
      totalEarned: earned - refunded,
      transactions: txRows,
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
      child: FutureBuilder<_EarningsData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
          }
          if (snapshot.hasError) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: DashboardStateMessage(title: "Couldn't load your earnings.", message: "${snapshot.error}"),
            );
          }

          final data = snapshot.data!;
          final stats = [
            (label: "Jobs Done", value: "${data.doneCount}", color: DashboardColors.statCompleted),
            (label: "In Progress", value: "${data.inProgressCount}", color: DashboardColors.statActive),
            (label: "Total Jobs", value: "${data.totalCount}", color: DashboardColors.statOpen),
          ];

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("My Earnings", style: DashboardText.heading(size: 18, color: Colors.black87)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [DashboardColors.primary, DashboardColors.primaryGradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total Earned", style: DashboardText.body(size: 12, weight: FontWeight.w600, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text("₱${data.totalEarned.toStringAsFixed(0)}", style: DashboardText.heading(size: 28, color: Colors.white)),
                    ],
                  ),
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
                Text("Payment History", style: DashboardText.heading(size: 15, color: Colors.black87)),
                const SizedBox(height: 10),
                if (data.transactions.isEmpty)
                  Text("No payments yet.", style: DashboardText.body(size: 13, color: DashboardColors.muted))
                else
                  for (final tx in data.transactions) _PaymentHistoryItem(tx: tx),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaymentHistoryItem extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _PaymentHistoryItem({required this.tx});

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(tx['created_at'] as String? ?? '');
    final dateLabel =
        createdAt == null ? '' : "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}";
    final amount = (tx['amount'] as num).toDouble();
    final isRefund = tx['type'] == 'refund';
    final job = tx['job'] as Map<String, dynamic>?;

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
                Text(job?['category'] as String? ?? '—', style: DashboardText.heading(size: 14, weight: FontWeight.w700, color: Colors.black87)),
                const SizedBox(height: 3),
                Text(dateLabel, style: DashboardText.body(size: 12, color: DashboardColors.muted)),
              ],
            ),
          ),
          Text(
            "${isRefund ? '-' : '+'}₱${amount.toStringAsFixed(0)}",
            style: DashboardText.heading(size: 15, color: isRefund ? const Color(0xFFC62828) : DashboardColors.statusCompleted),
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

class _ProfileTabState extends State<_ProfileTab> {
  late Future<Map<String, dynamic>> _profileFuture;
  final _locationCtrl = TextEditingController();
  Set<String> _selectedSkills = {};
  bool _uploadingAvatar = false;
  bool _savingLocation = false;
  bool _savingSkills = false;
  String? _locationError;
  String? _locationSuccess;
  String? _skillsSuccess;
  String? _avatarUrlOverride;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final userId = supabase.auth.currentUser!.id;
    final row = await supabase.from('profiles').select().eq('id', userId).single();
    _locationCtrl.text = row['location'] as String? ?? '';
    _selectedSkills = ((row['skills'] as List?)?.cast<String>() ?? const []).toSet();
    return row;
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

  Future<void> _saveLocation() async {
    final location = _locationCtrl.text.trim();
    if (location.isEmpty) {
      setState(() => _locationError = "Location can't be empty.");
      return;
    }
    setState(() {
      _savingLocation = true;
      _locationError = null;
      _locationSuccess = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').update({'location': location}).eq('id', userId);
      if (!mounted) return;
      setState(() {
        _savingLocation = false;
        _locationSuccess = "Location updated.";
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _savingLocation = false;
        _locationError = e.message;
      });
    }
  }

  Future<void> _saveSkills() async {
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pick at least one skill.")));
      return;
    }
    setState(() {
      _savingSkills = true;
      _skillsSuccess = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').update({'skills': _selectedSkills.toList()}).eq('id', userId);
      if (!mounted) return;
      setState(() {
        _savingSkills = false;
        _skillsSuccess = "Skills updated.";
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _savingSkills = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
    return FutureBuilder<Map<String, dynamic>>(
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

        final p = snapshot.data!;
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
                    Text(p['email'] as String? ?? '', style: DashboardText.body(size: 13, color: DashboardColors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DashboardColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Location", style: DashboardText.body(size: 12, weight: FontWeight.w700, color: DashboardColors.muted)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationCtrl,
                      onChanged: (_) => setState(() {
                        _locationError = null;
                        _locationSuccess = null;
                      }),
                      style: DashboardText.body(size: 14, color: Colors.black87),
                      decoration: dashboardInputDecoration(label: "Location", hint: "City, Province"),
                    ),
                    if (_locationError != null) ...[
                      const SizedBox(height: 8),
                      Text(_locationError!, style: DashboardText.body(size: 12, color: const Color(0xFFC62828))),
                    ],
                    if (_locationSuccess != null) ...[
                      const SizedBox(height: 8),
                      Text(_locationSuccess!, style: DashboardText.body(size: 12, color: DashboardColors.statusCompleted)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: _savingLocation ? null : _saveLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DashboardColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _savingLocation
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text("Save", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
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
                    Text("Skills", style: DashboardText.body(size: 12, weight: FontWeight.w700, color: DashboardColors.muted)),
                    const SizedBox(height: 4),
                    Text(
                      "Pick everything you're able to do — clients filter Available Jobs by these.",
                      style: DashboardText.body(size: 12, color: DashboardColors.muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kCategories.map((c) {
                        final selected = _selectedSkills.contains(c);
                        return FilterChip(
                          label: Text(c),
                          selected: selected,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selectedSkills.add(c);
                            } else {
                              _selectedSkills.remove(c);
                            }
                            _skillsSuccess = null;
                          }),
                          selectedColor: DashboardColors.primary,
                          checkmarkColor: Colors.white,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: selected ? DashboardColors.primary : DashboardColors.border),
                          labelStyle: DashboardText.body(size: 12, weight: FontWeight.w600, color: selected ? Colors.white : Colors.black87),
                        );
                      }).toList(),
                    ),
                    if (_skillsSuccess != null) ...[
                      const SizedBox(height: 10),
                      Text(_skillsSuccess!, style: DashboardText.body(size: 12, color: DashboardColors.statusCompleted)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: _savingSkills ? null : _saveSkills,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DashboardColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _savingSkills
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text("Save Skills", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
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
