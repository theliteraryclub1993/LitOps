import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/utils/responsive.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final offlineBox = Hive.box('offline_attendance');
    final offlineCount = offlineBox.length;
    final r = context.r;

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.fredoka(
            color: LitColors.bone,
            fontWeight: FontWeight.bold,
            fontSize: r.sp(16),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: r.w(16),
          right: r.w(16),
          top: r.h(16),
          bottom: r.listBottomPadding,
        ),
        children: [
          // Profile Section
          Text(
            'Account',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              fontSize: r.sp(14),
              color: LitColors.bone,
            ),
          ),
          SizedBox(height: r.h(8)),
          ClayCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person, color: LitColors.ember, size: r.icon(20)),
                  title: Text(
                    'Profile',
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.bone,
                      fontSize: r.sp(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    profile?.fullName ?? 'Loading...',
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.ash,
                      fontSize: r.sp(11),
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, color: LitColors.ash, size: r.icon(20)),
                  onTap: () => context.go('/profile'),
                ),
                Divider(height: 1, color: LitColors.border),
                ListTile(
                  leading: Icon(Icons.admin_panel_settings, color: LitColors.ember, size: r.icon(20)),
                  title: Text(
                    'Role',
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.bone,
                      fontSize: r.sp(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    profile?.role.label ?? 'Loading...',
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.ash,
                      fontSize: r.sp(11),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: r.h(24)),
          // Offline Data
          Text(
            'Offline Data',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              fontSize: r.sp(14),
              color: LitColors.bone,
            ),
          ),
          SizedBox(height: r.h(8)),
          ClayCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.cloud_off, color: LitColors.amber, size: r.icon(20)),
                  title: Text(
                    'Pending Offline Records',
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.bone,
                      fontSize: r.sp(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '$offlineCount records waiting to sync',
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.ash,
                      fontSize: r.sp(11),
                    ),
                  ),
                  trailing: offlineCount > 0
                      ? ClayButton(
                          width: r.w(90),
                          height: r.h(32),
                          onPressed: () => _syncOffline(context),
                          child: Text(
                            'Sync Now',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: r.sp(11),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Icon(Icons.check_circle, color: LitColors.moss, size: r.icon(20)),
                ),
              ],
            ),
          ),

          SizedBox(height: r.h(24)),
          // Database Management
          if (profile?.role.canManageDatabase == true) ...[
            Text(
              'Database',
              style: GoogleFonts.fredoka(
                fontWeight: FontWeight.bold,
                fontSize: r.sp(14),
                color: LitColors.bone,
              ),
            ),
            SizedBox(height: r.h(8)),
            ClayCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.storage, color: LitColors.amber, size: r.icon(20)),
                    title: Text(
                      'Student Database Management',
                      style: GoogleFonts.plusJakartaSans(
                        color: LitColors.bone,
                        fontSize: r.sp(13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: LitColors.ash, size: r.icon(20)),
                    onTap: () => context.push('/students/manage'),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.h(24)),
          ],

          // Notifications
          Text(
            'Notifications',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              fontSize: r.sp(14),
              color: LitColors.bone,
            ),
          ),
          SizedBox(height: r.h(8)),
          ClayCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.notifications, color: LitColors.amber, size: r.icon(20)),
                  title: Text(
                    'Notifications',
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.bone,
                      fontSize: r.sp(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, color: LitColors.ash, size: r.icon(20)),
                  onTap: () => _showNotifications(context),
                ),
              ],
            ),
          ),

          SizedBox(height: r.h(24)),
          // About
          Text(
            'About',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              fontSize: r.sp(14),
              color: LitColors.bone,
            ),
          ),
          SizedBox(height: r.h(8)),
          ClayCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info, color: LitColors.ember, size: r.icon(20)),
                  title: Text(
                    'Lit Life',
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.bone,
                      fontSize: r.sp(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Event Operations Platform\nThe Literary Club, Malnad College of Engineering\nVersion 1.0.0',
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.ash,
                      fontSize: r.sp(11),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: r.h(32)),
          // Logout
          ClayButton(
            onPressed: () => _confirmLogout(context, ref),
            isDanger: true,
            height: r.h(45),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, size: r.icon(16)),
                SizedBox(width: r.w(8)),
                Text(
                  'Sign Out',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: r.sp(13),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(24)),
        ],
      ),
    );
  }

  Future<void> _syncOffline(BuildContext context) async {
    final box = Hive.box('offline_attendance');
    final keysToDelete = [];
    int synced = 0;
    int failed = 0;

    for (var key in box.keys) {
      final record = box.get(key);
      if (record != null) {
        try {
          await SupabaseConfig.client.from(SupabaseTables.attendance).insert({
            'event_id': record['event_id'],
            'registration_id': record['registration_id'],
            'student_id': record['student_id'],
            'marked_by': record['marked_by'],
            'method': record['method'] ?? 'barcode',
            'is_offline': true,
            'synced_at': DateTime.now().toIso8601String(),
          });
          keysToDelete.add(key);
          synced++;
        } catch (_) {
          failed++;
        }
      }
    }

    for (var key in keysToDelete) {
      await box.delete(key);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced: $synced, Failed: $failed'),
          backgroundColor: failed > 0 ? LitColors.coral : LitColors.moss,
        ),
      );
    }
  }

  Future<void> _showNotifications(BuildContext context) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NotificationsSheet(userId: userId),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    await ConfirmDialog.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmText: 'Sign Out',
      confirmColor: LitColors.coral,
      onConfirm: () => ref.read(authStateProvider.notifier).signOut(),
    );
  }
}

