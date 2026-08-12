import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../../theme/dashboard_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/dashboard/dashboard_widgets.dart';
import '../public/home_screen.dart';

enum _AdminTab { dashboard, users, jobs, transactions, refunds, reports, settings }

/// Below this width the sidebar becomes a Drawer (hamburger menu) instead
/// of a permanent column — mirrors the React DashboardShell's mobile-topbar
/// breakpoint. Admin is still primarily a desktop web portal (the Users
/// table needs real width), but the shell shouldn't break on a narrow
/// browser window or a phone.
const _narrowBreakpoint = 900.0;
const _sidebarPrefKey = 'hanap_admin_sidebar_collapsed';

class _AdminProfile {
  final String firstName;
  final String lastName;
  const _AdminProfile({required this.firstName, required this.lastName});
}

/// Admin web portal shell — collapsible left sidebar on wide screens, a
/// Drawer + hamburger topbar below `_narrowBreakpoint` (matches the React
/// DashboardShell). Every tab is wired to real Supabase data.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  _AdminTab _tab = _AdminTab.dashboard;
  bool _collapsed = false;
  _AdminProfile? _profile;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCollapsedPref();
    _loadProfile();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final rows = await supabase.from('profiles').select('id').eq('role', 'worker').eq('status', 'pending');
    if (!mounted) return;
    setState(() => _pendingCount = (rows as List).length);
  }

  Future<void> _loadCollapsedPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _collapsed = prefs.getBool(_sidebarPrefKey) ?? false);
  }

  Future<void> _toggleCollapsed() async {
    setState(() => _collapsed = !_collapsed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sidebarPrefKey, _collapsed);
  }

  Future<void> _loadProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final row = await supabase.from('profiles').select('first_name, last_name').eq('id', userId).single();
    if (!mounted) return;
    setState(() => _profile = _AdminProfile(firstName: row['first_name'] as String, lastName: row['last_name'] as String));
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Widget _content() => switch (_tab) {
        _AdminTab.dashboard => _OverviewTab(onNavigate: (t) => setState(() => _tab = t)),
        _AdminTab.users => _UsersTab(onUsersChanged: _loadPendingCount),
        _AdminTab.jobs => const _JobsTab(),
        _AdminTab.transactions => const _TransactionsTab(),
        _AdminTab.refunds => const _RefundsTab(),
        _AdminTab.reports => const _ReportsTab(),
        _AdminTab.settings => const _SettingsTab(),
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < _narrowBreakpoint;
        if (isNarrow) return _buildNarrow(context);
        return _buildWide(context);
      },
    );
  }

  Widget _buildWide(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardColors.bg,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _collapsed ? 72 : 240,
            child: _Sidebar(
              selected: _tab,
              onSelect: (t) => setState(() => _tab = t),
              onLogout: _logout,
              collapsed: _collapsed,
              onToggleCollapse: _toggleCollapsed,
              profile: _profile,
              pendingCount: _pendingCount,
            ),
          ),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: DashboardColors.primary),
        title: RichText(
          text: TextSpan(
            style: DashboardText.heading(size: 18, color: Colors.black87),
            children: const [
              TextSpan(text: "han"),
              TextSpan(text: "ap", style: TextStyle(color: DashboardColors.accent)),
            ],
          ),
        ),
      ),
      drawer: Drawer(
        child: _Sidebar(
          selected: _tab,
          onSelect: (t) {
            setState(() => _tab = t);
            Navigator.of(context).pop();
          },
          onLogout: _logout,
          collapsed: false,
          onToggleCollapse: null,
          profile: _profile,
          pendingCount: _pendingCount,
        ),
      ),
      body: _content(),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final _AdminTab selected;
  final ValueChanged<_AdminTab> onSelect;
  final VoidCallback onLogout;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;
  final _AdminProfile? profile;
  final int pendingCount;

  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.onLogout,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.profile,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: DashboardColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                if (!collapsed)
                  RichText(
                    text: TextSpan(
                      style: DashboardText.heading(size: 20, color: Colors.black87),
                      children: const [
                        TextSpan(text: "HAN"),
                        TextSpan(text: "AP", style: TextStyle(color: DashboardColors.accent)),
                      ],
                    ),
                  ),
                if (onToggleCollapse != null)
                  InkWell(
                    onTap: onToggleCollapse,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        collapsed ? Icons.chevron_right : Icons.chevron_left,
                        size: 18,
                        color: DashboardColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _UserCard(collapsed: collapsed, profile: profile),
          const Divider(height: 1, color: DashboardColors.border),
          const SizedBox(height: 8),
          _NavItem(icon: Icons.dashboard_outlined, label: "Dashboard", collapsed: collapsed, selected: selected == _AdminTab.dashboard, onTap: () => onSelect(_AdminTab.dashboard)),
          _NavGroup(
            icon: Icons.category_outlined,
            label: "Management",
            collapsed: collapsed,
            children: [
              _NavItem(
                icon: Icons.people_outline,
                label: "Users",
                collapsed: collapsed,
                indent: !collapsed,
                selected: selected == _AdminTab.users,
                badgeCount: pendingCount,
                onTap: () => onSelect(_AdminTab.users),
              ),
              _NavItem(
                icon: Icons.work_outline,
                label: "Jobs",
                collapsed: collapsed,
                indent: !collapsed,
                selected: selected == _AdminTab.jobs,
                onTap: () => onSelect(_AdminTab.jobs),
              ),
            ],
          ),
          _NavGroup(
            icon: Icons.account_balance_wallet_outlined,
            label: "Finance",
            collapsed: collapsed,
            children: [
              _NavItem(
                icon: Icons.payments_outlined,
                label: "Transactions",
                collapsed: collapsed,
                indent: !collapsed,
                selected: selected == _AdminTab.transactions,
                onTap: () => onSelect(_AdminTab.transactions),
              ),
              _NavItem(
                icon: Icons.report_gmailerrorred_outlined,
                label: "Refund Requests",
                collapsed: collapsed,
                indent: !collapsed,
                selected: selected == _AdminTab.refunds,
                onTap: () => onSelect(_AdminTab.refunds),
              ),
              _NavItem(
                icon: Icons.bar_chart_outlined,
                label: "Reports",
                collapsed: collapsed,
                indent: !collapsed,
                selected: selected == _AdminTab.reports,
                onTap: () => onSelect(_AdminTab.reports),
              ),
            ],
          ),
          _NavItem(icon: Icons.settings_outlined, label: "Settings", collapsed: collapsed, selected: selected == _AdminTab.settings, onTap: () => onSelect(_AdminTab.settings)),
          const Spacer(),
          const Divider(height: 1, color: DashboardColors.border),
          _NavItem(icon: Icons.logout, label: "Log out", collapsed: collapsed, selected: false, onTap: onLogout),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Collapsible nav group ("Management", "Finance") — a header row that
/// expands/collapses its children in place. When the sidebar itself is
/// collapsed to the icon-only rail, there's no room for a group header or
/// indentation, so children just render flat (matching how a lone _NavItem
/// already degrades to icon+tooltip in that mode).
class _NavGroup extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool collapsed;
  final List<Widget> children;

  const _NavGroup({required this.icon, required this.label, required this.collapsed, required this.children});

  @override
  State<_NavGroup> createState() => _NavGroupState();
}

