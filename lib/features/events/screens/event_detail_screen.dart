import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/widgets/common_widgets.dart';


import '../../../core/theme/theme.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/utils/app_utils.dart';
import '../../auth/providers/auth_provider.dart';

final eventDetailProvider = StreamProvider.family<Event, String>((ref, eventId) async* {
  print('📡 [Realtime] eventDetailProvider starting for $eventId');
  try {
    final stream = SupabaseConfig.client
        .from(SupabaseTables.events)
        .stream(primaryKey: ['id'])
        .eq('id', eventId);

    await for (final data in stream) {
      print('📡 [Realtime] eventDetailProvider received data: $data');
      if (data.isNotEmpty) {
        yield Event.fromJson(data.first);
      }
    }
  } catch (e) {
    print('❌ [Realtime] eventDetailProvider error: $e');
    rethrow;
  }
});

final eventRegistrationsCountProvider = StreamProvider.family<int, String>((ref, eventId) async* {
  final stream = SupabaseConfig.client
      .from(SupabaseTables.registrations)
      .stream(primaryKey: ['id'])
      .eq('event_id', eventId);

  await for (final data in stream) {
    final count = data.where((r) => r['is_cancelled'] == false).length;
    yield count;
  }
});

final eventAttendanceCountProvider = StreamProvider.family<int, String>((ref, eventId) async* {
  final stream = SupabaseConfig.client
      .from(SupabaseTables.attendance)
      .stream(primaryKey: ['id'])
      .eq('event_id', eventId);

  await for (final data in stream) {
    yield data.length;
  }
});

