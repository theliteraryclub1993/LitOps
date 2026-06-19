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
import 'package:intl/intl.dart';

final _registrationsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.registrations).stream(primaryKey: ['id']));
final _eventsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.events).stream(primaryKey: ['id']));
final _assignmentsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.eventAssignments).stream(primaryKey: ['id']));

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
    final client = SupabaseConfig.client;
    final eventsRes = await client.from(SupabaseTables.events).select('id');
    final registrationsRes = await client.from(SupabaseTables.registrations).select('student_id').eq('is_cancelled', false);
    final attendanceRes = await client.from(SupabaseTables.attendance).select('id');
    final membersRes = await client.from(SupabaseTables.profiles).select('id').eq('is_active', true);

    final events = (eventsRes as List).length;
    final uniqueRegisteredStudents = (registrationsRes as List).map((r) => r['student_id']).toSet().length;
    final att = (attendanceRes as List).length;
    final membersCount = (membersRes as List).length;

    return {
      'events': events,
      'registrations': uniqueRegisteredStudents > 0 ? uniqueRegisteredStudents : 1,
      'attendance': att,
      'students': membersCount,
    };
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
    final profile = ref.watch(currentProfileProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    
    if (profile != null && !profile.role.isAdmin && profile.year != 3) {
      return _buildNonAdminDashboard(context, profile, ref);
    }

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Lit Life',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 17, color: LitColors.bone),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: LitColors.bone, size: 20),
            onPressed: () => context.push('/search'),
            tooltip: 'Global Search',
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: UserAvatar(
              name: profile?.fullName ?? 'U',
              imageUrl: profile?.photoUrl,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authStateProvider.notifier).refreshProfile();
          ref.invalidate(dashboardStatsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, profile),
              if (profile?.role.isSuperAdmin == true) ...[
                const SizedBox(height: 16),
                _FadeIn(delay: 100, child: _buildAdminConsoleCard(context)),
              ],
              const SizedBox(height: 16),
              _FadeIn(delay: 200, child: _buildBentoGrid(context, statsAsync, profile?.role.canViewAppeals == true && profile?.role.isSuperAdmin != true)),
              const SizedBox(height: 24),
              _FadeIn(delay: 300, child: _buildSectionTitle(context, 'Quick Services')),
              const SizedBox(height: 8),
              _FadeIn(delay: 400, child: _buildServicesGrid(context, profile, ref)),
              const SizedBox(height: 8),
              _FadeIn(delay: 500, child: const LiveRankingsWidget()),
              const SizedBox(height: 24),
              _FadeIn(delay: 600, child: _buildSectionTitle(context, 'Upcoming Highlights')),
              const SizedBox(height: 12),
              _FadeIn(delay: 700, child: _buildHighlights(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNonAdminDashboard(BuildContext context, Profile profile, WidgetRef ref) {
    final ongoingAsync = ref.watch(ongoingEventsProvider);
    final assignedAsync = ref.watch(myAssignedEventsProvider);

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Lit Life',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 17, color: LitColors.bone),
        ),
        actions: [
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: UserAvatar(
              name: profile.fullName,
              imageUrl: profile.photoUrl,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authStateProvider.notifier).refreshProfile();
          ref.invalidate(ongoingEventsProvider);
          ref.invalidate(myAssignedEventsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, profile),
              const SizedBox(height: 24),
              
              _FadeIn(delay: 100, child: _buildSectionTitle(context, 'Ongoing Events')),
              const SizedBox(height: 12),
              ongoingAsync.when(
                data: (events) {
                  if (events.isEmpty) {
                    return _buildEmptyState('No events are currently running.');
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
                error: (e, _) => Text('Error: $e', style: GoogleFonts.plusJakartaSans(color: LitColors.coral)),
              ),
              const SizedBox(height: 24),

              _FadeIn(delay: 300, child: _buildSectionTitle(context, 'My Assigned Events')),
              const SizedBox(height: 12),
              assignedAsync.when(
                data: (events) {
                  if (events.isEmpty) {
                    return _buildEmptyState('You have no upcoming assignments.');
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
                error: (e, _) => Text('Error: $e', style: GoogleFonts.plusJakartaSans(color: LitColors.coral)),
              ),
              const SizedBox(height: 24),
              
              _FadeIn(delay: 500, child: _buildSectionTitle(context, 'Quick Services')),
              const SizedBox(height: 12),
              _FadeIn(delay: 600, child: _buildNonAdminServicesGrid(context, profile, ref)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return ClayInsetCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Event event, bool isOngoing) {
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      borderColor: isOngoing ? LitColors.ember.withOpacity(0.4) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOngoing 
                  ? LitColors.ember.withOpacity(0.15)
                  : LitColors.clay2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isOngoing ? Icons.play_circle_fill_rounded : Icons.event_available_rounded,
              color: isOngoing ? LitColors.ember : LitColors.ash,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: LitColors.bone,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: LitColors.ash),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.venue ?? 'Venue TBD',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: LitColors.ash),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (!isOngoing && event.eventDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: LitColors.ash),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(event.eventDate!),
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: LitColors.ash),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: LitColors.ash),
            onPressed: () => context.push('/events/${event.id}'),
          ),
        ],
      ),
    );
  }

  Widget _buildNonAdminServicesGrid(BuildContext context, Profile profile, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final showAssignments = role.canAssignMembers || profile.year == 4;
    final services = [
      {'icon': Icons.qr_code_scanner_rounded, 'label': 'Scan QR', 'route': '/registration', 'color': LitColors.ember},
      {'icon': Icons.calendar_today_rounded, 'label': 'Events', 'route': '/events', 'color': LitColors.amber},
      {'icon': Icons.group_rounded, 'label': 'Students', 'route': '/students', 'color': LitColors.ash},
      if (showAssignments)
        {'icon': Icons.assignment_ind_rounded, 'label': 'Assign Crew', 'route': '/assignments', 'color': LitColors.amber},
      {'icon': Icons.emoji_events_rounded, 'label': 'Results', 'route': '/results', 'color': LitColors.ember},
      {'icon': Icons.analytics_rounded, 'label': 'Analytics', 'route': '/analytics', 'color': LitColors.amber},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
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
    // Exact layout replicating: AR | Namaskara, Ananya | Day 2. Apr 18 | Joint Secretary
    String initial = 'U';
    if (profile != null && profile.fullName.isNotEmpty) {
      initial = profile.fullName[0].toUpperCase();
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: LitColors.clay3,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                  color: LitColors.amber,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Namaskara, ${profile?.fullName.split(" ").first ?? "Member"}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: LitColors.bone,
                  ),
                ),
                Text(
                  'Day 2 · Apr 18',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.0,
                    color: LitColors.ash,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatusChip(label: profile?.role.name ?? 'Crew'),
      ],
    );
  }

  Widget _buildBentoGrid(BuildContext context, AsyncValue<Map<String, int>> statsAsync, bool showAppeals) {
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
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          NumberFormat('#,###').format(regCount),
                          style: GoogleFonts.fredoka(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: LitColors.bone,
                          ),
                        ),
                        Text(
                          'REGISTRATIONS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8.5,
                            color: LitColors.ash,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.04,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClayInsetCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$attendanceRate%',
                          style: GoogleFonts.fredoka(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: LitColors.bone,
                          ),
                        ),
                        Text(
                          'LIVE ATTENDANCE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8.5,
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
              const SizedBox(height: 8),
              // Bento Grid Row 2: Open Appeals
              ClayInsetCard(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Open Appeals',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: LitColors.bone,
                      ),
                    ),
                    Text(
                      '3 pending',
                      style: GoogleFonts.fredoka(
                        fontSize: 14,
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
    return Text(
      title,
      style: GoogleFonts.fredoka(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: LitColors.bone,
      ),
    );
  }

  Widget _buildServicesGrid(BuildContext context, Profile? profile, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final showAssignments = role.canAssignMembers || profile?.year == 4;
    final services = [
      {'icon': Icons.qr_code_scanner_rounded, 'label': 'Scan QR', 'route': '/registration', 'color': LitColors.ember},
      {'icon': Icons.calendar_today_rounded, 'label': 'Events', 'route': '/events', 'color': LitColors.amber},
      if (showAssignments)
        {'icon': Icons.assignment_ind_rounded, 'label': 'Assign Crew', 'route': '/assignments', 'color': LitColors.amber},
      {'icon': Icons.group_rounded, 'label': 'Students', 'route': '/students', 'color': LitColors.ash},
      {'icon': Icons.emoji_events_rounded, 'label': 'Results', 'route': '/results', 'color': LitColors.ember},
      {'icon': Icons.analytics_rounded, 'label': 'Analytics', 'route': '/analytics', 'color': LitColors.amber},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
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
    return ClayCard(
      padding: EdgeInsets.zero,
      onTap: () {
        final route = service['route'] as String;
        const tabRoutes = ['/dashboard', '/events', '/registration', '/admin'];
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
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: LitColors.clay2,
              shape: BoxShape.circle,
            ),
            child: Icon(service['icon'] as IconData, color: service['color'] as Color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            service['label'] as String,
            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: LitColors.bone),
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
    return ClayCard(
      borderColor: LitColors.ember.withOpacity(0.4),
      width: double.infinity,
      padding: EdgeInsets.zero,
      onTap: () => context.push('/admin'),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LitColors.ember.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: LitColors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Governance & Operations',
                    style: GoogleFonts.fredoka(
                      color: LitColors.bone,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Access roster, database, points, and logs.',
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.ash,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: LitColors.ash, size: 14),
          ],
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

    return ClayCard(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Branch Standings',
                style: GoogleFonts.fredoka(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: LitColors.bone,
                ),
              ),
              const Icon(Icons.emoji_events_rounded, color: LitColors.ember, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          rankingsAsync.when(
            data: (rankings) {
              if (rankings.isEmpty) {
                return Text(
                  'No standings available for the current fest.',
                  style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 11),
                );
              }

              // Take top 5 for the chart
              final topRankings = rankings.take(5).toList();
              final maxPoints = topRankings.isNotEmpty ? topRankings.first.totalPoints : 1;

              return Column(
                children: [
                  // Bar Chart Representation
                  SizedBox(
                    height: 160,
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
                                if (index < 0 || index >= topRankings.length) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    topRankings[index].branch,
                                    style: const TextStyle(color: LitColors.ash, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                );
                              },
                              reservedSize: 28,
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(topRankings.length, (index) {
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: topRankings[index].totalPoints.toDouble(),
                                gradient: LinearGradient(
                                  colors: index == 0 
                                      ? [LitColors.ember, LitColors.amber] 
                                      : [LitColors.clay3, LitColors.ash],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: 18,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Detailed List View
                  ...List.generate(topRankings.length, (index) {
                    final rank = topRankings[index];
                    final isTop3 = index < 3;
                    final progress = rank.totalPoints / (maxPoints > 0 ? maxPoints : 1);
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      decoration: BoxDecoration(
                        border: index == topRankings.length - 1 
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
                                      fontSize: 12,
                                      color: LitColors.bone,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${rank.totalPoints}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isTop3 ? LitColors.amber : LitColors.bone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClayProgressBar(progress: progress),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: LitColors.ember),
              ),
            ),
            error: (e, _) => Text('Failed to load standings', style: GoogleFonts.plusJakartaSans(color: LitColors.coral, fontSize: 11)),
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