class _NavGroupState extends State<_NavGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.collapsed) {
      return Column(children: widget.children);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(widget.icon, size: 19, color: DashboardColors.muted),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.label, style: DashboardText.body(size: 13, weight: FontWeight.w600, color: DashboardColors.muted))),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: DashboardColors.muted),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final bool collapsed;
  final _AdminProfile? profile;
  const _UserCard({required this.collapsed, required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile == null ? "Admin" : "${profile!.firstName} ${profile!.lastName}";
    final initials = profile == null
        ? "A"
        : "${profile!.firstName.isNotEmpty ? profile!.firstName[0] : ''}${profile!.lastName.isNotEmpty ? profile!.lastName[0] : ''}".toUpperCase();

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: DashboardColors.accent,
          child: Text(initials, style: DashboardText.heading(size: 12, color: Colors.white)),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: DashboardColors.statusCompleted,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );

    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 10, vertical: 8),
      decoration: BoxDecoration(color: DashboardColors.bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          avatar,
          if (!collapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, overflow: TextOverflow.ellipsis, style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.black87)),
                  Text("Administrator", style: DashboardText.body(size: 11, color: DashboardColors.muted)),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return collapsed ? Tooltip(message: "$name · Administrator", child: card) : card;
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  final int badgeCount;
  final bool indent;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.badgeCount = 0,
    this.indent = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWithDot = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 19, color: selected ? DashboardColors.primary : DashboardColors.muted),
        if (collapsed && badgeCount > 0)
          Positioned(
            top: -2,
            right: -3,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: DashboardColors.accent, shape: BoxShape.circle),
            ),
          ),
      ],
    );

    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: EdgeInsets.only(left: indent ? 22 : 10, right: 10, top: 2, bottom: 2),
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? DashboardColors.accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: collapsed ? null : Border(left: BorderSide(color: selected ? DashboardColors.accent : Colors.transparent, width: 3)),
        ),
        child: Row(
          mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            iconWithDot,
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: DashboardText.body(size: 13, weight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? DashboardColors.primary : DashboardColors.muted),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: DashboardColors.accent, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    "$badgeCount",
                    style: DashboardText.body(size: 10, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
    return collapsed ? Tooltip(message: badgeCount > 0 ? "$label ($badgeCount)" : label, child: content) : content;
  }
}

({String label, Color color}) _profileStatusStyle(String status) {
  switch (status) {
    case 'pending':
      return (label: 'Pending', color: DashboardColors.statusPending);
    case 'active':
      return (label: 'Active', color: DashboardColors.statusCompleted);
    case 'rejected':
      return (label: 'Rejected', color: const Color(0xFFC62828));
    case 'suspended':
      return (label: 'Suspended', color: DashboardColors.statusCancelled);
    default:
      return (label: status, color: DashboardColors.muted);
  }
}

class _ProfileStatusBadge extends StatelessWidget {
  final String status;
  const _ProfileStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final style = _profileStatusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        style.label.toUpperCase(),
        style: DashboardText.body(size: 10, weight: FontWeight.w700, color: style.color).copyWith(letterSpacing: 0.4),
      ),
    );
  }
}

({String label, Color color}) _paymentStatusStyle(String status) {
  switch (status) {
    case 'unpaid':
      return (label: 'Unpaid', color: DashboardColors.muted);
    case 'paid':
      return (label: 'In Escrow', color: DashboardColors.accent);
    case 'refund_requested':
      return (label: 'Refund Requested', color: DashboardColors.accent);
    case 'refunded':
      return (label: 'Refunded', color: DashboardColors.statusCancelled);
    case 'released':
      return (label: 'Released', color: DashboardColors.statusCompleted);
    default:
      return (label: status, color: DashboardColors.muted);
  }
}

/// A page heading + subtitle, matching the Users tab's established look —
/// reused by every other admin tab instead of Client/Worker's gradient
/// DashboardHeaderCard (that's a mobile-hero pattern, not a fit here).
class _TabHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _TabHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: DashboardText.heading(size: 22, color: Colors.black87)),
        const SizedBox(height: 4),
        Text(subtitle, style: DashboardText.body(size: 13, color: DashboardColors.muted)),
      ],
    );
  }
}

class _UsersTab extends StatefulWidget {
  final VoidCallback onUsersChanged;
  const _UsersTab({required this.onUsersChanged});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  String? _actingOnId;

