import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../providers/admin_providers.dart';
import '../../auth/providers/auth_settings_provider.dart';
import '../../../core/utils/responsive.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Responsive(context);
    final membersAsync = ref.watch(memberListProvider);
    final auditLogsAsync = ref.watch(auditLogsProvider);
    final archivesAsync = ref.watch(yearlyArchivesProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF0D0D0D),
              Color(0xFF151312),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom Animated App Bar
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF0A0A0A).withValues(alpha: 0.8),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Text(
                    'Lit Life Console',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: r.sp(24),
                      color: const Color(0xFFF3ECE2),
                      shadows: [
                        const Shadow(
                          color: Color(0xFFFF6A2C),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                leading: IconButton(
                  icon:
                      const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => context.go('/dashboard'),
                ),
              ),

              // Overview Stats Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 10.0),
                  child: membersAsync.when(
                    data: (members) {
                      final activeCount = members
                          .where((m) => m.status == MemberStatus.active)
                          .length;
                      final suspendedCount = members
                          .where((m) => m.status == MemberStatus.suspended)
                          .length;

                      return Row(
                        children: [
                          Expanded(
                            child: _buildGlassStatCard(
                              context,
                              title: 'Total Members',
                              value: members.length.toString(),
                              icon: Icons.people_alt_rounded,
                              accentColor: const Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildGlassStatCard(
                              context,
                              title: 'Active Members',
                              value: activeCount.toString(),
                              icon: Icons.verified_user_rounded,
                              accentColor: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'Error loading stats: $e',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ),
              ),

              // Second Row of Overview Stats (Archives & Audits)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: archivesAsync.when(
                          data: (archives) => _buildGlassStatCard(
                            context,
                            title: 'Fest Database Years',
                            value: '${archives.length} / 4',
                            icon: Icons.storage_rounded,
                            accentColor: const Color(0xFFF59E0B),
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => const SizedBox(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: auditLogsAsync.when(
                          data: (logs) => _buildGlassStatCard(
                            context,
                            title: 'Total Audits',
                            value: logs.length.toString(),
                            icon: Icons.history_edu_rounded,
                            accentColor: const Color(0xFFEC4899),
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => const SizedBox(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Authentication Control (Super Admin)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, top: 8, bottom: 12),
                  child: _AuthControlSummaryCard(
                    onManage: () => context.push('/admin/auth-control'),
                  ),
                ),
              ),

              // Quick Actions Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, top: 24, bottom: 12),
                  child: Text(
                    'Administrative Controls',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF3ECE2),
                    ),
                  ),
                ),
              ),

              // Quick Actions Grid
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: r.w(20)),
                sliver: SliverGrid.count(
                  crossAxisCount: r.isSmall ? 1 : 2,
                  mainAxisSpacing: r.h(16),
                  crossAxisSpacing: r.w(16),
                  childAspectRatio: r.isSmall ? 2.0 : 1.15,
                  children: [
                    _buildQuickActionCard(
                      context,
                      title: 'Authentication',
                      subtitle: 'Open or close sign-in & registration',
                      icon: Icons.lock_clock_rounded,
                      color: const Color(0xFF3B82F6),
                      route: '/admin/auth-control',
                    ),
                    _buildQuickActionCard(
                      context,
                      title: 'Pending Approvals',
                      subtitle: 'Review new member profile requests',
                      icon: Icons.person_add_alt_1_rounded,
                      color: const Color(0xFFF59E0B),
                      route: '/admin/pending',
                    ),
                    _buildQuickActionCard(
                      context,
                      title: 'Member Management',
                      subtitle: 'Add, edit, & suspend club members',
                      icon: Icons.group_add_rounded,
                      color: const Color(0xFFFF6A2C),
                      route: '/admin/members',
                    ),
                    _buildQuickActionCard(
                      context,
                      title: 'Sarvottam Points',
                      subtitle: 'Manage points & leaderboards',
                      icon: Icons.workspace_premium_rounded,
                      color: const Color(0xFFFFB14D),
                      route: '/admin/points',
                    ),
                    _buildQuickActionCard(
                      context,
                      title: 'Year Database',
                      subtitle: 'Rotate & archive fest data (Max 4)',
                      icon: Icons.cloud_done_rounded,
                      color: const Color(0xFFEC4899),
                      route: '/admin/yearly',
                    ),
                    _buildQuickActionCard(
                      context,
                      title: 'Historical Import',
                      subtitle: 'Import CSV archives into systems',
                      icon: Icons.upload_file_rounded,
                      color: const Color(0xFF6FAE8F),
                      route: '/admin/import',
                    ),
                    _buildQuickActionCard(
                      context,
                      title: 'Fest Rulebook',
                      subtitle: 'Upload and manage PDF rulebook',
                      icon: Icons.picture_as_pdf_rounded,
                      color: const Color(0xFF10B981),
                      route: '/admin/rulebook',
                    ),
                  ],
                ),
              ),

              // Audit Logs & Activity Feed Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, top: 32, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Governance Audit Log',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF3ECE2),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/admin/audit'),
                        child: Text(
                          'View All',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFFF6A2C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Feed list
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                sliver: auditLogsAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'No audit logs available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    }

                    // Display only the first 5 logs
                    final recentLogs = logs.take(5).toList();
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final log = recentLogs[index];
                          return _buildAuditListItem(log);
                        },
                        childCount: recentLogs.length,
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'Failed to load audit logs: $e',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF262220),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C857C),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF3ECE2),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF262220),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: EdgeInsets.all(r.w(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 26,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF3ECE2),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C857C),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuditListItem(AuditExtended log) {
    final dateStr = DateFormat('MMM d, h:mm a').format(log.createdAt);

    // Choose icon based on action
    IconData actionIcon;
    Color iconColor;
    switch (log.action.toUpperCase()) {
      case 'CREATE':
        actionIcon = Icons.add_circle_outline_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      case 'UPDATE':
        actionIcon = Icons.edit_note_rounded;
        iconColor = const Color(0xFF3B82F6);
        break;
      case 'DELETE':
        actionIcon = Icons.remove_circle_outline_rounded;
        iconColor = const Color(0xFFEF4444);
        break;
      default:
        actionIcon = Icons.history_rounded;
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1A18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF262220),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              actionIcon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${log.action} ${log.entityType.toUpperCase()}',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF3ECE2),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C857C),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _getAuditSummary(log),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C857C),
                    fontSize: 12,
                  ),
                ),
                if (log.userEmail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'By: ${log.userEmail}',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFFF6A2C).withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getAuditSummary(AuditExtended log) {
    if (log.newValue != null) {
      if (log.entityType == 'member_assignments') {
        final role = log.newValue!['role'] ?? 'Unknown';
        final status = log.newValue!['status'] ?? 'Unknown';
        return 'Role assigned: $role (Status: $status)';
      } else if (log.entityType == 'event_points') {
        final points = log.newValue!['points'] ?? 0;
        final reason = log.newValue!['reason'] ?? '';
        return 'Allocated $points points. Reason: $reason';
      }
    }
    return 'Entity ID: ${log.entityId ?? "unknown"}';
  }
}

class _AuthControlSummaryCard extends ConsumerWidget {
  final VoidCallback onManage;

  const _AuthControlSummaryCard({required this.onManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(authSettingsProvider);

    return settingsAsync.when(
      loading: () => const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (settings) {
        final signInOpen = settings.signInEnabled;
        final registrationOpen = settings.registrationEnabled;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1D1A18),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF262220)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onManage,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.lock_clock_rounded,
                        color: Color(0xFF3B82F6),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Authentication Control',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFF3ECE2),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _StatusChip(
                                label: 'Sign In',
                                isOpen: signInOpen,
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(
                                label: 'Registration',
                                isOpen: registrationOpen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF8C857C)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isOpen;

  const _StatusChip({required this.label, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: ${isOpen ? 'Open' : 'Closed'}',
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
