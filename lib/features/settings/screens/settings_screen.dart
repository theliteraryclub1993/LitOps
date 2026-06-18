import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final offlineBox = Hive.box('offline_attendance');
    final syncBox = Hive.box('sync_queue');
    final offlineCount = offlineBox.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Settings', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          Text('Account', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              subtitle: Text(profile?.fullName ?? 'Loading...'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/profile'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Role'),
              subtitle: Text(profile?.role.label ?? 'Loading...'),
            ),
          ])),

          const SizedBox(height: 24),
          // Offline Data
          Text('Offline Data', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.cloud_off),
              title: const Text('Pending Offline Records'),
              subtitle: Text('$offlineCount records waiting to sync'),
              trailing: offlineCount > 0
                  ? ElevatedButton(
                      onPressed: () => _syncOffline(context),
                      child: const Text('Sync Now'),
                    )
                  : const Icon(Icons.check_circle, color: Colors.green),
            ),
          ])),

          const SizedBox(height: 24),
          // Database Management
          if (profile?.role.canManageDatabase == true) ...[
            Text('Database', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(child: Column(children: [
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Student Database Management'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/students/manage'),
              ),
            ])),
            const SizedBox(height: 24),
          ],

          // Notifications
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showNotifications(context),
            ),
          ])),

          const SizedBox(height: 24),
          // About
          Text('About', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('Lit Life'),
              subtitle: Text('Event Operations Platform\nThe Literary Club, Malnad College of Engineering\nVersion 1.0.0'),
            ),
          ])),

          const SizedBox(height: 32),
          // Logout
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 24),
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
        SnackBar(content: Text('Synced: $synced, Failed: $failed'), backgroundColor: failed > 0 ? Colors.orange : Colors.green),
      );
    }
  }

  Future<void> _showNotifications(BuildContext context) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    if (!context.mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NotificationsSheet(userId: userId),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authStateProvider.notifier).signOut();
    }
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1535),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF818CF8)),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF818CF8)))
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(height: 16),
                            Text(
                              'You\'re all caught up!',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          final isRead = n['is_read'] == true;
                          final date = DateTime.parse(n['created_at']).toLocal();
                          
                          // Quick rough 'time ago' calculation
                          final diff = DateTime.now().difference(date);
                          String timeAgo;
                          if (diff.inDays > 0) {
                            timeAgo = '${diff.inDays}d ago';
                          } else if (diff.inHours > 0) timeAgo = '${diff.inHours}h ago';
                          else if (diff.inMinutes > 0) timeAgo = '${diff.inMinutes}m ago';
                          else timeAgo = 'Just now';

                          return GestureDetector(
                            onTap: () {
                              if (!isRead) _markAsRead(n['id']);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isRead 
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : const Color(0xFF6366F1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isRead 
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : const Color(0xFF818CF8).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isRead 
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : const Color(0xFF6366F1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isRead ? Icons.notifications_none : Icons.notifications,
                                      color: Colors.white,
                                      size: 16,
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
                                            Expanded(
                                              child: Text(
                                                n['title'] ?? 'Notification',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              timeAgo,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.4),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          n['message'] ?? '',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.7),
                                            fontSize: 13,
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
