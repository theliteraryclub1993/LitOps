import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';

class DepartmentResult {
  final String department;
  final int totalPoints;
  final int rank;
  final List<EventResult> eventResults;

  DepartmentResult({
    required this.department,
    required this.totalPoints,
    required this.rank,
    required this.eventResults,
  });
}

class EventResult {
  final String eventId;
  final String eventName;
  final String? position;
  final int points;

  EventResult({
    required this.eventId,
    required this.eventName,
    this.position,
    required this.points,
  });
}

final leaderboardProvider = StreamProvider<List<DepartmentResult>>((ref) async* {
  // List of ALL participating departments
  final allDepartments = [
    'CSE', 'ISE', 'ECE', 'EEE', 'ME', 'CE', 'IPE', 'IEM', 'CH', 'MCA'
  ];

  // Watch for changes in event points
  final pointsStream = SupabaseConfig.client
      .from(SupabaseTables.eventPoints)
      .stream(primaryKey: ['id']);

  await for (final _ in pointsStream) {
    // Fetch event points and all events separately to ensure we get event names
    final pointsData = await SupabaseConfig.client
        .from(SupabaseTables.eventPoints)
        .select();
        
    // Fetch all columns from events table to avoid column not found errors
    final eventsData = await SupabaseConfig.client
        .from(SupabaseTables.events)
        .select();
        
    // Create a map for quick event lookup
    final eventMap = <String, String>{};
    for (final event in eventsData) {
      final id = event['id'] as String?;
      if (id == null) continue;
      
      // Try both possible column names for event name
      final name = event['name'] as String?;
      final title = event['title'] as String?;
      final eventName = name ?? title ?? 'Unknown Event';
      
      eventMap[id] = eventName;
    }

    // Group points by department and event
    final departmentData = <String, Map<String, dynamic>>{};
    final eventPointsPerBranch = <String, Map<String, Map<String, dynamic>>>{};
    
    // Initialize ALL departments with 0 points
    for (final dept in allDepartments) {
      departmentData[dept] = {
        'totalPoints': 0,
        'eventResults': <EventResult>[],
      };
      eventPointsPerBranch[dept] = {}; // To track points per event for each branch
    }

    // Add points from event points table
    for (final row in pointsData) {
      final branch = (row['branch'] as String?)?.toUpperCase();
      if (branch == null || !allDepartments.contains(branch)) continue;
      
      final eventId = (row['event_id'] as String?) ?? 'unknown';
      final pointsVal = int.tryParse((row['points'] ?? 0).toString()) ?? 0;
      final position = row['position'] as String?;
      
      // Get event name from our map
      String eventName = eventMap[eventId] ?? 'Unknown Event';

      // Update total branch total points
      departmentData[branch]!['totalPoints'] = (departmentData[branch]!['totalPoints'] as int) + pointsVal;
      
      // Group points by event for this branch
      if (!eventPointsPerBranch[branch]!.containsKey(eventId)) {
        // First time seeing this event for the branch
        eventPointsPerBranch[branch]![eventId] = {
          'eventId': eventId,
          'eventName': eventName,
          'position': position,
          'totalEventPoints': 0,
        };
      }
      
      // Add these points to this event's total (using non-null assertion)
      final eventInfo = eventPointsPerBranch[branch]![eventId]!;
      eventInfo['totalEventPoints'] = (eventInfo['totalEventPoints'] as int) + pointsVal;
      
      // Update position if we don't have one yet
      if (eventInfo['position'] == null && position != null) {
        eventInfo['position'] = position;
      }
    }
    
    // Now build eventResults from the grouped data
    for (final branch in eventPointsPerBranch.keys) {
      for (final eventId in eventPointsPerBranch[branch]!.keys) {
        final eventInfo = eventPointsPerBranch[branch]![eventId]!;
        departmentData[branch]!['eventResults'].add(
          EventResult(
            eventId: eventId,
            eventName: eventInfo['eventName'] as String,
            position: eventInfo['position'] as String?,
            points: eventInfo['totalEventPoints'] as int,
          ),
        );
      }
    }

    // Sort departments by total points
    final sortedBranches = departmentData.entries.toList()
      ..sort((a, b) => (b.value['totalPoints'] as int).compareTo(a.value['totalPoints'] as int));

    // Convert to DepartmentResult objects
    final resultList = <DepartmentResult>[];
    for (int i = 0; i < sortedBranches.length; i++) {
      final entry = sortedBranches[i];
      resultList.add(
        DepartmentResult(
          department: entry.key,
          totalPoints: entry.value['totalPoints'] as int,
          rank: i + 1,
          eventResults: entry.value['eventResults'] as List<EventResult>,
        ),
      );
    }

    yield resultList;
  }
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  String? _getUserBranch(Profile? profile) {
    if (profile == null || profile.usn == null) return null;
    final usn = profile.usn!.toUpperCase();
    if (usn.contains('CS')) return 'CSE';
    if (usn.contains('IS')) return 'ISE';
    if (usn.contains('EC')) return 'ECE';
    if (usn.contains('EE')) return 'EEE';
    if (usn.contains('ME')) return 'ME';
    if (usn.contains('CV') || usn.contains('CE')) return 'CE';
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final profile = ref.watch(currentProfileProvider);
    final userBranch = _getUserBranch(profile);

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: LitLifeAppBar(
        title: 'Leaderboard',
        showBack: Navigator.canPop(context),
      ),
      body: leaderboardAsync.when(
        data: (departments) {
          if (departments.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(leaderboardProvider),
              color: LitColors.ember,
              backgroundColor: LitColors.clay,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  const EmptyView(
                    icon: Icons.emoji_events_rounded,
                    title: 'Leaderboard is empty',
                    subtitle: 'Points will appear here once event results are published.',
                  ),
                ],
              ),
            );
          }

          final maxPoints = departments.first.totalPoints;
          final maxPointsVal = maxPoints > 0 ? maxPoints : 1;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(leaderboardProvider),
            color: LitColors.ember,
            backgroundColor: LitColors.clay,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // Header section
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 48,
                        color: LitColors.ember,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sarvottam Trophy',
                        style: GoogleFonts.fredoka(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: LitColors.bone,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live branch standings',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: LitColors.ash,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Points System Legend Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildLegendChip('Winner 10'),
                    _buildLegendChip('Runner-Up 7'),
                    _buildLegendChip('2nd RU 5'),
                    _buildLegendChip('Participation 1'),
                  ],
                ),
                const SizedBox(height: 24),

                // List of department cards with detailed tables
                ...departments.map((dept) {
                  final isUserBranch = userBranch != null && dept.department.toUpperCase() == userBranch.toUpperCase();
                  final ratio = dept.totalPoints / maxPointsVal;

                  return ClayCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    borderColor: isUserBranch ? LitColors.ember : Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Department header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${dept.rank} · ${dept.department}',
                              style: GoogleFonts.plusJakartaSans(
                                color: LitColors.bone,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${dept.totalPoints} pts',
                              style: GoogleFonts.jetBrainsMono(
                                color: LitColors.bone,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClayProgressBar(progress: ratio),
                        if (isUserBranch) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Your branch',
                            style: GoogleFonts.plusJakartaSans(
                              color: LitColors.ember,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        
                        // Detailed results table
                        ClayInsetCard(
                          borderRadius: 12,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(1),
                              3: FlexColumnWidth(1),
                            },
                            border: TableBorder.symmetric(
                              inside: BorderSide(color: LitColors.ash.withValues(alpha: 0.2), width: 1),
                            ),
                            children: [
                              // Header row
                              TableRow(
                                decoration: BoxDecoration(
                                  color: LitColors.clay.withValues(alpha: 0.5),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    child: Text(
                                      'Event',
                                      style: GoogleFonts.fredoka(
                                        color: LitColors.bone,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    child: Text(
                                      'Position',
                                      style: GoogleFonts.fredoka(
                                        color: LitColors.bone,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    child: Text(
                                      'Points',
                                      style: GoogleFonts.fredoka(
                                        color: LitColors.bone,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    child: Text(
                                      'Actions',
                                      style: GoogleFonts.fredoka(
                                        color: LitColors.bone,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              // Event result rows
                              ...dept.eventResults.map((result) {
                                String positionText = '';
                                if (result.position == 'winner') {
                                  positionText = 'Winner';
                                } else if (result.position == 'runner_up') {
                                  positionText = 'Runner-Up';
                                } else if (result.position == 'second_runner_up') {
                                  positionText = '2nd RU';
                                } else {
                                  positionText = 'Participation';
                                }

                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      child: Text(
                                        result.eventName,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: LitColors.bone,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      child: Text(
                                        positionText,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: LitColors.ash,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      child: Text(
                                        '${result.points}',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: LitColors.moss,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      child: GestureDetector(
                                        onTap: () {
                                          // Navigate to event details page
                                          context.push('/events/${result.eventId}');
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: LitColors.ember,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'View',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
          message: 'Error loading leaderboard: $err',
          onRetry: () => ref.invalidate(leaderboardProvider),
        ),
      ),
    );
  }

  Widget _buildLegendChip(String text) {
    return ClayInsetCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: LitColors.ash,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