  @override
  void initState() {
    super.initState();
    _usersFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await supabase.from('profiles').select().order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _usersFuture = future);
    await future;
  }

  Future<void> _setStatus(String id, String status) async {
    setState(() => _actingOnId = id);
    try {
      await supabase.from('profiles').update({'status': status}).eq('id', id);
      await _refresh();
      widget.onUsersChanged();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actingOnId = null);
    }
  }

  Future<void> _viewNbi(String path) async {
    try {
      final url = await supabase.storage.from('nbi-clearance').createSignedUrl(path, 60 * 10);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open file: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Users", style: DashboardText.heading(size: 22, color: Colors.black87)),
          const SizedBox(height: 4),
          Text("All registered users on the platform", style: DashboardText.body(size: 13, color: DashboardColors.muted)),
          const SizedBox(height: 20),
          Expanded(
            child: RefreshIndicator(
              color: DashboardColors.primary,
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _usersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
                  }
                  if (snapshot.hasError) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: DashboardStateMessage(title: "Couldn't load users.", message: "${snapshot.error}"),
                    );
                  }
                  final users = snapshot.data ?? [];
                  if (users.isEmpty) {
                    return const SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: DashboardStateMessage(title: "No users yet."),
                    );
                  }
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 920),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DashboardColors.border),
                          ),
                          child: Column(
                            children: [
                              const _UserRow.header(),
                              for (final u in users)
                                _UserRow(
                                  user: u,
                                  acting: _actingOnId == u['id'],
                                  onApprove: () => _setStatus(u['id'] as String, 'active'),
                                  onReject: () => _setStatus(u['id'] as String, 'rejected'),
                                  onSuspend: () => _setStatus(u['id'] as String, 'suspended'),
                                  onReactivate: () => _setStatus(u['id'] as String, 'active'),
                                  onViewNbi: u['nbi_clearance_path'] != null ? () => _viewNbi(u['nbi_clearance_path'] as String) : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _colName = 220.0;
const _colRole = 90.0;
const _colLocation = 150.0;
const _colJoined = 120.0;
const _colStatus = 110.0;
const _colAction = 230.0;

class _UserRow extends StatelessWidget {
  final Map<String, dynamic>? user;
  final bool acting;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onSuspend;
  final VoidCallback? onReactivate;
  final VoidCallback? onViewNbi;
  final bool isHeader;

  const _UserRow({
    required this.user,
    this.acting = false,
    this.onApprove,
    this.onReject,
    this.onSuspend,
    this.onReactivate,
    this.onViewNbi,
  }) : isHeader = false;

  const _UserRow.header()
      : user = null,
        acting = false,
        onApprove = null,
        onReject = null,
        onSuspend = null,
        onReactivate = null,
        onViewNbi = null,
        isHeader = true;

  @override
  Widget build(BuildContext context) {
    if (isHeader) {
      final headerStyle = DashboardText.body(size: 12, weight: FontWeight.w700, color: Colors.black87);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: DashboardColors.bg,
          border: Border(bottom: BorderSide(color: DashboardColors.border)),
        ),
        child: Row(
          children: [
            SizedBox(width: _colName, child: Text("Name", style: headerStyle)),
            SizedBox(width: _colRole, child: Text("Role", style: headerStyle)),
            SizedBox(width: _colLocation, child: Text("Location", style: headerStyle)),
            SizedBox(width: _colJoined, child: Text("Joined", style: headerStyle)),
            SizedBox(width: _colStatus, child: Text("Status", style: headerStyle)),
            SizedBox(width: _colAction, child: Text("Action", style: headerStyle)),
          ],
        ),
      );
    }

    final u = user!;
    final role = u['role'] as String;
    final status = u['status'] as String;
    final statusStyle = _profileStatusStyle(status);
    final createdAt = DateTime.tryParse(u['created_at'] as String? ?? '');
    final joined = createdAt == null ? '—' : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    final nbiPath = u['nbi_clearance_path'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _colName,
            child: Text(
              "${u['first_name']} ${u['last_name']}",
              style: DashboardText.body(size: 13, weight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          SizedBox(width: _colRole, child: Text(role, style: DashboardText.body(size: 13, color: DashboardColors.muted))),
          SizedBox(width: _colLocation, child: Text(u['location'] as String? ?? '—', style: DashboardText.body(size: 13, color: DashboardColors.muted))),
          SizedBox(width: _colJoined, child: Text(joined, style: DashboardText.body(size: 13, color: DashboardColors.muted))),
          SizedBox(
            width: _colStatus,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusStyle.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(
                statusStyle.label,
                style: DashboardText.body(size: 11, weight: FontWeight.w700, color: statusStyle.color),
              ),
            ),
          ),
          SizedBox(
            width: _colAction,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (role == 'worker' && status == 'pending' && nbiPath != null)
                  _ActionChip(label: "View NBI", color: DashboardColors.statOpen, onTap: onViewNbi),
                if (role == 'worker' && status == 'pending')
                  _ActionChip(label: "Approve", color: DashboardColors.statusCompleted, filled: true, loading: acting, onTap: onApprove),
                if (role == 'worker' && status == 'pending')
                  _ActionChip(label: "Reject", color: const Color(0xFFC62828), loading: acting, onTap: onReject),
                if (status == 'active') _ActionChip(label: "Suspend", color: DashboardColors.accent, loading: acting, onTap: onSuspend),
                if (status == 'suspended') _ActionChip(label: "Reactivate", color: DashboardColors.statusCompleted, filled: true, loading: acting, onTap: onReactivate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionChip({required this.label, required this.color, this.filled = false, this.loading = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? color : Colors.white,
          foregroundColor: filled ? Colors.white : color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: loading
            ? SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5, color: filled ? Colors.white : color))
            : Text(label, style: DashboardText.body(size: 11, weight: FontWeight.w700)),
      ),
    );
  }
}

// ── DASHBOARD (OVERVIEW) TAB ────────────────────────────────────────────

class _OverviewData {
  final int clients;
  final int activeWorkers;
  final int totalJobs;
  final int activeJobs;
  final int completedJobs;
  final double totalEarnings;
  final List<Map<String, dynamic>> recentUsers;
  final List<Map<String, dynamic>> recentJobs;

  const _OverviewData({
    required this.clients,
    required this.activeWorkers,
    required this.totalJobs,
    required this.activeJobs,
    required this.completedJobs,
    required this.totalEarnings,
    required this.recentUsers,
    required this.recentJobs,
  });
}

class _OverviewTab extends StatefulWidget {
  final ValueChanged<_AdminTab> onNavigate;
  const _OverviewTab({required this.onNavigate});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Future<_OverviewData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_OverviewData> _load() async {
    final profileRows = ((await supabase.from('profiles').select('role, status')) as List).cast<Map<String, dynamic>>();
    final jobRows = ((await supabase.from('jobs').select('status')) as List).cast<Map<String, dynamic>>();
    final recentUsersRows = ((await supabase.from('profiles').select('first_name, last_name, role, location, status').order('created_at', ascending: false).limit(5)) as List)
        .cast<Map<String, dynamic>>();
    final recentJobsRows = ((await supabase
            .from('jobs')
            .select('category, budget, status, client:profiles!jobs_client_id_fkey(first_name,last_name), worker:profiles!jobs_worker_id_fkey(first_name,last_name)')
            .order('created_at', ascending: false)
            .limit(5)) as List)
        .cast<Map<String, dynamic>>();
    // Only count the 10% platform fee as earned once the payment has
    // actually been released to the worker — 'paid' (still in escrow) and
    // 'refund_requested' (dispute outcome undetermined) can still end up
    // fully refunded, so they're not real earnings yet.
    final txRows = ((await supabase.from('transactions').select('type, platform_fee, job:jobs(payment_status)')) as List).cast<Map<String, dynamic>>();
    final earnings = txRows
        .where((t) => t['type'] == 'payment' && (t['job'] as Map<String, dynamic>?)?['payment_status'] == 'released')
        .fold<double>(0, (sum, t) => sum + ((t['platform_fee'] as num?) ?? 0).toDouble());

    return _OverviewData(
      clients: profileRows.where((p) => p['role'] == 'client').length,
      activeWorkers: profileRows.where((p) => p['role'] == 'worker' && p['status'] == 'active').length,
      totalJobs: jobRows.length,
      activeJobs: jobRows.where((j) => ['accepted', 'arrived', 'in_progress'].contains(j['status'])).length,
      completedJobs: jobRows.where((j) => j['status'] == 'completed').length,
      totalEarnings: earnings,
      recentUsers: recentUsersRows,
      recentJobs: recentJobsRows,
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
      child: FutureBuilder<_OverviewData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
          }
          if (snapshot.hasError) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(28),
              child: DashboardStateMessage(title: "Couldn't load the dashboard.", message: "${snapshot.error}"),
            );
          }
          final d = snapshot.data!;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
                      Text("Admin Dashboard", style: DashboardText.heading(size: 24, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text("Platform overview and system health", style: DashboardText.body(size: 13, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: DashboardStatCard(icon: Icons.person_outline, value: "${d.clients}", label: "Total Clients", accentColor: DashboardColors.primary)),
                    const SizedBox(width: 14),
                    Expanded(child: DashboardStatCard(icon: Icons.build_outlined, value: "${d.activeWorkers}", label: "Active Workers", accentColor: DashboardColors.accent)),
                    const SizedBox(width: 14),
                    Expanded(child: DashboardStatCard(icon: Icons.work_outline, value: "${d.totalJobs}", label: "Total Jobs", accentColor: DashboardColors.statusCompleted)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _PlainStatCard(value: "${d.activeJobs}", label: "Active Jobs", color: DashboardColors.statOpen)),
                    const SizedBox(width: 14),
                    Expanded(child: _PlainStatCard(value: "${d.completedJobs}", label: "Completed Jobs", color: DashboardColors.statusCompleted)),
                    const SizedBox(width: 14),
                    Expanded(child: _PlainStatCard(value: "₱${d.totalEarnings.toStringAsFixed(0)}", label: "Total Earnings (10% fee)", color: DashboardColors.accent)),
                  ],
                ),
                const SizedBox(height: 24),
                _RecentUsersCard(users: d.recentUsers, onViewAll: () => widget.onNavigate(_AdminTab.users)),
                const SizedBox(height: 20),
                _RecentJobsCard(jobs: d.recentJobs, onViewAll: () => widget.onNavigate(_AdminTab.jobs)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlainStatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _PlainStatCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: DashboardText.heading(size: 26, color: color)),
          const SizedBox(height: 4),
          Text(label, style: DashboardText.body(size: 13, color: DashboardColors.muted)),
        ],
      ),
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: DashboardColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text("View all", style: DashboardText.body(size: 12, weight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class _RecentUsersCard extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final VoidCallback onViewAll;
  const _RecentUsersCard({required this.users, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DashboardColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                Expanded(child: Text("Recent Users", style: DashboardText.heading(size: 16, color: Colors.black87))),
                _ViewAllButton(onTap: onViewAll),
              ],
            ),
          ),
          if (users.isEmpty)
            const Padding(padding: EdgeInsets.only(bottom: 24), child: Center(child: Text("No users yet.")))
          else ...[
            const Divider(height: 1, color: DashboardColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text("NAME", style: _headCellStyle)),
                  Expanded(flex: 2, child: Text("ROLE", style: _headCellStyle)),
                  Expanded(flex: 3, child: Text("LOCATION", style: _headCellStyle)),
                  Expanded(flex: 2, child: Text("STATUS", style: _headCellStyle)),
                ],
              ),
            ),
            for (final u in users)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text("${u['first_name']} ${u['last_name']}", style: DashboardText.body(size: 13, weight: FontWeight.w600, color: Colors.black87))),
                    Expanded(flex: 2, child: Text(u['role'] as String, style: DashboardText.body(size: 13, color: DashboardColors.muted))),
                    Expanded(flex: 3, child: Text(u['location'] as String? ?? '—', style: DashboardText.body(size: 13, color: DashboardColors.muted))),
                    Expanded(flex: 2, child: _ProfileStatusBadge(status: u['status'] as String)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _RecentJobsCard extends StatelessWidget {
  final List<Map<String, dynamic>> jobs;
  final VoidCallback onViewAll;
  const _RecentJobsCard({required this.jobs, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DashboardColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                Expanded(child: Text("Recent Jobs", style: DashboardText.heading(size: 16, color: Colors.black87))),
                _ViewAllButton(onTap: onViewAll),
              ],
            ),
          ),
          if (jobs.isEmpty)
            const Padding(padding: EdgeInsets.only(bottom: 24), child: Center(child: Text("No jobs yet.")))
          else ...[
            const Divider(height: 1, color: DashboardColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text("JOB", style: _headCellStyle)),
                  Expanded(flex: 2, child: Text("CLIENT", style: _headCellStyle)),
                  Expanded(flex: 2, child: Text("WORKER", style: _headCellStyle)),
                  Expanded(flex: 2, child: Text("BUDGET", style: _headCellStyle)),
                  Expanded(flex: 2, child: Text("STATUS", style: _headCellStyle)),
                ],
              ),
            ),
            for (final j in jobs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(j['category'] as String, style: DashboardText.body(size: 13, weight: FontWeight.w600, color: Colors.black87))),
                    Expanded(flex: 2, child: Text(_fullName(j['client']), style: DashboardText.body(size: 13, color: DashboardColors.muted))),
                    Expanded(flex: 2, child: Text(_fullName(j['worker']), style: DashboardText.body(size: 13, color: DashboardColors.muted))),
                    Expanded(flex: 2, child: Text(j['budget'] != null ? "₱${(j['budget'] as num).toStringAsFixed(0)}" : "—", style: DashboardText.body(size: 13, color: DashboardColors.muted))),
                    Expanded(flex: 2, child: DashboardStatusBadge(status: j['status'] as String)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _fullName(Map<String, dynamic>? p) {
    if (p == null) return '—';
    return "${p['first_name']} ${p['last_name']}";
  }
}

