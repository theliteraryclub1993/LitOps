import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/responsive.dart';


import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/utils/app_utils.dart';
import '../../auth/providers/auth_provider.dart';

final eventDetailProvider = StreamProvider.family<Event, String>((ref, eventId) async* {
  print('📡 [Realtime] eventDetailProvider starting for $eventId');
  bool hasData = false;
  try {
    final res = await SupabaseConfig.client
        .from(SupabaseTables.events)
        .select()
        .eq('id', eventId)
        .maybeSingle();
    if (res != null) {
      yield Event.fromJson(res);
      hasData = true;
    }
  } catch (e) {
    print('⚠️ [Realtime] eventDetailProvider initial REST fetch failed: $e');
  }

  while (true) {
    try {
      final stream = SupabaseConfig.client
          .from(SupabaseTables.events)
          .stream(primaryKey: ['id'])
          .eq('id', eventId);

      await for (final data in stream) {
        print('📡 [Realtime] eventDetailProvider received data: $data');
        if (data.isNotEmpty) {
          yield Event.fromJson(data.first);
          hasData = true;
        }
      }
    } catch (e) {
      print('❌ [Realtime] eventDetailProvider stream error: $e');
      try {
        final res = await SupabaseConfig.client
            .from(SupabaseTables.events)
            .select()
            .eq('id', eventId)
            .maybeSingle();
        if (res != null) {
          yield Event.fromJson(res);
          hasData = true;
        }
      } catch (restError) {
        print('⚠️ [Realtime] eventDetailProvider backup REST fetch failed: $restError');
      }

      if (!hasData) {
        rethrow;
      }
      print('📡 [Realtime] eventDetailProvider retrying subscription in 5 seconds...');
      await Future.delayed(const Duration(seconds: 5));
    }
  }
});

final eventRegistrationsCountProvider = StreamProvider.family<int, String>((ref, eventId) async* {
  print('📡 [Realtime] eventRegistrationsCountProvider starting for $eventId');
  bool hasData = false;
  try {
    final res = await SupabaseConfig.client
        .from(SupabaseTables.registrations)
        .select()
        .eq('event_id', eventId);
    final count = res.where((r) => r['is_cancelled'] == false).length;
    yield count;
    hasData = true;
  } catch (e) {
    print('⚠️ [Realtime] eventRegistrationsCountProvider initial REST fetch failed: $e');
  }

  while (true) {
    try {
      final stream = SupabaseConfig.client
          .from(SupabaseTables.registrations)
          .stream(primaryKey: ['id'])
          .eq('event_id', eventId);

      await for (final data in stream) {
        final count = data.where((r) => r['is_cancelled'] == false).length;
        yield count;
        hasData = true;
      }
    } catch (e) {
      print('❌ [Realtime] eventRegistrationsCountProvider stream error: $e');
      try {
        final res = await SupabaseConfig.client
            .from(SupabaseTables.registrations)
            .select()
            .eq('event_id', eventId);
        final count = res.where((r) => r['is_cancelled'] == false).length;
        yield count;
        hasData = true;
      } catch (restError) {
        print('⚠️ [Realtime] eventRegistrationsCountProvider backup REST fetch failed: $restError');
      }

      if (!hasData) {
        rethrow;
      }
      print('📡 [Realtime] eventRegistrationsCountProvider retrying subscription in 5 seconds...');
      await Future.delayed(const Duration(seconds: 5));
    }
  }
});

