import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/providers/admin_providers.dart';
import '../../../core/enums/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/config/role_config.dart';
import 'package:intl/intl.dart';

final _registrationsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.registrations).stream(primaryKey: ['id']));
final _eventsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.events).stream(primaryKey: ['id']));
final _assignmentsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.eventAssignments).stream(primaryKey: ['id']));

final activeProfilesStreamProvider = StreamProvider<List<Profile>>((ref) {
  return SupabaseConfig.client
      .from(SupabaseTables.profiles)
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .map((data) {
        final list = data.map((json) => Profile.fromJson(json)).toList();
        list.sort((a, b) {
          final levelA = a.role.hierarchyLevel;
          final levelB = b.role.hierarchyLevel;
          if (levelA != levelB) {
            return levelA.compareTo(levelB);
          }
          return a.fullName.compareTo(b.fullName);
        });
        return list;
      });
});

final rulebookStreamProvider = StreamProvider<Rulebook?>((ref) {
  return SupabaseConfig.client
      .from('rulebook')
      .stream(primaryKey: ['id'])
      .map((data) {
        if (data.isEmpty) return null;
        return Rulebook.fromJson(data.first);
      });
});

final ongoingEventsProvider = StreamProvider<List<Event>>((ref) {
  return SupabaseConfig.client
      .from(SupabaseTables.events)
      .stream(primaryKey: ['id'])
      .eq('status', EventStatus.ongoing.value)
      .map((data) => data.map((e) => Event.fromJson(e)).toList());
});

final myAssignedEventsProvider = FutureProvider<List<Event>>((ref) async {
  // Watch for any assignment changes to trigger a re-fetch
  ref.watch(_assignmentsStream);
  
  final profile = ref.read(currentProfileProvider);
  if (profile == null) return [];
  
  final data = await SupabaseConfig.client
      .from(SupabaseTables.eventAssignments)
      .select('*, events!inner(*)')
      .eq('user_id', profile.id);
      
  return (data as List).map((e) => Event.fromJson(e['events'] as Map<String, dynamic>)).toList();
});

final dashboardStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  // Re-run stats calculation whenever registrations or events change
  ref.watch(_registrationsStream);
  ref.watch(_eventsStream);

  try {
    final activeArchive = await ref.watch(activeYearlyArchiveProvider.future);
    final membersRes = await SupabaseConfig.client.from(SupabaseTables.profiles).select('id').eq('is_active', true);
    final membersCount = (membersRes as List).length;

    if (activeArchive != null) {
      return {
        'events': activeArchive.totalEvents,
        'registrations': activeArchive.totalRegistrations > 0 ? activeArchive.totalRegistrations : 1,
        'attendance': activeArchive.totalAttendance,
        'students': membersCount,
      };
    } else {
      // Fall back to counting all if no active archive exists
      final eventsRes = await SupabaseConfig.client.from(SupabaseTables.events).select('id');
      final registrationsRes = await SupabaseConfig.client.from(SupabaseTables.registrations).select('student_id').eq('is_cancelled', false);
      final attendanceRes = await SupabaseConfig.client.from(SupabaseTables.attendance).select('id');

      final events = (eventsRes as List).length;
      final uniqueRegisteredStudents = (registrationsRes as List).map((r) => r['student_id']).toSet().length;
      final att = (attendanceRes as List).length;

      return {
        'events': events,
        'registrations': uniqueRegisteredStudents > 0 ? uniqueRegisteredStudents : 1,
        'attendance': att,
        'students': membersCount,
      };
    }
  } catch (_) {
    return {
      'events': 12,
      'registrations': 458,
      'attendance': 392,
      'students': 8,
    };
  }
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleConfig = ref.watch(roleConfigProvider);
    final profile = roleConfig.profile;
    final statsAsync = ref.watch(dashboardStatsProvider);
    
    if (profile != null && !roleConfig.isCoreAdmin) {
      return _buildNonAdminDashboard(context, roleConfig, ref);
    }

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Image.asset(
          'assets/images/logo.png',
          height: context.r.h(32),
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: LitColors.bone, size: context.r.icon(20)),
            onPressed: () => context.push('/search'),
            tooltip: 'Global Search',
          ),
          SizedBox(width: context.r.w(4)),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: UserAvatar(
              name: profile?.fullName ?? 'U',
              imageUrl: profile?.photoUrl,
            ),
          ),
          SizedBox(width: context.r.w(16)),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(authStateProvider.notifier).refreshProfile();
              ref.invalidate(dashboardStatsProvider);
            },
            child: SingleChildScrollView(
              padding: context.r.pageInsets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, profile),
                  if (roleConfig.showAdminConsole) ...[
                    SizedBox(height: context.r.h(16)),
                    _FadeIn(delay: 100, child: _buildAdminConsoleCard(context)),
                  ],
                  SizedBox(height: context.r.h(16)),
                  _FadeIn(delay: 200, child: _buildBentoGrid(context, statsAsync, roleConfig.canViewAppeals && !roleConfig.isSuperAdmin)),
                  SizedBox(height: context.r.h(24)),
                  _FadeIn(delay: 300, child: _buildSectionTitle(context, 'Quick Services')),
                  SizedBox(height: context.r.h(8)),
                  _FadeIn(delay: 400, child: _buildServicesGrid(context, roleConfig, ref)),
                  SizedBox(height: context.r.h(24)),
                  if (roleConfig.showRulebookCard) ...[
                    _FadeIn(delay: 500, child: _buildRulebookCard(context, ref.watch(rulebookStreamProvider))),
                  ] else ...[
                    _FadeIn(delay: 500, child: const LiveRankingsWidget()),
                  ],
                  SizedBox(height: context.r.listBottomPadding),
                ],
              ),
            ),
          ),
          Positioned(
            right: context.r.w(24),
            bottom: context.r.h(120),
            child: GestureDetector(
              onTap: () => context.push('/registration'),
              child: Container(
                height: context.r.w(56),
                width: context.r.w(56),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [LitColors.ember, LitColors.emberDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: LitColors.ember.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: const Color(0xFF1A0D05),
                  size: context.r.icon(26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonAdminDashboard(BuildContext context, RoleConfig roleConfig, WidgetRef ref) {
    final profile = roleConfig.profile!;
    final ongoingAsync = ref.watch(ongoingEventsProvider);
    final assignedAsync = ref.watch(myAssignedEventsProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final r = context.r;

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Image.asset(
          'assets/images/logo.png',
          height: r.h(32),
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: LitColors.bone, size: r.icon(20)),
            onPressed: () => context.push('/search'),
            tooltip: 'Global Search',
          ),
          SizedBox(width: r.w(4)),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: UserAvatar(
              name: profile.fullName,
              imageUrl: profile.photoUrl,
            ),
          ),
          SizedBox(width: r.w(16)),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(authStateProvider.notifier).refreshProfile();
              ref.invalidate(ongoingEventsProvider);
              ref.invalidate(myAssignedEventsProvider);
              ref.invalidate(dashboardStatsProvider);
            },
            child: SingleChildScrollView(
              padding: r.pageInsets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, profile),
                  if (!roleConfig.isJunior) ...[
                    SizedBox(height: r.h(16)),
                    _FadeIn(
                      delay: 150,
                      child: _buildBentoGrid(
                        context,
                        statsAsync,
                        roleConfig.canViewAppeals && !roleConfig.isSuperAdmin,
                      ),
                    ),
                  ],
                  SizedBox(height: r.h(24)),
                  
                  _FadeIn(delay: 100, child: _buildSectionTitle(context, 'Ongoing Events')),
                  SizedBox(height: r.h(12)),
                  ongoingAsync.when(
                    data: (events) {
                      if (events.isEmpty) {
                        return _buildEmptyState(context, 'No events are currently running.');
                      }
                      return Column(
                        children: events.asMap().entries.map((entry) {
                          return _FadeIn(
                            delay: 150 + (entry.key * 50),
                            child: _buildEventCard(context, entry.value, true),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: LitColors.ember)),
                    error: (e, _) => Text('Error: $e', style: GoogleFonts.plusJakartaSans(color: LitColors.coral, fontSize: r.sp(13))),
                  ),
                  SizedBox(height: r.h(24)),

                  if (roleConfig.showMyAssignedEvents) ...[
                    _FadeIn(delay: 300, child: _buildSectionTitle(context, 'My Assigned Events')),
                    SizedBox(height: r.h(12)),
                    assignedAsync.when(
                      data: (events) {
                        if (events.isEmpty) {
                          return _buildEmptyState(context, 'You have no upcoming assignments.');
                        }
                        return Column(
                          children: events.asMap().entries.map((entry) {
                            return _FadeIn(
                              delay: 350 + (entry.key * 50),
                              child: _buildEventCard(context, entry.value, false),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: LitColors.ember)),
                      error: (e, _) => Text('Error: $e', style: GoogleFonts.plusJakartaSans(color: LitColors.coral, fontSize: r.sp(13))),
                    ),
                    SizedBox(height: r.h(24)),
                  ],
                  
                  _FadeIn(delay: 500, child: _buildSectionTitle(context, 'Quick Services')),
                  SizedBox(height: r.h(12)),
                  _FadeIn(delay: 600, child: _buildNonAdminServicesGrid(context, roleConfig, ref)),
                  SizedBox(height: r.h(24)),
                  if (roleConfig.showRulebookCard) ...[
                    _FadeIn(delay: 700, child: _buildRulebookCard(context, ref.watch(rulebookStreamProvider))),
                  ] else ...[
                    _FadeIn(delay: 700, child: const LiveRankingsWidget()),
                  ],
                  SizedBox(height: r.listBottomPadding),
                ],
              ),
            ),
          ),
          Positioned(
            right: r.w(24),
            bottom: r.h(120),
            child: GestureDetector(
              onTap: () => context.push('/registration'),
              child: Container(
                height: r.w(56),
                width: r.w(56),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [LitColors.ember, LitColors.emberDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: LitColors.ember.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: const Color(0xFF1A0D05),
                  size: r.icon(26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final r = context.r;
    return ClayInsetCard(
      width: double.infinity,
      padding: EdgeInsets.all(r.w(20)),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(13)),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Event event, bool isOngoing) {
    final r = context.r;
    return ClayCard(
      margin: EdgeInsets.only(bottom: r.h(12)),
      padding: EdgeInsets.all(r.w(14)),
      borderColor: isOngoing ? LitColors.ember.withValues(alpha: 0.4) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(r.w(10)),
            decoration: BoxDecoration(
              color: isOngoing 
                  ? LitColors.ember.withValues(alpha: 0.15)
                  : LitColors.clay2,
              borderRadius: BorderRadius.circular(r.radius(12)),
            ),
            child: Icon(
              isOngoing ? Icons.play_circle_fill_rounded : Icons.event_available_rounded,
              color: isOngoing ? LitColors.ember : LitColors.ash,
              size: r.icon(20),
            ),
          ),
          SizedBox(width: r.w(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.w600,
                    fontSize: r.sp(14.5),
                    color: LitColors.bone,
                  ),
                ),
                SizedBox(height: r.h(4)),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: r.icon(12), color: LitColors.ash),
                    SizedBox(width: r.w(4)),
                    Expanded(
                      child: Text(
                        event.venue ?? 'Venue TBD',
                        style: GoogleFonts.plusJakartaSans(fontSize: r.sp(11), color: LitColors.ash),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (!isOngoing && event.eventDate != null) ...[
                  SizedBox(height: r.h(4)),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: r.icon(12), color: LitColors.ash),
                      SizedBox(width: r.w(4)),
                      Text(
                        DateFormat('MMM d, yyyy').format(event.eventDate!),
                        style: GoogleFonts.plusJakartaSans(fontSize: r.sp(11), color: LitColors.ash),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios_rounded, size: r.icon(14), color: LitColors.ash),
            onPressed: () => context.push('/events/${event.id}'),
          ),
        ],
      ),
    );
  }

  Widget _buildNonAdminServicesGrid(BuildContext context, RoleConfig roleConfig, WidgetRef ref) {
    final services = roleConfig.getQuickServices();

    final r = context.r;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: r.gridColumns(small: 3, medium: 3, large: 4),
        crossAxisSpacing: r.w(10),
        mainAxisSpacing: r.h(10),
        childAspectRatio: 1.0,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildServiceCard(context, service);
      },
    );
  }

  Widget _buildHeader(BuildContext context, Profile? profile) {
    final r = Responsive(context);
    String initial = 'U';
    if (profile != null && profile.fullName.isNotEmpty) {
      initial = profile.fullName[0].toUpperCase();
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            children: [
              Container(
                width: r.w(40),
                height: r.w(40),
                decoration: const BoxDecoration(
                  color: LitColors.clay3,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: r.sp(14),
                    color: LitColors.amber,
                  ),
                ),
              ),
              SizedBox(width: r.w(10)),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${profile?.fullName.split(" ").first ?? "Member"}',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.satisfy(
                        fontSize: r.sp(18),
                        color: LitColors.bone,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE · MMM d').format(DateTime.now()),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: r.sp(10),
                        color: LitColors.ash,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        StatusChip(label: profile?.role.label ?? 'Crew', isCursive: true, color: LitColors.amber),
      ],
    );
  }

  Widget _buildBentoGrid(BuildContext context, AsyncValue<Map<String, int>> statsAsync, bool showAppeals) {
    final r = context.r;
    return statsAsync.when(
      data: (stats) {
        final regCount = stats['registrations'] ?? 1;
        final attCount = stats['attendance'] ?? 0;
        final attendanceRate = regCount > 0 ? (attCount / regCount * 100).toStringAsFixed(0) : '0';

        return Column(
          children: [
            // Bento Grid Row 1
            Row(
              children: [
                Expanded(
                  child: ClayInsetCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          NumberFormat('#,###').format(regCount),
                          style: GoogleFonts.fredoka(
                            fontSize: r.sp(17),
                            fontWeight: FontWeight.bold,
                            color: LitColors.bone,
                          ),
                        ),
                        Text(
                          'REGISTRATIONS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: r.sp(8.5),
                            color: LitColors.ash,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.04,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: r.w(8)),
                Expanded(
                  child: ClayInsetCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$attendanceRate%',
                          style: GoogleFonts.fredoka(
                            fontSize: r.sp(17),
                            fontWeight: FontWeight.bold,
                            color: LitColors.bone,
                          ),
                        ),
                        Text(
                          'LIVE ATTENDANCE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: r.sp(8.5),
                            color: LitColors.ash,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.04,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (showAppeals) ...[
              SizedBox(height: r.h(8)),
              // Bento Grid Row 2: Open Appeals
              ClayInsetCard(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: r.w(14), vertical: r.h(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Open Appeals',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: r.sp(11.5),
                        color: LitColors.bone,
                      ),
                    ),
                    Text(
                      '3 pending',
                      style: GoogleFonts.fredoka(
                        fontSize: r.sp(14),
                        color: LitColors.coral,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: LitColors.ember)),
      error: (_, __) => const Text('Error loading stats'),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final r = Responsive(context);
    return Text(
      title,
      style: GoogleFonts.fredoka(
        fontSize: r.sp(15),
        fontWeight: FontWeight.w600,
        color: LitColors.bone,
      ),
    );
  }

  Widget _buildServicesGrid(BuildContext context, RoleConfig roleConfig, WidgetRef ref) {
    final services = roleConfig.getQuickServices();

    final r = Responsive(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: r.gridColumns(small: 2, medium: 3, large: 4),
        crossAxisSpacing: r.w(10),
        mainAxisSpacing: r.h(10),
        childAspectRatio: 1.0,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildServiceCard(context, service);
      },
    );
  }

  Widget _buildServiceCard(BuildContext context, Map<String, dynamic> service) {
    final r = Responsive(context);
    return ClayCard(
      padding: EdgeInsets.zero,
      onTap: () {
        final route = service['route'] as String;
        const tabRoutes = [
          '/dashboard', 
          '/events', 
          '/registration', 
          '/admin', 
          '/assignments', 
          '/students', 
          '/results', 
          '/analytics'
        ];
        if (tabRoutes.contains(route)) {
          context.go(route);
        } else {
          context.push(route);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(r.w(8)),
            decoration: const BoxDecoration(
              color: LitColors.clay2,
              shape: BoxShape.circle,
            ),
            child: Icon(service['icon'] as IconData, color: service['color'] as Color, size: r.icon(20)),
          ),
          SizedBox(height: r.h(8)),
          Text(
            service['label'] as String,
            style: GoogleFonts.plusJakartaSans(fontSize: r.sp(10), fontWeight: FontWeight.bold, color: LitColors.bone),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlights(BuildContext context) {
    return ClayCard(
      color: LitColors.clay2,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.stars_rounded, color: LitColors.ember, size: 24),
          const SizedBox(height: 12),
          Text(
            'Pentathlon Registrations Closing Soon!',
            style: GoogleFonts.fredoka(
              color: LitColors.bone,
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Only 12 slots left for the main stage event.',
            style: GoogleFonts.plusJakartaSans(
              color: LitColors.ash,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          ClayButton(
            onPressed: () => context.go('/events'),
            width: 110,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Text('View Event'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminConsoleCard(BuildContext context) {
    final r = context.r;
    return ClayCard(
      borderColor: LitColors.ember.withValues(alpha: 0.4),
      width: double.infinity,
      padding: EdgeInsets.zero,
      onTap: () => context.push('/admin'),
      child: Padding(
        padding: EdgeInsets.all(r.w(14)),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(r.w(10)),
              decoration: BoxDecoration(
                color: LitColors.ember.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.radius(12)),
              ),
              child: Icon(Icons.admin_panel_settings_rounded, color: LitColors.amber, size: r.icon(24)),
            ),
            SizedBox(width: r.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Governance & Operations',
                    style: GoogleFonts.fredoka(
                      color: LitColors.bone,
                      fontSize: r.sp(13.5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: r.h(2)),
                  Text(
                    'Access roster, database, points, and logs.',
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.ash,
                      fontSize: r.sp(10.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: LitColors.ash, size: r.icon(14)),
          ],
        ),
      ),
    );
  }

  // Centralized isJunior check is now handled via RoleConfig



  Widget _buildRulebookCard(BuildContext context, AsyncValue<Rulebook?> rulebookAsync) {
    final r = context.r;
    return rulebookAsync.when(
      data: (rulebook) {
        if (rulebook == null) {
          return ClayCard(
            width: double.infinity,
            padding: EdgeInsets.all(r.w(16)),
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined, color: LitColors.ash, size: r.icon(24)),
                SizedBox(width: r.w(12)),
                Expanded(
                  child: Text(
                    'Rulebook not available.',
                    style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(13), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }

        return ClayCard(
          width: double.infinity,
          padding: EdgeInsets.all(r.w(16)),
          borderColor: LitColors.amber.withValues(alpha: 0.3),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(r.w(10)),
                decoration: BoxDecoration(
                  color: LitColors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.picture_as_pdf_rounded, color: LitColors.amber, size: r.icon(24)),
              ),
              SizedBox(width: r.w(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fest Rulebook',
                      style: GoogleFonts.fredoka(
                        fontWeight: FontWeight.bold,
                        fontSize: r.sp(14.5),
                        color: LitColors.bone,
                      ),
                    ),
                    SizedBox(height: r.h(4)),
                    Text(
                      'Updated: ${DateFormat('MMM dd, yyyy').format(rulebook.uploadedAt)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: r.sp(11),
                        color: LitColors.ash,
                      ),
                    ),
                  ],
                ),
              ),
              ClayButton(
                onPressed: () => context.push('/rulebook/view', extra: rulebook.fileUrl),
                padding: EdgeInsets.symmetric(horizontal: r.w(14), vertical: r.h(8)),
                child: const Text('Open'),
              ),
            ],
          ),
        );
      },
      loading: () => _buildLoadingCard(context),
      error: (e, _) => ClayCard(
        width: double.infinity,
        padding: EdgeInsets.all(r.w(16)),
        child: Text('Error loading rulebook: $e', style: GoogleFonts.plusJakartaSans(color: LitColors.coral, fontSize: r.sp(12))),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    final r = context.r;
    return ClayCard(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: r.h(24)),
      child: Center(
        child: SizedBox(
          height: r.w(20),
          width: r.w(20),
          child: CircularProgressIndicator(strokeWidth: 2, color: LitColors.ember),
        ),
      ),
    );
  }


}

class LiveRankingsWidget extends ConsumerWidget {
  const LiveRankingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingsAsync = ref.watch(departmentRankingsProvider);
    final r = context.r;

    return ClayCard(
      width: double.infinity,
      padding: EdgeInsets.all(r.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Branch Standings',
                style: GoogleFonts.fredoka(
                  fontSize: r.sp(13.5),
                  fontWeight: FontWeight.bold,
                  color: LitColors.bone,
                ),
              ),
              Icon(Icons.emoji_events_rounded, color: LitColors.ember, size: r.icon(18)),
            ],
          ),
          SizedBox(height: r.h(12)),
          rankingsAsync.when(
            data: (rankings) {
              if (rankings.isEmpty) {
                return Text(
                  'No standings available for the current fest.',
                  style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(11)),
                );
              }

              // Use ALL rankings
              final allRankings = rankings;
              final maxPoints = allRankings.isNotEmpty ? allRankings.first.totalPoints : 1;

              return Column(
                children: [
                  // Bar Chart Representation (still limit to top 8 for readability)
                  SizedBox(
                    height: r.h(160),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxPoints * 1.2,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= allRankings.take(8).length) return const SizedBox.shrink();
                                return Padding(
                                  padding: EdgeInsets.only(top: r.h(8.0)),
                                  child: Text(
                                    allRankings[index].branch,
                                    style: TextStyle(color: LitColors.ash, fontSize: r.sp(8), fontWeight: FontWeight.bold),
                                  ),
                                );
                              },
                              reservedSize: r.h(28),
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(allRankings.take(8).length, (index) {
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: allRankings[index].totalPoints.toDouble(),
                                gradient: LinearGradient(
                                  colors: index == 0 
                                      ? [LitColors.ember, LitColors.amber] 
                                      : [LitColors.clay3, LitColors.ash],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: r.w(14),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(r.radius(6))),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                  SizedBox(height: r.h(20)),
                  // Detailed List View - ALL departments
                  ...List.generate(allRankings.length, (index) {
                    final rank = allRankings[index];
                    final isTop3 = index < 3;
                    final progress = rank.totalPoints / (maxPoints > 0 ? maxPoints : 1);
                    
                    return Container(
                      padding: EdgeInsets.symmetric(vertical: r.h(8.0)),
                      decoration: BoxDecoration(
                        border: index == allRankings.length - 1 
                            ? null 
                            : const Border(bottom: BorderSide(color: Color(0xFF262220))),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${index + 1} · ${rank.branch}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: r.sp(12),
                                      color: LitColors.bone,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${rank.totalPoints}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: r.sp(12),
                                  fontWeight: FontWeight.bold,
                                  color: isTop3 ? LitColors.amber : LitColors.bone,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: r.h(6)),
                          ClayProgressBar(progress: progress),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => Center(
              child: SizedBox(
                height: r.w(20),
                width: r.w(20),
                child: CircularProgressIndicator(strokeWidth: 2, color: LitColors.ember),
              ),
            ),
            error: (e, _) => Text('Failed to load standings', style: GoogleFonts.plusJakartaSans(color: LitColors.coral, fontSize: r.sp(11))),
          ),
        ],
      ),
    );
  }
}

class _FadeIn extends StatefulWidget {
  final Widget child;
  final int delay;

  const _FadeIn({required this.child, required this.delay});

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