class _NotificationsSheet extends StatefulWidget {
  final String userId;
  const _NotificationsSheet({required this.userId});

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await SupabaseConfig.client
          .from(SupabaseTables.notifications)
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _notifications = data as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await SupabaseConfig.client
          .from(SupabaseTables.notifications)
          .update({'is_read': true})
          .eq('id', id);

      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: LitColors.clay,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          SizedBox(height: r.h(12)),
          Container(
            width: r.w(40),
            height: r.h(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(r.radius(2)),
            ),
          ),
          SizedBox(height: r.h(16)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.w(24)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(r.w(8)),
                  decoration: BoxDecoration(
                    color: LitColors.ember.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.radius(12)),
                  ),
                  child: Icon(Icons.notifications_active_rounded, color: LitColors.ember, size: r.icon(20)),
                ),
                SizedBox(width: r.w(16)),
                Text(
                  'Notifications',
                  style: GoogleFonts.fredoka(
                    fontSize: r.sp(20),
                    fontWeight: FontWeight.bold,
                    color: LitColors.bone,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: LitColors.ash, size: r.icon(20)),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(16)),
          Divider(height: 1, color: LitColors.border),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: LitColors.ember))
                : _notifications.isEmpty
                    ? const EmptyView(
                        icon: Icons.notifications_off_outlined,
                        title: "You're all caught up!",
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(r.w(24), r.w(24), r.w(24), r.w(24) + r.bottomSafeArea),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => SizedBox(height: r.h(16)),
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          final isRead = n['is_read'] == true;
                          final date = DateTime.parse(n['created_at']).toLocal();

                          // Quick rough 'time ago' calculation
                          final diff = DateTime.now().difference(date);
                          String timeAgo;
                          if (diff.inDays > 0) {
                            timeAgo = '${diff.inDays}d ago';
                          } else if (diff.inHours > 0) {
                            timeAgo = '${diff.inHours}h ago';
                          } else if (diff.inMinutes > 0) {
                            timeAgo = '${diff.inMinutes}m ago';
                          } else {
                            timeAgo = 'Just now';
                          }

                          return GestureDetector(
                            onTap: () {
                              if (!isRead) _markAsRead(n['id']);
                            },
                            child: Container(
                              padding: EdgeInsets.all(r.w(16)),
                              decoration: BoxDecoration(
                                color: isRead
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : LitColors.ember.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(r.radius(16)),
                                border: Border.all(
                                  color: isRead
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : LitColors.ember.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(r.w(10)),
                                    decoration: BoxDecoration(
                                      color: isRead
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : LitColors.ember,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isRead ? Icons.notifications_none : Icons.notifications,
                                      color: isRead ? Colors.white : const Color(0xFF1A0D05),
                                      size: r.icon(16),
                                    ),
                                  ),
                                  SizedBox(width: r.w(16)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                n['title'] ?? 'Notification',
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: LitColors.bone,
                                                  fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                                  fontSize: r.sp(14),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              timeAgo,
                                              style: GoogleFonts.plusJakartaSans(
                                                color: LitColors.ash,
                                                fontSize: r.sp(11),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: r.h(6)),
                                        Text(
                                          n['message'] ?? '',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: LitColors.bone.withValues(alpha: 0.7),
                                            fontSize: r.sp(12),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