class EventDetailScreen extends ConsumerWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final regCountAsync = ref.watch(eventRegistrationsCountProvider(eventId));
    final attCountAsync = ref.watch(eventAttendanceCountProvider(eventId));
    final role = ref.watch(currentUserRoleProvider);
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: LitColors.bone),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Event Details',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16, color: LitColors.bone),
        ),
        actions: [
          if (role.canManageEvents || profile?.year == 4)
            PopupMenuButton<String>(
              color: LitColors.clay,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: LitColors.border, width: 1.3),
              ),
              icon: const Icon(Icons.more_vert, color: LitColors.bone),
              onSelected: (value) async {
                if (value == 'command') {
                  context.push('/command-center/$eventId');
                } else if (value == 'report') {
                  context.push('/reports/$eventId');
                } else if (value == 'rounds') {
                  context.push('/rounds/$eventId');
                } else if (value == 'assign') {
                  final event = eventAsync.value;
                  if (event != null) {
                    context.push('/assignments', extra: event);
                  }
                } else if (value == 'edit') {
                  final event = eventAsync.value;
                  if (event != null) {
                    context.push('/events/$eventId/edit', extra: event);
                  }
                } else if (value == 'duplicate') {
                  _duplicateEvent(context, ref);
                } else if (value == 'archive') {
                  _archiveEvent(context, ref);
                } else if (value == 'delete') {
                  _deleteEvent(context, ref);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'command',
                  child: Row(
                    children: [
                      const Icon(Icons.monitor, color: LitColors.ash, size: 18),
                      const SizedBox(width: 12),
                      Text('Command Center', style: GoogleFonts.plusJakartaSans(color: LitColors.bone)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'rounds',
                  child: Row(
                    children: [
                      const Icon(Icons.layers, color: LitColors.ash, size: 18),
                      const SizedBox(width: 12),
                      Text('Rounds', style: GoogleFonts.plusJakartaSans(color: LitColors.bone)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: LitColors.ash, size: 18),
                      const SizedBox(width: 12),
                      Text('Generate Report', style: GoogleFonts.plusJakartaSans(color: LitColors.bone)),
                    ],
                  ),
                ),
                if (role.canAssignMembers || profile?.year == 4)
                  PopupMenuItem(
                    value: 'assign',
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_ind, color: LitColors.ash, size: 18),
                        const SizedBox(width: 12),
                        Text('Assign Crew', style: GoogleFonts.plusJakartaSans(color: LitColors.bone)),
                      ],
                    ),
                  ),
                if (role.canCreateEvents)
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, color: LitColors.ash, size: 18),
                        const SizedBox(width: 12),
                        Text('Edit Event', style: GoogleFonts.plusJakartaSans(color: LitColors.bone)),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      const Icon(Icons.copy, color: LitColors.ash, size: 18),
                      const SizedBox(width: 12),
                      Text('Duplicate', style: GoogleFonts.plusJakartaSans(color: LitColors.bone)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      const Icon(Icons.archive, color: LitColors.ash, size: 18),
                      const SizedBox(width: 12),
                      Text('Archive', style: GoogleFonts.plusJakartaSans(color: LitColors.bone)),
                    ],
                  ),
                ),
                if (role.isAdmin)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, color: LitColors.coral, size: 18),
                        const SizedBox(width: 12),
                        Text('Delete', style: GoogleFonts.plusJakartaSans(color: LitColors.coral)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: eventAsync.when(
        data: (event) {
          final isOngoing = event.status == EventStatus.ongoing;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category and Status chips row
                      Row(
                        children: [
                          CategoryChip(category: event.category.value),
                          const SizedBox(width: 8),
                          if (role.canManageEvents || profile?.year == 4)
                            Flexible(
                              child: GestureDetector(
                                onTap: () async {
                                  final newStatus = await showModalBottomSheet<EventStatus>(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (ctx) => ClayCard(
                                      color: LitColors.clay,
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Change Status',
                                            style: GoogleFonts.fredoka(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: LitColors.bone,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ...EventStatus.values.map((status) {
                                            return ListTile(
                                              title: Text(status.label),
                                              leading: event.status == status
                                                  ? const Icon(Icons.check_circle, color: LitColors.moss)
                                                  : null,
                                              onTap: () {
                                                Navigator.pop(ctx, status);
                                              },
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (newStatus != null) {
                                    await SupabaseConfig.client
                                        .from(SupabaseTables.events)
                                        .update({
                                          'status': newStatus.value,
                                          'updated_at': DateTime.now().toIso8601String()
                                        })
                                        .eq('id', eventId);
                                  }
                                },
                                child: StatusChip(label: event.status.label),
                              ),
                            )
                          else
                            StatusChip(label: event.status.label),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Wavy Poster Block
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [LitColors.clay3, LitColors.clay],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _getCategoryIcon(event.category),
                          color: LitColors.ember,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        event.name,
                        style: GoogleFonts.fredoka(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: LitColors.bone,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tabs Layout
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTabItem(context, 'Overview', true, null),
                            _buildTabItem(context, 'Participants', false, () => context.push('/events/$eventId/participants', extra: event)),
                            _buildTabItem(context, 'Rounds', false, () => context.push('/rounds/$eventId')),
                            _buildTabItem(context, 'Results', false, () => context.push('/results/score/$eventId')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      if (event.description != null)
                        Text(
                          event.description!,
                          style: GoogleFonts.plusJakartaSans(
                            color: LitColors.ash,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Details Grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.2,
                        children: [
                          _buildDetailStat('VENUE', event.venue ?? 'TBD'),
                          _buildDetailStat('DATE', event.eventDate != null ? AppUtils.formatDate(event.eventDate!) : 'TBD'),
                          _buildDetailStat('TEAM SIZE', '${event.teamSize}'),
                          _buildDetailStat('CAPACITY', event.capacity != null ? '${event.capacity}' : 'Unlimited'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Rules collapsible card
                      if (event.rules != null)
                        ClayInsetCard(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Text(
                                'Rules & Eligibility',
                                style: GoogleFonts.plusJakartaSans(
                                  color: LitColors.bone,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              iconColor: LitColors.ash,
                              collapsedIconColor: LitColors.ash,
                              tilePadding: EdgeInsets.zero,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    event.rules!,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: LitColors.ash,
                                      fontSize: 11.5,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Operation quick link buttons
                      _buildOperationButton(
                        context,
                        'Waiting List',
                        Icons.hourglass_empty,
                        () => context.push('/waiting-list/$eventId'),
                      ),
                      _buildOperationButton(
                        context,
                        'Results Board',
                        Icons.emoji_events,
                        () => context.push('/results/score/$eventId'),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Register Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF141110),
                  border: Border(
                    top: BorderSide(color: Color(0xFF262220), width: 1.0),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (role.canRegisterParticipants) ...[
                        ClayButton(
                          onPressed: () => context.go('/registration', extra: event),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner, size: 16),
                              SizedBox(width: 8),
                              Text('Register Now'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Waitlist enabled · Secured by Supabase Auth',
                          style: GoogleFonts.plusJakartaSans(
                            color: LitColors.ash,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, String text, bool active, VoidCallback? onTap) {
    final content = Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(colors: [LitColors.ember, LitColors.emberDark])
            : null,
        color: active ? null : LitColors.clay2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: active ? const Color(0xFF1A0D05) : LitColors.ash,
          fontWeight: active ? FontWeight.bold : FontWeight.w600,
          fontSize: 10.5,
        ),
      ),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }

  Widget _buildDetailStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LitColors.clay2,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(4, 4),
            blurRadius: 9,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.02),
            offset: const Offset(-2, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: LitColors.ash,
              letterSpacing: 0.04,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              color: LitColors.bone,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClayButton(
        isGhost: true,
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(EventCategory category) {
    switch (category) {
      case EventCategory.balwaan:
        return Icons.fitness_center;
      case EventCategory.buddhimaan:
        return Icons.lightbulb_outline;
      case EventCategory.darpan:
        return Icons.mic_none;
      case EventCategory.kalakruthi:
        return Icons.palette_outlined;
    }
  }

  Future<void> _duplicateEvent(BuildContext context, WidgetRef ref) async {
    final event = ref.read(eventDetailProvider(eventId)).value;
    if (event == null) return;
    final client = SupabaseConfig.client;
    final userId = ref.read(authStateProvider).profile!.id;
    await client.from(SupabaseTables.events).insert({
      ...event.toJson(),
      'id': null,
      'title': '${event.name} (Copy)',
      'status': 'draft',
      'created_by': userId,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event duplicated')));
      ref.invalidate(eventDetailProvider(eventId));
    }
  }

  Future<void> _archiveEvent(BuildContext context, WidgetRef ref) async {
    await SupabaseConfig.client.from(SupabaseTables.events).update({'status': 'archived'}).eq('id', eventId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event archived')));
      ref.invalidate(eventDetailProvider(eventId));
    }
  }

  Future<void> _deleteEvent(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LitColors.clay,
        title: Text('Delete Event', style: GoogleFonts.fredoka(color: LitColors.bone)),
        content: Text('Are you sure? This action cannot be undone.', style: GoogleFonts.plusJakartaSans(color: LitColors.ash)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: LitColors.ash))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: LitColors.coral), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseConfig.client.from(SupabaseTables.events).delete().eq('id', eventId);
      if (context.mounted) {
        context.go('/events');
      }
    }
  }
}