final _headCellStyle = DashboardText.body(size: 11, weight: FontWeight.w700, color: DashboardColors.muted).copyWith(letterSpacing: 0.4);

// ── JOBS TAB ─────────────────────────────────────────────────────────────

class _JobsTab extends StatefulWidget {
  const _JobsTab();

  @override
  State<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<_JobsTab> {
  late Future<List<Map<String, dynamic>>> _jobsFuture;
  String _statusFilter = 'All';

  static const _statuses = ['All', 'open', 'accepted', 'arrived', 'in_progress', 'completed', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _jobsFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await supabase
        .from('jobs')
        .select('*, client:profiles!jobs_client_id_fkey(first_name,last_name), worker:profiles!jobs_worker_id_fkey(first_name,last_name)')
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _jobsFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TabHeading(title: "Jobs", subtitle: "All jobs posted on the platform"),
          const SizedBox(height: 16),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
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
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              color: DashboardColors.primary,
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _jobsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
                  }
                  if (snapshot.hasError) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: DashboardStateMessage(title: "Couldn't load jobs.", message: "${snapshot.error}"),
                    );
                  }
                  final allJobs = snapshot.data ?? [];
                  final jobs = _statusFilter == 'All' ? allJobs : allJobs.where((j) => j['status'] == _statusFilter).toList();
                  if (jobs.isEmpty) {
                    return const SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: DashboardStateMessage(title: "No jobs match this filter."),
                    );
                  }
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 1000),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DashboardColors.border)),
                          child: Column(
                            children: [
                              const _JobRow.header(),
                              for (final j in jobs) _JobRow(job: j),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _jColCategory = 160.0;
const _jColClient = 150.0;
const _jColWorker = 150.0;
const _jColBudget = 100.0;
const _jColLocation = 140.0;
const _jColStatus = 120.0;
const _jColPayment = 140.0;

class _JobRow extends StatelessWidget {
  final Map<String, dynamic>? job;
  final bool isHeader;

  const _JobRow({required this.job}) : isHeader = false;
  const _JobRow.header() : job = null, isHeader = true;

  @override
  Widget build(BuildContext context) {
    if (isHeader) {
      final headerStyle = DashboardText.body(size: 12, weight: FontWeight.w700, color: Colors.black87);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(color: DashboardColors.bg, border: Border(bottom: BorderSide(color: DashboardColors.border))),
        child: Row(
          children: [
            SizedBox(width: _jColCategory, child: Text("Category", style: headerStyle)),
            SizedBox(width: _jColClient, child: Text("Client", style: headerStyle)),
            SizedBox(width: _jColWorker, child: Text("Worker", style: headerStyle)),
            SizedBox(width: _jColBudget, child: Text("Budget", style: headerStyle)),
            SizedBox(width: _jColLocation, child: Text("Location", style: headerStyle)),
            SizedBox(width: _jColStatus, child: Text("Status", style: headerStyle)),
            SizedBox(width: _jColPayment, child: Text("Payment", style: headerStyle)),
          ],
        ),
      );
    }

    final j = job!;
    final client = j['client'] as Map<String, dynamic>?;
    final worker = j['worker'] as Map<String, dynamic>?;
    final clientName = client == null ? '—' : "${client['first_name']} ${client['last_name']}";
    final workerName = worker == null ? '—' : "${worker['first_name']} ${worker['last_name']}";
    final budget = (j['budget'] as num?)?.toDouble();
    final statusStyle = dashboardStatusStyle(j['status'] as String);
    final paymentStyle = _paymentStatusStyle(j['payment_status'] as String? ?? 'unpaid');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        children: [
          SizedBox(width: _jColCategory, child: Text(j['category'] as String, style: DashboardText.body(size: 13, weight: FontWeight.w600, color: Colors.black87))),
          SizedBox(width: _jColClient, child: Text(clientName, style: DashboardText.body(size: 13, color: DashboardColors.muted))),
          SizedBox(width: _jColWorker, child: Text(workerName, style: DashboardText.body(size: 13, color: DashboardColors.muted))),
          SizedBox(width: _jColBudget, child: Text(budget == null ? '—' : "₱${budget.toStringAsFixed(0)}", style: DashboardText.body(size: 13, color: DashboardColors.muted))),
          SizedBox(width: _jColLocation, child: Text(j['location'] as String? ?? '—', style: DashboardText.body(size: 13, color: DashboardColors.muted))),
          SizedBox(
            width: _jColStatus,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusStyle.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(statusStyle.label, style: DashboardText.body(size: 11, weight: FontWeight.w700, color: statusStyle.color)),
            ),
          ),
          SizedBox(
            width: _jColPayment,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: paymentStyle.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(paymentStyle.label, style: DashboardText.body(size: 11, weight: FontWeight.w700, color: paymentStyle.color)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── TRANSACTIONS TAB ────────────────────────────────────────────────────

class _TransactionsTab extends StatefulWidget {
  const _TransactionsTab();

  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  late Future<List<Map<String, dynamic>>> _txFuture;

  @override
  void initState() {
    super.initState();
    _txFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await supabase
        .from('transactions')
        .select('*, job:jobs(category), client:profiles!transactions_client_id_fkey(first_name,last_name), worker:profiles!transactions_worker_id_fkey(first_name,last_name)')
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _txFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TabHeading(title: "Transactions", subtitle: "Every payment and refund on the platform"),
          const SizedBox(height: 20),
          Expanded(
            child: RefreshIndicator(
              color: DashboardColors.primary,
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _txFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
                  }
                  if (snapshot.hasError) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: DashboardStateMessage(title: "Couldn't load transactions.", message: "${snapshot.error}"),
                    );
                  }
                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty) {
                    return const SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: DashboardStateMessage(
                        title: "No transactions yet.",
                        message: "Payments and refunds will show up here once jobs get paid.",
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 820),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DashboardColors.border)),
                          child: Column(
                            children: [
                              const _TransactionRow.header(),
                              for (final t in rows) _TransactionRow(tx: t),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _tColJob = 180.0;
const _tColClient = 150.0;
const _tColWorker = 150.0;
const _tColType = 110.0;
const _tColAmount = 110.0;
const _tColDate = 120.0;

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic>? tx;
  final bool isHeader;

  const _TransactionRow({required this.tx}) : isHeader = false;
  const _TransactionRow.header() : tx = null, isHeader = true;

  @override
  Widget build(BuildContext context) {
    if (isHeader) {
      final headerStyle = DashboardText.body(size: 12, weight: FontWeight.w700, color: Colors.black87);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(color: DashboardColors.bg, border: Border(bottom: BorderSide(color: DashboardColors.border))),
        child: Row(
          children: [
            SizedBox(width: _tColJob, child: Text("Job", style: headerStyle)),
            SizedBox(width: _tColClient, child: Text("Client", style: headerStyle)),
            SizedBox(width: _tColWorker, child: Text("Worker", style: headerStyle)),
            SizedBox(width: _tColType, child: Text("Type", style: headerStyle)),
            SizedBox(width: _tColAmount, child: Text("Amount", style: headerStyle)),
            SizedBox(width: _tColDate, child: Text("Date", style: headerStyle)),
          ],
        ),
      );
    }

    final t = tx!;
    final job = t['job'] as Map<String, dynamic>?;
    final client = t['client'] as Map<String, dynamic>?;
    final worker = t['worker'] as Map<String, dynamic>?;
    final type = t['type'] as String;
    final isRefund = type == 'refund';
    final amount = (t['amount'] as num).toDouble();
    final createdAt = DateTime.tryParse(t['created_at'] as String? ?? '');
    final dateLabel = createdAt == null ? '—' : "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(
        children: [
          SizedBox(width: _tColJob, child: Text(job?['category'] as String? ?? '—', style: DashboardText.body(size: 13, weight: FontWeight.w600, color: Colors.black87))),
          SizedBox(width: _tColClient, child: Text(client == null ? '—' : "${client['first_name']} ${client['last_name']}", style: DashboardText.body(size: 13, color: DashboardColors.muted))),
          SizedBox(width: _tColWorker, child: Text(worker == null ? '—' : "${worker['first_name']} ${worker['last_name']}", style: DashboardText.body(size: 13, color: DashboardColors.muted))),
          SizedBox(
            width: _tColType,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isRefund ? DashboardColors.statusCancelled : DashboardColors.statusCompleted).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isRefund ? "Refund" : "Payment",
                style: DashboardText.body(size: 11, weight: FontWeight.w700, color: isRefund ? DashboardColors.statusCancelled : DashboardColors.statusCompleted),
              ),
            ),
          ),
          SizedBox(
            width: _tColAmount,
            child: Text(
              "${isRefund ? '-' : ''}₱${amount.toStringAsFixed(0)}",
              style: DashboardText.body(size: 13, weight: FontWeight.w700, color: isRefund ? const Color(0xFFC62828) : Colors.black87),
            ),
          ),
          SizedBox(width: _tColDate, child: Text(dateLabel, style: DashboardText.body(size: 13, color: DashboardColors.muted))),
        ],
      ),
    );
  }
}

