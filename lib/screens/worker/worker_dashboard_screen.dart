import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../models/categories.dart';
import '../../models/job.dart';
import '../../theme/dashboard_theme.dart';
import '../../utils/validators.dart';
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
/// Below [dashboardWideBreakpoint], the shell becomes a left
/// [DashboardSidebar] instead of the bottom nav — same as Client and Admin.
class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

enum _Tab { dashboard, availableJobs, myJobs, earnings, profile }

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  _Tab _tab = _Tab.dashboard;
  bool _hasUnreadNotif = false;
  bool _hasUnreadMessages = false;
  bool get _hasUnread => _hasUnreadNotif || _hasUnreadMessages;
  String? _firstName;

  @override
  void initState() {
    super.initState();
    _checkUnread();
    _loadFirstName();
  }

  Future<void> _loadFirstName() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final row = await supabase
        .from('profiles')
        .select('first_name')
        .eq('id', userId)
        .single();
    if (!mounted) return;
    setState(() => _firstName = row['first_name'] as String);
  }

  Future<void> _checkUnread() async {
    final userId = supabase.auth.currentUser!.id;

    final notifRows = await supabase
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .isFilter('read_at', null)
        .limit(1);
    final hasUnreadNotif = (notifRows as List).isNotEmpty;

    final jobRows = await supabase
        .from('jobs')
        .select('id')
        .or('client_id.eq.$userId,worker_id.eq.$userId')
        .not('worker_id', 'is', null);
    final jobIds = (jobRows as List).map((r) => r['id'] as String).toList();
    bool hasUnreadMessages = false;
    if (jobIds.isNotEmpty) {
      final msgRows = await supabase
          .from('messages')
          .select('id')
          .inFilter('job_id', jobIds)
          .neq('sender_id', userId)
          .isFilter('read_at', null)
          .limit(1);
      hasUnreadMessages = (msgRows as List).isNotEmpty;
    }

    if (mounted) {
      setState(() {
        _hasUnreadNotif = hasUnreadNotif;
        _hasUnreadMessages = hasUnreadMessages;
      });
    }
  }

  void _openJobsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ActionSheet(
        items: [
          (
            icon: Icons.list_alt_outlined,
            label: "Available Jobs",
            hasUnread: false,
            onTap: () => setState(() => _tab = _Tab.availableJobs),
          ),
          (
            icon: Icons.work_outline,
            label: "My Jobs",
            hasUnread: false,
            onTap: () => setState(() => _tab = _Tab.myJobs),
          ),
        ],
      ),
    );
  }

  void _openInboxSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ActionSheet(
        items: [
          (
            icon: Icons.chat_bubble_outline,
            label: "Messages",
            hasUnread: _hasUnreadMessages,
            onTap: () => _openInboxScreen(const ConversationsScreen()),
          ),
          (
            icon: Icons.notifications_outlined,
            label: "Notifications",
            hasUnread: _hasUnreadNotif,
            onTap: () => _openInboxScreen(const NotificationsScreen()),
          ),
        ],
      ),
    );
  }

  Future<void> _openInboxScreen(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _checkUnread();
  }

  Widget _content() => switch (_tab) {
    _Tab.dashboard => const _WorkerDashboardTab(),
    _Tab.availableJobs => _AvailableJobsTab(
      onAccepted: () => setState(() => _tab = _Tab.myJobs),
    ),
    _Tab.myJobs => const _MyJobsTab(),
    _Tab.earnings => const _EarningsTab(),
    _Tab.profile => const _ProfileTab(),
  };

  List<SidebarDestination> _sidebarDestinations() => [
    SidebarDestination(
      icon: Icons.home_outlined,
      label: "Dashboard",
      selected: _tab == _Tab.dashboard,
      onTap: () => setState(() => _tab = _Tab.dashboard),
    ),
    SidebarDestination(
      icon: Icons.list_alt_outlined,
      label: "Available Jobs",
      selected: _tab == _Tab.availableJobs,
      onTap: () => setState(() => _tab = _Tab.availableJobs),
    ),
    SidebarDestination(
      icon: Icons.work_outline,
      label: "My Jobs",
      selected: _tab == _Tab.myJobs,
      onTap: () => setState(() => _tab = _Tab.myJobs),
    ),
    SidebarDestination(
      icon: Icons.payments_outlined,
      label: "Earnings",
      selected: _tab == _Tab.earnings,
      onTap: () => setState(() => _tab = _Tab.earnings),
    ),
    SidebarDestination(
      icon: Icons.chat_bubble_outline,
      label: "Messages",
      trailing: _hasUnreadMessages ? const _UnreadDot() : null,
      onTap: () => _openInboxScreen(const ConversationsScreen()),
    ),
    SidebarDestination(
      icon: Icons.notifications_outlined,
      label: "Notifications",
      trailing: _hasUnreadNotif ? const _UnreadDot() : null,
      onTap: () => _openInboxScreen(const NotificationsScreen()),
    ),
    SidebarDestination(
      icon: Icons.person_outline,
      label: "Profile",
      selected: _tab == _Tab.profile,
      onTap: () => setState(() => _tab = _Tab.profile),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SafeArea(child: _content());
        if (constraints.maxWidth >= dashboardWideBreakpoint) {
          return Scaffold(
            backgroundColor: DashboardColors.bg,
            body: Row(
              children: [
                DashboardSidebar(
                  greeting: _firstName == null
                      ? "Worker Portal"
                      : "Hi, $_firstName",
                  destinations: _sidebarDestinations(),
                ),
                Expanded(child: content),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: DashboardColors.bg,
          body: content,
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
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: "Dashboard",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.work_outline),
                label: "Jobs",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.payments_outlined),
                label: "Earnings",
              ),
              BottomNavigationBarItem(
                icon: _InboxIcon(hasUnread: _hasUnread),
                label: "Inbox",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: "Profile",
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small standalone unread-badge dot, used as a [SidebarDestination.trailing].
class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: DashboardColors.accent,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  final List<
    ({IconData icon, String label, bool hasUnread, VoidCallback? onTap})
  >
  items;
  const _ActionSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items
              .map(
                (item) => ListTile(
                  leading: Icon(item.icon, color: DashboardColors.primary),
                  title: Row(
                    children: [
                      Text(
                        item.label,
                        style: DashboardText.body(
                          size: 15,
                          weight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (item.hasUnread) ...[
                        const SizedBox(width: 7),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: DashboardColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    item.onTap?.call();
                  },
                ),
              )
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
              decoration: const BoxDecoration(
                color: DashboardColors.accent,
                shape: BoxShape.circle,
              ),
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
  final double? avgRating;
  final int ratingCount;

  const _WorkerDashboardData({
    required this.firstName,
    required this.available,
    required this.openCount,
    required this.activeCount,
    required this.completedCount,
    required this.avgRating,
    required this.ratingCount,
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

    final profileRow = await supabase
        .from('profiles')
        .select('first_name, available, skills')
        .eq('id', userId)
        .single();
    final mySkills =
        ((profileRow['skills'] as List?)?.cast<String>() ?? const []).toSet();
    // Matches _AvailableJobsTab's own filtering (skill match, or everything
    // if no skills set yet) — otherwise this count disagrees with what the
    // Available Jobs tab actually shows when tapped.
    final openRows = await supabase
        .from('jobs')
        .select('id, category')
        .eq('status', 'open');
    final openJobs = (openRows as List).cast<Map<String, dynamic>>();
    final openCount = mySkills.isEmpty
        ? openJobs.length
        : openJobs
              .where((j) => mySkills.contains(j['category'] as String))
              .length;
    final myRows = await supabase
        .from('jobs')
        .select('id, status')
        .eq('worker_id', userId);
    final myList = (myRows as List).cast<Map<String, dynamic>>();
    final ratingRows = await supabase
        .from('ratings')
        .select('rating')
        .eq('worker_id', userId);
    final ratings = (ratingRows as List)
        .map((r) => (r as Map<String, dynamic>)['rating'] as int)
        .toList();

    return _WorkerDashboardData(
      firstName: profileRow['first_name'] as String,
      available: profileRow['available'] as bool,
      openCount: openCount,
      activeCount: myList
          .where(
            (j) =>
                j['status'] == 'accepted' ||
                j['status'] == 'arrived' ||
                j['status'] == 'in_progress',
          )
          .length,
      completedCount: myList.where((j) => j['status'] == 'completed').length,
      avgRating: ratings.isEmpty
          ? null
          : ratings.reduce((a, b) => a + b) / ratings.length,
      ratingCount: ratings.length,
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
      await supabase
          .from('profiles')
          .update({'available': value})
          .eq('id', userId);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _availableOverride = !value);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: DashboardColors.primary),
            );
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                DashboardStateMessage(
                  title: "Couldn't load the dashboard.",
                  message: "${snapshot.error}",
                ),
              ],
            );
          }

          final data = snapshot.data!;
          final available = _availableOverride ?? data.available;
          final stats = [
            (
              label: "Available",
              value: "${data.openCount}",
              color: DashboardColors.statOpen,
            ),
            (
              label: "Active",
              value: "${data.activeCount}",
              color: DashboardColors.statActive,
            ),
            (
              label: "Completed",
              value: "${data.completedCount}",
              color: DashboardColors.statCompleted,
            ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                            Text(
                              "Available for Jobs",
                              style: DashboardText.heading(
                                size: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              available
                                  ? "You'll be shown new job postings."
                                  : "You won't be shown new job postings.",
                              style: DashboardText.body(
                                size: 12,
                                color: DashboardColors.muted,
                              ),
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
                        child:
                            DashboardStatCard(
                                  value: stats[i].value,
                                  label: stats[i].label,
                                  accentColor: stats[i].color,
                                )
                                .animate(delay: (i * 80).ms)
                                .fadeIn(duration: 280.ms)
                                .slideY(
                                  begin: 0.15,
                                  end: 0,
                                  duration: 280.ms,
                                  curve: Curves.easeOut,
                                ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DashboardColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: DashboardColors.accent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.avgRating != null
                                  ? data.avgRating!.toStringAsFixed(1)
                                  : "No ratings yet",
                              style: DashboardText.heading(
                                size: 16,
                                color: Colors.black87,
                              ),
                            ),
                            if (data.avgRating != null)
                              Text(
                                "${data.ratingCount} review${data.ratingCount == 1 ? '' : 's'}",
                                style: DashboardText.body(
                                  size: 12,
                                  color: DashboardColors.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
    final profileRow = await supabase
        .from('profiles')
        .select('skills')
        .eq('id', userId)
        .single();
    final mySkills =
        ((profileRow['skills'] as List?)?.cast<String>() ?? const []).toSet();

    final rows = await supabase
        .from('jobs')
        .select('*, client:profiles!jobs_client_id_fkey(first_name,last_name)')
        .eq('status', 'open')
        .order('created_at', ascending: false);
    final allJobs = (rows as List)
        .map((r) => Job.fromMap(r as Map<String, dynamic>))
        .toList();

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
        SnackBar(
          content: Text("Job accepted! \"${job.category}\" is now in My Jobs."),
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: DashboardColors.primary),
            );
          }
          if (snapshot.hasError) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: DashboardStateMessage(
                title: "Couldn't load the jobs.",
                message: "${snapshot.error}",
              ),
            );
          }

          final allJobs = snapshot.data ?? [];
          final categories = [
            'All',
            ...{for (final j in allJobs) j.category},
          ];
          final jobs = _selectedCategory == 'All'
              ? allJobs
              : allJobs.where((j) => j.category == _selectedCategory).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  "Available Jobs",
                  style: DashboardText.heading(size: 18, color: Colors.black87),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = categories[i];
                    final selected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                      selectedColor: DashboardColors.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected
                            ? DashboardColors.primary
                            : DashboardColors.border,
                      ),
                      labelStyle: DashboardText.body(
                        size: 12,
                        weight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: jobs.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: DashboardStateMessage(
                          title: allJobs.isEmpty
                              ? "No open jobs right now"
                              : "No jobs in this category",
                          message: allJobs.isEmpty
                              ? "Check back later for new job postings."
                              : null,
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
                                onTap: () => showJobDetailsSheet(context, job),
                                actions: SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: ElevatedButton(
                                    onPressed: acting
                                        ? null
                                        : () => _accept(job),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: DashboardColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: acting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            "Accept Job",
                                            style: DashboardText.body(
                                              size: 13,
                                              weight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              )
                              .animate(delay: (i.clamp(0, 6) * 60).ms)
                              .fadeIn(duration: 260.ms)
                              .slideY(
                                begin: 0.06,
                                end: 0,
                                duration: 260.ms,
                                curve: Curves.easeOut,
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
        .select(
          '*, client:profiles!jobs_client_id_fkey(first_name,last_name), ratings(rating,comment)',
        )
        .eq('worker_id', userId);
    final jobs = (rows as List)
        .map((r) => Job.fromMap(r as Map<String, dynamic>))
        .toList();
    // Same freshest-activity-first ordering as Client's My Jobs.
    jobs.sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return jobs;
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _jobsFuture = future);
    await future;
  }

  Future<void> _updateStatus(Job job, String newStatus) async {
    setState(() => _actingOnJobId = job.id);
    try {
      await supabase.rpc(
        'update_job_status',
        params: {'job_id': job.id, 'new_status': newStatus},
      );
      if (!mounted) return;
      await _refresh();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
      await supabase.rpc(
        'cancel_job',
        params: {'job_id': job.id, 'reason': reason},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Job returned to the open pool.")),
      );
      await _refresh();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actingOnJobId = null);
    }
  }

  Future<void> _verifyOtp(Job job, String otp) async {
    if (otp.trim().length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter the 4-digit code from the client."),
        ),
      );
      return;
    }
    setState(() => _actingOnJobId = job.id);
    try {
      await supabase.rpc(
        'verify_arrival_otp',
        params: {'job_id': job.id, 'otp': otp.trim()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Arrival confirmed!")));
      await _refresh();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actingOnJobId = null);
    }
  }

  Future<void> _completeJob(Job job) async {
    setState(() => _actingOnJobId = job.id);
    try {
      await supabase.rpc('complete_job', params: {'job_id': job.id});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Marked complete! Waiting for the client to confirm."),
        ),
      );
      await _refresh();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: DashboardColors.primary),
            );
          }
          if (snapshot.hasError) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: DashboardStateMessage(
                title: "Couldn't load the jobs.",
                message: "${snapshot.error}",
              ),
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
              Text(
                "My Jobs",
                style: DashboardText.heading(size: 18, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < jobs.length; i++)
                _buildJobCard(jobs[i])
                    .animate(delay: (i.clamp(0, 6) * 60).ms)
                    .fadeIn(duration: 260.ms)
                    .slideY(
                      begin: 0.06,
                      end: 0,
                      duration: 260.ms,
                      curve: Curves.easeOut,
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _primaryActionWithCancel({
    required Job job,
    required bool acting,
    required String label,
    required String targetStatus,
  }) {
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: acting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: DashboardText.body(
                      size: 13,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        TextButton(
          onPressed: acting ? null : () => _cancel(job),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
          ),
          child: Text(
            "Can't do this job",
            style: DashboardText.body(
              size: 12,
              weight: FontWeight.w600,
              color: const Color(0xFFC62828),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lockedActionWithCancel({
    required Job job,
    required bool acting,
    required IconData icon,
    required String message,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoNote(icon: icon, message: message),
        TextButton(
          onPressed: acting ? null : () => _cancel(job),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
          ),
          child: Text(
            "Can't do this job",
            style: DashboardText.body(
              size: 12,
              weight: FontWeight.w600,
              color: const Color(0xFFC62828),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoNote({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DashboardColors.bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: DashboardColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: DashboardColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: DashboardText.body(size: 12, color: DashboardColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Job job) {
    final acting = _actingOnJobId == job.id;
    Widget? actions;

    if (job.status == 'accepted') {
      actions = job.paymentStatus == 'paid'
          ? _ArrivalOtpEntry(
              acting: acting,
              onVerify: (otp) => _verifyOtp(job, otp),
              onCancel: () => _cancel(job),
            )
          : _lockedActionWithCancel(
              job: job,
              acting: acting,
              icon: Icons.hourglass_top,
              message:
                  "Waiting for the client to pay before you can head over.",
            );
    } else if (job.status == 'arrived') {
      actions = _primaryActionWithCancel(
        job: job,
        acting: acting,
        label: "Start Job",
        targetStatus: 'in_progress',
      );
    } else if (job.status == 'in_progress') {
      final dateReached =
          job.scheduledDate == null ||
          !job.scheduledDate!.isAfter(DateTime.now());
      if (dateReached) {
        actions = SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton.icon(
            onPressed: acting ? null : () => _completeJob(job),
            icon: acting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.check_circle_outline,
                    size: 17,
                    color: Colors.white,
                  ),
            label: Text(
              acting ? "Completing..." : "Mark Completed",
              style: DashboardText.body(
                size: 13,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: DashboardColors.statusCompleted,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      } else {
        actions = _infoNote(
          icon: Icons.lock_outline,
          message:
              "Scheduled for ${job.scheduledDate!.year}-${job.scheduledDate!.month.toString().padLeft(2, '0')}-${job.scheduledDate!.day.toString().padLeft(2, '0')}",
        );
      }
    } else if (job.status == 'completed') {
      actions = switch (job.paymentStatus) {
        'paid' => _infoNote(
          icon: Icons.hourglass_top,
          message: "Waiting for the client to review and confirm completion.",
        ),
        'released' => _infoNote(
          icon: Icons.check_circle_outline,
          message:
              "Payment sent: ₱${(job.budget ?? 0).toStringAsFixed(0)} paid to you.",
        ),
        'refund_requested' => _infoNote(
          icon: Icons.report_gmailerrorred_outlined,
          message: "The client requested a refund. Under admin review.",
        ),
        'refunded' => _infoNote(
          icon: Icons.assignment_return_outlined,
          message: "This job was refunded to the client.",
        ),
        _ => null,
      };
    }

    return WorkerMyJobCard(
      title: job.category,
      budget: job.budget,
      location: job.location,
      clientName: job.clientName,
      status: job.status,
      rating: job.rating,
      actions: actions,
      onTap: () => showJobDetailsSheet(context, job),
    );
  }
}

/// Worker's 4-digit arrival-code entry — the code the client sees in-app and
/// hands over in person. A dedicated stateful widget (not inline in
/// _buildJobCard) so the TextEditingController survives the parent's
/// per-job rebuilds cleanly.
class _ArrivalOtpEntry extends StatefulWidget {
  final bool acting;
  final ValueChanged<String> onVerify;
  final VoidCallback onCancel;
  const _ArrivalOtpEntry({
    required this.acting,
    required this.onVerify,
    required this.onCancel,
  });

  @override
  State<_ArrivalOtpEntry> createState() => _ArrivalOtpEntryState();
}

class _ArrivalOtpEntryState extends State<_ArrivalOtpEntry> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: DashboardText.body(
                  size: 16,
                  weight: FontWeight.w700,
                  color: Colors.black87,
                ),
                decoration: dashboardInputDecoration(
                  label: "Arrival Code",
                  hint: "Ask the client",
                ).copyWith(counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: widget.acting
                    ? null
                    : () => widget.onVerify(_controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DashboardColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: widget.acting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        "Verify",
                        style: DashboardText.body(
                          size: 13,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: widget.acting ? null : widget.onCancel,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
          ),
          child: Text(
            "Can't do this job",
            style: DashboardText.body(
              size: 12,
              weight: FontWeight.w600,
              color: const Color(0xFFC62828),
            ),
          ),
        ),
      ],
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
    final jobRows =
        ((await supabase
                    .from('jobs')
                    .select('id, status')
                    .eq('worker_id', userId))
                as List)
            .cast<Map<String, dynamic>>();

    final txRows =
        ((await supabase
                    .from('transactions')
                    .select(
                      'type, amount, worker_amount, created_at, job:jobs(category, payment_status)',
                    )
                    .eq('worker_id', userId)
                    .order('created_at', ascending: false))
                as List)
            .cast<Map<String, dynamic>>();

    // Only count money that's actually been released — an escrowed
    // ('paid') job's transaction row exists but the worker hasn't been
    // paid out yet, and a refunded one never will be.
    final earned = txRows
        .where(
          (t) =>
              t['type'] == 'payment' &&
              (t['job'] as Map<String, dynamic>?)?['payment_status'] ==
                  'released',
        )
        .fold<double>(
          0,
          (sum, t) =>
              sum +
              ((t['worker_amount'] as num?) ?? (t['amount'] as num)).toDouble(),
        );

    return _EarningsData(
      doneCount: jobRows.where((j) => j['status'] == 'completed').length,
      inProgressCount: jobRows
          .where(
            (j) =>
                j['status'] == 'accepted' ||
                j['status'] == 'arrived' ||
                j['status'] == 'in_progress',
          )
          .length,
      totalCount: jobRows.length,
      totalEarned: earned,
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
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: DashboardColors.primary),
            );
          }
          if (snapshot.hasError) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: DashboardStateMessage(
                title: "Couldn't load your earnings.",
                message: "${snapshot.error}",
              ),
            );
          }

          final data = snapshot.data!;
          final stats = [
            (
              label: "Jobs Done",
              value: "${data.doneCount}",
              color: DashboardColors.statCompleted,
            ),
            (
              label: "In Progress",
              value: "${data.inProgressCount}",
              color: DashboardColors.statActive,
            ),
            (
              label: "Total Jobs",
              value: "${data.totalCount}",
              color: DashboardColors.statOpen,
            ),
          ];

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "My Earnings",
                  style: DashboardText.heading(size: 18, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        DashboardColors.primary,
                        DashboardColors.primaryGradientEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Earned",
                        style: DashboardText.body(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "₱${data.totalEarned.toStringAsFixed(0)}",
                        style: DashboardText.heading(
                          size: 28,
                          color: Colors.white,
                        ),
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
                        child:
                            DashboardStatCard(
                                  value: stats[i].value,
                                  label: stats[i].label,
                                  accentColor: stats[i].color,
                                )
                                .animate(delay: (i * 80).ms)
                                .fadeIn(duration: 280.ms)
                                .slideY(
                                  begin: 0.15,
                                  end: 0,
                                  duration: 280.ms,
                                  curve: Curves.easeOut,
                                ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "Payment History",
                  style: DashboardText.heading(size: 15, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                if (data.transactions.isEmpty)
                  Text(
                    "No payments yet.",
                    style: DashboardText.body(
                      size: 13,
                      color: DashboardColors.muted,
                    ),
                  )
                else
                  for (var i = 0; i < data.transactions.length; i++)
                    _PaymentHistoryItem(tx: data.transactions[i])
                        .animate(delay: (i.clamp(0, 6) * 60).ms)
                        .fadeIn(duration: 260.ms)
                        .slideY(
                          begin: 0.06,
                          end: 0,
                          duration: 260.ms,
                          curve: Curves.easeOut,
                        ),
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
    final dateLabel = createdAt == null
        ? ''
        : "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}";
    final isRefund = tx['type'] == 'refund';
    final amount = isRefund
        ? (tx['amount'] as num).toDouble()
        : ((tx['worker_amount'] as num?) ?? (tx['amount'] as num)).toDouble();
    final job = tx['job'] as Map<String, dynamic>?;
    final released = !isRefund && job?['payment_status'] == 'released';
    final statusLabel = isRefund
        ? "Refunded"
        : (released ? "Paid" : "In escrow");

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
                Text(
                  job?['category'] as String? ?? '—',
                  style: DashboardText.heading(
                    size: 14,
                    weight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "$dateLabel · $statusLabel",
                  style: DashboardText.body(
                    size: 12,
                    color: DashboardColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "${isRefund ? '-' : (released ? '+' : '')}₱${amount.toStringAsFixed(0)}",
            style: DashboardText.heading(
              size: 15,
              color: isRefund
                  ? const Color(0xFFC62828)
                  : DashboardColors.statusCompleted,
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

class _ProfileTabState extends State<_ProfileTab> {
  late Future<Map<String, dynamic>> _profileFuture;
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  Set<String> _selectedSkills = {};
  bool _uploadingAvatar = false;
  bool _savingLocation = false;
  bool _savingSkills = false;
  String? _locationError;
  String? _locationSuccess;
  String? _skillsSuccess;
  String? _avatarUrlOverride;
  // Null = legacy account, still editable. Non-null (from the server, or
  // right after this session sets it) = locked, field renders read-only.
  String? _originalUsername;

  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _changingPassword = false;
  bool _showCurrentPass = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    _usernameCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final userId = supabase.auth.currentUser!.id;
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    _locationCtrl.text = row['location'] as String? ?? '';
    _phoneCtrl.text = row['phone'] as String? ?? '';
    _usernameCtrl.text = row['username'] as String? ?? '';
    _originalUsername = row['username'] as String?;
    _selectedSkills = ((row['skills'] as List?)?.cast<String>() ?? const [])
        .toSet();
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

      await supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = supabase.storage.from('avatars').getPublicUrl(path);
      final bustedUrl = "$url?t=${DateTime.now().millisecondsSinceEpoch}";

      await supabase
          .from('profiles')
          .update({'avatar_url': bustedUrl})
          .eq('id', userId);

      if (!mounted) return;
      setState(() {
        _avatarUrlOverride = bustedUrl;
        _uploadingAvatar = false;
      });
    } on StorageException catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload failed. Please try again.")),
      );
    }
  }

  Future<void> _saveLocation() async {
    final location = _locationCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (location.isEmpty) {
      setState(() => _locationError = "Location can't be empty.");
      return;
    }
    if (!isValidPhMobile(phone)) {
      setState(() => _locationError = phPhoneErrorMessage);
      return;
    }
    // Once a username is set (server-side or by this save flow already),
    // the field is locked and this save must never touch it again.
    final usernameLocked = _originalUsername != null;
    final username = _usernameCtrl.text.trim().toLowerCase();
    final settingUsername = !usernameLocked && username.isNotEmpty;
    if (settingUsername && !RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      setState(
        () => _locationError =
            "Username must be 3-20 characters: lowercase letters, numbers, underscore only.",
      );
      return;
    }
    setState(() {
      _savingLocation = true;
      _locationError = null;
      _locationSuccess = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      final update = {
        'location': location,
        'phone': phone,
        if (settingUsername) 'username': username,
      };
      await supabase.from('profiles').update(update).eq('id', userId);
      if (!mounted) return;
      setState(() {
        _savingLocation = false;
        _locationSuccess = "Profile updated.";
        if (settingUsername) _originalUsername = username;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _savingLocation = false;
        _locationError = e.code == '23505'
            ? "Username is already taken."
            : e.message;
      });
    }
  }

  Future<void> _saveSkills() async {
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pick at least one skill.")));
      return;
    }
    setState(() {
      _savingSkills = true;
      _skillsSuccess = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase
          .from('profiles')
          .update({'skills': _selectedSkills.toList()})
          .eq('id', userId);
      if (!mounted) return;
      setState(() {
        _savingSkills = false;
        _skillsSuccess = "Skills updated.";
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _savingSkills = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
      setState(
        () => _passwordError = "New password must be at least 6 characters.",
      );
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
        _passwordError =
            e.message.toLowerCase().contains('invalid login credentials')
            ? "Current password is incorrect."
            : e.message;
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
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: DashboardColors.primary),
          );
        }
        if (snapshot.hasError) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: DashboardStateMessage(
              title: "Couldn't load your profile.",
              message: "${snapshot.error}",
            ),
          );
        }

        final p = snapshot.data!;
        final firstName = p['first_name'] as String? ?? '';
        final lastName = p['last_name'] as String? ?? '';
        final initials =
            "${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}"
                .toUpperCase();
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
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  initials,
                                  style: DashboardText.heading(
                                    size: 26,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: _uploadingAvatar
                                ? null
                                : _pickAndUploadAvatar,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: DashboardColors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: _uploadingAvatar
                                  ? const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "$firstName $lastName",
                      style: DashboardText.heading(
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      p['email'] as String? ?? '',
                      style: DashboardText.body(
                        size: 13,
                        color: DashboardColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DashboardColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Profile Info",
                      style: DashboardText.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: DashboardColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      enabled: _originalUsername == null,
                      controller: _usernameCtrl,
                      onChanged: (_) => setState(() {
                        _locationError = null;
                        _locationSuccess = null;
                      }),
                      style: DashboardText.body(
                        size: 14,
                        color: Colors.black87,
                      ),
                      decoration: dashboardInputDecoration(
                        label: "Username",
                        hint: _originalUsername == null
                            ? "lowercase, numbers, underscore only"
                            : null,
                      ),
                    ),
                    if (_originalUsername == null) ...[
                      const SizedBox(height: 6),
                      Text(
                        "You can set this once — choose carefully, it can't be changed later.",
                        style: DashboardText.body(
                          size: 11,
                          color: DashboardColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationCtrl,
                      onChanged: (_) => setState(() {
                        _locationError = null;
                        _locationSuccess = null;
                      }),
                      style: DashboardText.body(
                        size: 14,
                        color: Colors.black87,
                      ),
                      decoration: dashboardInputDecoration(
                        label: "Location",
                        hint: "City, Province",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhPhoneInputFormatter()],
                      onChanged: (_) => setState(() {
                        _locationError = null;
                        _locationSuccess = null;
                      }),
                      style: DashboardText.body(
                        size: 14,
                        color: Colors.black87,
                      ),
                      decoration: dashboardInputDecoration(
                        label: "Phone Number",
                        hint: "09XX XXX XXXX",
                      ),
                    ),
                    if (_locationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _locationError!,
                        style: DashboardText.body(
                          size: 12,
                          color: const Color(0xFFC62828),
                        ),
                      ),
                    ],
                    if (_locationSuccess != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _locationSuccess!,
                        style: DashboardText.body(
                          size: 12,
                          color: DashboardColors.statusCompleted,
                        ),
                      ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _savingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                "Save",
                                style: DashboardText.body(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DashboardColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Skills",
                      style: DashboardText.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: DashboardColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Pick everything you're able to do. Clients filter Available Jobs by these.",
                      style: DashboardText.body(
                        size: 12,
                        color: DashboardColors.muted,
                      ),
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
                          side: BorderSide(
                            color: selected
                                ? DashboardColors.primary
                                : DashboardColors.border,
                          ),
                          labelStyle: DashboardText.body(
                            size: 12,
                            weight: FontWeight.w600,
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        );
                      }).toList(),
                    ),
                    if (_skillsSuccess != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _skillsSuccess!,
                        style: DashboardText.body(
                          size: 12,
                          color: DashboardColors.statusCompleted,
                        ),
                      ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _savingSkills
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                "Save Skills",
                                style: DashboardText.body(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DashboardColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Change Password",
                      style: DashboardText.heading(
                        size: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _currentPassCtrl,
                      obscureText: !_showCurrentPass,
                      onChanged: (_) => setState(() => _passwordError = null),
                      style: DashboardText.body(
                        size: 14,
                        color: Colors.black87,
                      ),
                      decoration: dashboardInputDecoration(
                        label: "Current Password",
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showCurrentPass
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 18,
                            color: DashboardColors.muted,
                          ),
                          onPressed: () => setState(
                            () => _showCurrentPass = !_showCurrentPass,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _newPassCtrl,
                      obscureText: !_showNewPass,
                      onChanged: (_) => setState(() => _passwordError = null),
                      style: DashboardText.body(
                        size: 14,
                        color: Colors.black87,
                      ),
                      decoration: dashboardInputDecoration(
                        label: "New Password",
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showNewPass
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 18,
                            color: DashboardColors.muted,
                          ),
                          onPressed: () =>
                              setState(() => _showNewPass = !_showNewPass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirmPassCtrl,
                      obscureText: !_showConfirmPass,
                      onChanged: (_) => setState(() => _passwordError = null),
                      onSubmitted: (_) => _changePassword(),
                      style: DashboardText.body(
                        size: 14,
                        color: Colors.black87,
                      ),
                      decoration: dashboardInputDecoration(
                        label: "Confirm New Password",
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirmPass
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 18,
                            color: DashboardColors.muted,
                          ),
                          onPressed: () => setState(
                            () => _showConfirmPass = !_showConfirmPass,
                          ),
                        ),
                      ),
                    ),
                    if (_passwordError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _passwordError!,
                        style: DashboardText.body(
                          size: 12,
                          color: const Color(0xFFC62828),
                        ),
                      ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _changingPassword
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                "Update Password",
                                style: DashboardText.body(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
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
                  icon: const Icon(
                    Icons.logout,
                    size: 17,
                    color: Color(0xFFC62828),
                  ),
                  label: Text(
                    "Log Out",
                    style: DashboardText.body(
                      size: 13,
                      weight: FontWeight.w700,
                      color: const Color(0xFFC62828),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFC62828)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