final eventAttendanceCountProvider = StreamProvider.family<int, String>((ref, eventId) async* {
  print('📡 [Realtime] eventAttendanceCountProvider starting for $eventId');
  bool hasData = false;
  try {
    final res = await SupabaseConfig.client
        .from(SupabaseTables.attendance)
        .select()
        .eq('event_id', eventId);
    yield res.length;
    hasData = true;
  } catch (e) {
    print('⚠️ [Realtime] eventAttendanceCountProvider initial REST fetch failed: $e');
  }

  while (true) {
    try {
      final stream = SupabaseConfig.client
          .from(SupabaseTables.attendance)
          .stream(primaryKey: ['id'])
          .eq('event_id', eventId);

      await for (final data in stream) {
        yield data.length;
        hasData = true;
      }
    } catch (e) {
      print('❌ [Realtime] eventAttendanceCountProvider stream error: $e');
      try {
        final res = await SupabaseConfig.client
            .from(SupabaseTables.attendance)
            .select()
            .eq('event_id', eventId);
        yield res.length;
        hasData = true;
      } catch (restError) {
        print('⚠️ [Realtime] eventAttendanceCountProvider backup REST fetch failed: $restError');
      }

      if (!hasData) {
        rethrow;
      }
      print('📡 [Realtime] eventAttendanceCountProvider retrying subscription in 5 seconds...');
      await Future.delayed(const Duration(seconds: 5));
    }
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
    final year = profile?.year;
    final isAllowedToRegister = role.canRegisterParticipants || (year != null && year >= 1 && year <=4);

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
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: context.r.sp(16), color: LitColors.bone),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: LitColors.bone),
            onPressed: () {
              ref.invalidate(eventDetailProvider(eventId));
              ref.invalidate(eventRegistrationsCountProvider(eventId));
              ref.invalidate(eventAttendanceCountProvider(eventId));
            },
          ),
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
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(eventDetailProvider(eventId));
                    ref.invalidate(eventRegistrationsCountProvider(eventId));
                    ref.invalidate(eventAttendanceCountProvider(eventId));
                    try {
                      await ref.read(eventDetailProvider(eventId).future);
                    } catch (_) {}
                  },
                  color: LitColors.ember,
                  backgroundColor: LitColors.clay,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: context.r.pageInsets,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category and Status chips row
                      Row(
                        children: [
                          CategoryChip(category: event.category.value),
                          SizedBox(width: context.r.w(8)),
                          if (role.canManageEvents || profile?.year == 4)
                            Flexible(
                              child: GestureDetector(
                                onTap: () async {
                                  final newStatus = await showModalBottomSheet<EventStatus>(
                                    context: context,
                                    useRootNavigator: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (ctx) => ClayCard(
                                      color: LitColors.clay,
                                      padding: EdgeInsets.fromLTRB(context.r.w(16), context.r.h(16), context.r.w(16), context.r.h(16) + context.r.bottomSafeArea),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Change Status',
                                            style: GoogleFonts.fredoka(
                                              fontWeight: FontWeight.bold,
                                              fontSize: context.r.sp(16),
                                              color: LitColors.bone,
                                            ),
                                          ),
                                          SizedBox(height: context.r.h(16)),
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
                      SizedBox(height: context.r.h(12)),

                      // Wavy Poster Block
                      Container(
                        height: context.r.h(120),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [LitColors.clay3, LitColors.clay],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(context.r.radius(16)),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _getCategoryIcon(event.category),
                          color: LitColors.ember,
                          size: context.r.icon(38),
                        ),
                      ),
                      SizedBox(height: context.r.h(16)),

                      Text(
                        event.name,
                        style: GoogleFonts.fredoka(
                          fontSize: context.r.sp(20),
                          fontWeight: FontWeight.bold,
                          color: LitColors.bone,
                        ),
                      ),
                      SizedBox(height: context.r.h(8)),

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
                      SizedBox(height: context.r.h(12)),

                      // Description
                      if (event.description != null)
                        Text(
                          event.description!,
                          style: GoogleFonts.plusJakartaSans(
                            color: LitColors.ash,
                            fontSize: context.r.sp(12),
                            height: 1.5,
                          ),
                        ),
                      SizedBox(height: context.r.h(16)),

                      // Details Grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: context.r.isSmall ? 1 : 2,
                        crossAxisSpacing: context.r.w(8),
                        mainAxisSpacing: context.r.h(8),
                        childAspectRatio: context.r.isSmall ? 3.5 : 2.2,
                        children: [
                          _buildDetailStat(context, 'VENUE', event.venue ?? 'TBD'),
                          _buildDetailStat(context, 'DATE', event.eventDate != null ? AppUtils.formatDate(event.eventDate!) : 'TBD'),
                          _buildDetailStat(context, 'TEAM SIZE', '${event.teamSize}'),
                          _buildDetailStat(context, 'CAPACITY', event.capacity != null ? '${event.capacity}' : 'Unlimited'),
                        ],
                      ),
                      SizedBox(height: context.r.h(16)),

                      // Rules collapsible card
                      if (event.rules != null)
                        ClayInsetCard(
                          borderRadius: context.r.radius(14),
                          padding: EdgeInsets.symmetric(horizontal: context.r.w(14), vertical: context.r.h(12)),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Text(
                                'Rules & Eligibility',
                                style: GoogleFonts.plusJakartaSans(
                                  color: LitColors.bone,
                                  fontSize: context.r.sp(12),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              iconColor: LitColors.ash,
                              collapsedIconColor: LitColors.ash,
                              tilePadding: EdgeInsets.zero,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: context.r.h(8.0)),
                                  child: Text(
                                    event.rules!,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: LitColors.ash,
                                      fontSize: context.r.sp(11.5),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(height: context.r.h(16)),

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
            ),

              // Bottom Register Bar
              Container(
                padding: EdgeInsets.all(context.r.w(16)),
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
                      if (isAllowedToRegister) ...[
                        ClayButton(
                          onPressed: () => context.go('/registration', extra: event),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner, size: context.r.icon(16)),
                              SizedBox(width: context.r.w(8)),
                              const Text('Register Now'),
                            ],
                          ),
                        ),
                        SizedBox(height: context.r.h(8)),
                        Text(
                          'Waitlist enabled · Secured by Supabase Auth',
                          style: GoogleFonts.plusJakartaSans(
                            color: LitColors.ash,
                            fontSize: context.r.sp(10),
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
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(eventDetailProvider(eventId));
            ref.invalidate(eventRegistrationsCountProvider(eventId));
            ref.invalidate(eventAttendanceCountProvider(eventId));
          },
        ),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, String text, bool active, VoidCallback? onTap) {
    final r = Responsive(context);
    final content = Container(
      margin: EdgeInsets.only(right: r.w(6)),
      padding: EdgeInsets.symmetric(horizontal: r.w(14), vertical: r.h(8)),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(colors: [LitColors.ember, LitColors.emberDark])
            : null,
        color: active ? null : LitColors.clay2,
        borderRadius: BorderRadius.circular(r.radius(12)),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: active ? const Color(0xFF1A0D05) : LitColors.ash,
          fontWeight: active ? FontWeight.bold : FontWeight.w600,
          fontSize: r.sp(10.5),
        ),
      ),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }

  Widget _buildDetailStat(BuildContext context, String label, String value) {
    final r = Responsive(context);
    return Container(
      padding: EdgeInsets.all(r.w(10)),
      decoration: BoxDecoration(
        color: LitColors.clay2,
        borderRadius: BorderRadius.circular(r.radius(14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(4, 4),
            blurRadius: 9,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.02),
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
              fontSize: r.sp(8.5),
              fontWeight: FontWeight.bold,
              color: LitColors.ash,
              letterSpacing: 0.04,
            ),
          ),
          SizedBox(height: r.h(2)),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: r.sp(12),
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
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(bottom: r.h(10)),
      child: ClayButton(
        isGhost: true,
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: r.icon(16)),
            SizedBox(width: r.w(8)),
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
    final confirm = await ConfirmDialog.show(
      context,
      title: 'Delete Event',
      message: 'Are you sure? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: LitColors.coral,
      onConfirm: () {},
    );
    if (confirm == true) {
      await SupabaseConfig.client.from(SupabaseTables.events).delete().eq('id', eventId);
      if (context.mounted) {
        context.go('/events');
      }
    }
  }
}