// ── REFUND REQUESTS TAB ─────────────────────────────────────────────────

class _RefundsTab extends StatefulWidget {
  const _RefundsTab();

  @override
  State<_RefundsTab> createState() => _RefundsTabState();
}

class _RefundsTabState extends State<_RefundsTab> {
  late Future<List<Map<String, dynamic>>> _refundsFuture;
  String? _actingOnId;

  @override
  void initState() {
    super.initState();
    _refundsFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await supabase
        .from('jobs')
        .select('*, client:profiles!jobs_client_id_fkey(first_name,last_name), worker:profiles!jobs_worker_id_fkey(first_name,last_name)')
        .eq('payment_status', 'refund_requested')
        .order('refund_requested_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _refundsFuture = future);
    await future;
  }

  Future<void> _resolve(String jobId, bool approve, String message) async {
    setState(() => _actingOnId = jobId);
    try {
      await supabase.rpc('resolve_refund', params: {'job_id': jobId, 'approve': approve, 'message': message});
      await _refresh();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actingOnId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TabHeading(title: "Refund Requests", subtitle: "Pending refund requests from clients"),
          const SizedBox(height: 20),
          Expanded(
            child: RefreshIndicator(
              color: DashboardColors.primary,
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _refundsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
                  }
                  if (snapshot.hasError) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: DashboardStateMessage(title: "Couldn't load refund requests.", message: "${snapshot.error}"),
                    );
                  }
                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty) {
                    return const SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: DashboardStateMessage(title: "No pending refund requests."),
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _RefundCard(
                      job: rows[i],
                      acting: _actingOnId == rows[i]['id'],
                      onApprove: (message) => _resolve(rows[i]['id'] as String, true, message),
                      onDeny: (message) => _resolve(rows[i]['id'] as String, false, message),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundCard extends StatefulWidget {
  final Map<String, dynamic> job;
  final bool acting;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onDeny;

  const _RefundCard({required this.job, required this.acting, required this.onApprove, required this.onDeny});

  @override
  State<_RefundCard> createState() => _RefundCardState();
}

class _RefundCardState extends State<_RefundCard> {
  final _messageCtrl = TextEditingController();

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _viewEvidence(String path) async {
    try {
      final url = await supabase.storage.from('refund-evidence').createSignedUrl(path, 60 * 10);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open photo: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final client = job['client'] as Map<String, dynamic>?;
    final worker = job['worker'] as Map<String, dynamic>?;
    final clientName = client == null ? '—' : "${client['first_name']} ${client['last_name']}";
    final workerName = worker == null ? '—' : "${worker['first_name']} ${worker['last_name']}";
    final budget = (job['budget'] as num?)?.toDouble();
    final serviceFee = (job['service_fee'] as num?)?.toDouble();
    final photoPath = job['refund_photo_url'] as String?;
    final requestedAt = DateTime.tryParse(job['refund_requested_at'] as String? ?? '');
    final dateLabel =
        requestedAt == null ? '—' : "${requestedAt.year}-${requestedAt.month.toString().padLeft(2, '0')}-${requestedAt.day.toString().padLeft(2, '0')}";
    final canAct = _messageCtrl.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      constraints: const BoxConstraints(maxWidth: 720),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DashboardColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(job['category'] as String, style: DashboardText.heading(size: 15, color: Colors.black87))),
              if (budget != null)
                Text("₱${(budget + (serviceFee ?? 0)).toStringAsFixed(0)} escrowed", style: DashboardText.heading(size: 16, color: DashboardColors.accent)),
            ],
          ),
          const SizedBox(height: 6),
          Text("Client: $clientName  ·  Worker: $workerName", style: DashboardText.body(size: 12, color: DashboardColors.muted)),
          const SizedBox(height: 2),
          Text("Requested $dateLabel", style: DashboardText.body(size: 12, color: DashboardColors.muted)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: DashboardColors.bg, borderRadius: BorderRadius.circular(8)),
            child: Text(
              job['refund_reason'] as String? ?? 'No reason given.',
              style: DashboardText.body(size: 13, color: Colors.black87).copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          if (photoPath != null)
            OutlinedButton.icon(
              onPressed: () => _viewEvidence(photoPath),
              icon: const Icon(Icons.photo_outlined, size: 16),
              label: Text("View Photo Evidence", style: DashboardText.body(size: 12, weight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: DashboardColors.primary,
                side: const BorderSide(color: DashboardColors.border),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 2,
            style: DashboardText.body(size: 13, color: Colors.black87),
            decoration: dashboardInputDecoration(label: "Message to client", hint: "Explain your decision (required)"),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: widget.acting || !canAct ? null : () => widget.onApprove(_messageCtrl.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DashboardColors.statusCompleted,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: widget.acting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text("Approve Refund", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: widget.acting || !canAct ? null : () => widget.onDeny(_messageCtrl.text.trim()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text("Deny (release to worker)", style: DashboardText.body(size: 12, weight: FontWeight.w700), textAlign: TextAlign.center),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── REPORTS TAB ──────────────────────────────────────────────────────────

class _ReportsData {
  final Map<String, int> categoryCounts;
  final int totalJobs;
  final int completedJobs;
  final double totalRevenue;

  const _ReportsData({required this.categoryCounts, required this.totalJobs, required this.completedJobs, required this.totalRevenue});
}

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  late Future<_ReportsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_ReportsData> _load() async {
    final jobRows = ((await supabase.from('jobs').select('category, status')) as List).cast<Map<String, dynamic>>();
    final txRows = ((await supabase.from('transactions').select('type, platform_fee, job:jobs(payment_status)')) as List).cast<Map<String, dynamic>>();
    // HANAP's actual earnings — the 10% platform fee, only once it's been
    // released to the worker. 'paid' (still in escrow) and
    // 'refund_requested' (dispute outcome undetermined) can still end up
    // fully refunded, so they're not counted as earned yet.
    final revenue = txRows
        .where((t) => t['type'] == 'payment' && (t['job'] as Map<String, dynamic>?)?['payment_status'] == 'released')
        .fold<double>(0, (sum, t) => sum + ((t['platform_fee'] as num?) ?? 0).toDouble());

    final categoryCounts = <String, int>{};
    for (final j in jobRows) {
      final cat = j['category'] as String;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    return _ReportsData(
      categoryCounts: categoryCounts,
      totalJobs: jobRows.length,
      completedJobs: jobRows.where((j) => j['status'] == 'completed').length,
      totalRevenue: revenue,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _dataFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TabHeading(title: "Reports", subtitle: "Platform activity at a glance"),
          const SizedBox(height: 20),
          Expanded(
            child: RefreshIndicator(
              color: DashboardColors.primary,
              onRefresh: _refresh,
              child: FutureBuilder<_ReportsData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: DashboardColors.primary));
                  }
                  if (snapshot.hasError) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: DashboardStateMessage(title: "Couldn't load reports.", message: "${snapshot.error}"),
                    );
                  }
                  final d = snapshot.data!;
                  final completionRate = d.totalJobs == 0 ? 0.0 : (d.completedJobs / d.totalJobs) * 100;
                  final sortedCategories = d.categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                  final maxCount = sortedCategories.isEmpty ? 1 : sortedCategories.first.value;

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            SizedBox(width: 200, child: DashboardStatCard(value: "${d.totalJobs}", label: "Total Jobs", accentColor: DashboardColors.primary)),
                            SizedBox(
                              width: 200,
                              child: DashboardStatCard(value: "${completionRate.toStringAsFixed(0)}%", label: "Completion Rate", accentColor: DashboardColors.statCompleted),
                            ),
                            SizedBox(width: 200, child: DashboardStatCard(value: "₱${d.totalRevenue.toStringAsFixed(0)}", label: "Total Revenue", accentColor: DashboardColors.accent)),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text("Jobs by Category", style: DashboardText.heading(size: 16, color: Colors.black87)),
                        const SizedBox(height: 14),
                        if (sortedCategories.isEmpty)
                          Text("No jobs posted yet.", style: DashboardText.body(size: 13, color: DashboardColors.muted))
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              children: [for (final entry in sortedCategories) _CategoryBar(label: entry.key, count: entry.value, maxCount: maxCount)],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;
  const _CategoryBar({required this.label, required this.count, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount == 0 ? 0.0 : count / maxCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: DashboardText.body(size: 13, weight: FontWeight.w600, color: Colors.black87))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 16,
                backgroundColor: DashboardColors.bg,
                valueColor: const AlwaysStoppedAnimation(DashboardColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 24, child: Text("$count", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.black87))),
        ],
      ),
    );
  }
}

// ── SETTINGS TAB ─────────────────────────────────────────────────────────

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late Future<Map<String, dynamic>> _profileFuture;
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;
  bool _savingPhone = false;
  String? _error;
  String? _success;
  String? _phoneError;
  String? _phoneSuccess;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final userId = supabase.auth.currentUser!.id;
    final row = await supabase.from('profiles').select().eq('id', userId).single();
    _phoneCtrl.text = row['phone'] as String? ?? '';
    return row;
  }

  Future<void> _savePhone() async {
    final phone = _phoneCtrl.text.trim();
    if (!isValidPhMobile(phone)) {
      setState(() => _phoneError = phPhoneErrorMessage);
      return;
    }
    setState(() {
      _savingPhone = true;
      _phoneError = null;
      _phoneSuccess = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').update({'phone': phone}).eq('id', userId);
      if (!mounted) return;
      setState(() {
        _savingPhone = false;
        _phoneSuccess = "Phone number updated.";
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _savingPhone = false;
        _phoneError = e.message;
      });
    }
  }

  Future<void> _changePassword() async {
    final newPass = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();
    setState(() {
      _error = null;
      _success = null;
    });

    if (newPass.length < 6) {
      setState(() => _error = "Password must be at least 6 characters.");
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = "Passwords don't match.");
      return;
    }

    setState(() => _saving = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPass));
      if (!mounted) return;
      setState(() {
        _saving = false;
        _success = "Password updated.";
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Something went wrong. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TabHeading(title: "Settings", subtitle: "Your admin account"),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<Map<String, dynamic>>(
                      future: _profileFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: DashboardColors.primary)));
                        }
                        final p = snapshot.data!;
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DashboardColors.border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Account Info", style: DashboardText.heading(size: 15, color: Colors.black87)),
                              const SizedBox(height: 14),
                              _InfoLine(label: "Name", value: "${p['first_name']} ${p['last_name']}"),
                              _InfoLine(label: "Email", value: p['email'] as String),
                              _InfoLine(label: "Location", value: p['location'] as String? ?? '—'),
                              const _InfoLine(label: "Role", value: "Administrator"),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DashboardColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Phone Number", style: DashboardText.heading(size: 15, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text(
                            "Used for GCash payment verification.",
                            style: DashboardText.body(size: 12, color: DashboardColors.muted),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [PhPhoneInputFormatter()],
                            onChanged: (_) => setState(() {
                              _phoneError = null;
                              _phoneSuccess = null;
                            }),
                            style: DashboardText.body(size: 14, color: Colors.black87),
                            decoration: dashboardInputDecoration(label: "Phone Number", hint: "09XX XXX XXXX"),
                          ),
                          if (_phoneError != null) ...[
                            const SizedBox(height: 10),
                            Text(_phoneError!, style: DashboardText.body(size: 12, color: const Color(0xFFC62828))),
                          ],
                          if (_phoneSuccess != null) ...[
                            const SizedBox(height: 10),
                            Text(_phoneSuccess!, style: DashboardText.body(size: 12, color: DashboardColors.statusCompleted)),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _savingPhone ? null : _savePhone,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DashboardColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _savingPhone
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text("Save", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: DashboardColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Change Password", style: DashboardText.heading(size: 15, color: Colors.black87)),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _newPassCtrl,
                            obscureText: true,
                            style: DashboardText.body(size: 14, color: Colors.black87),
                            decoration: dashboardInputDecoration(label: "New Password", hint: "••••••••"),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _confirmPassCtrl,
                            obscureText: true,
                            style: DashboardText.body(size: 14, color: Colors.black87),
                            onSubmitted: (_) => _changePassword(),
                            decoration: dashboardInputDecoration(label: "Confirm Password", hint: "••••••••"),
                          ),
                          const SizedBox(height: 14),
                          if (_error != null) ...[
                            Text(_error!, style: DashboardText.body(size: 12, color: const Color(0xFFC62828))),
                            const SizedBox(height: 10),
                          ],
                          if (_success != null) ...[
                            Text(_success!, style: DashboardText.body(size: 12, color: DashboardColors.statusCompleted)),
                            const SizedBox(height: 10),
                          ],
                          SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _changePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DashboardColors.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _saving
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text("Update Password", style: DashboardText.body(size: 13, weight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: DashboardText.body(size: 12, weight: FontWeight.w600, color: DashboardColors.muted))),
          Expanded(child: Text(value, style: DashboardText.body(size: 13, color: Colors.black87))),
        ],
      ),
    );
  }
}
