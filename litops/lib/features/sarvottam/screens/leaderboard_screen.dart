import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/enums/enums.dart';
import '../../dashboard/screens/dashboard_screen.dart';
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
    'CS', 'IS', 'CI', 'CB', 'RI', 'EC', 'VL', 'EI', 'EE', 'CV', 'ME'
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
    if (usn.contains('CS')) return 'CS';
    if (usn.contains('IS')) return 'IS';
    if (usn.contains('EC')) return 'EC';
    if (usn.contains('EE')) return 'EE';
    if (usn.contains('ME')) return 'ME';
    if (usn.contains('CV') || usn.contains('CE')) return 'CV';
    if (usn.contains('CI')) return 'CI';
    if (usn.contains('CB')) return 'CB';
    if (usn.contains('RI')) return 'RI';
    if (usn.contains('VL')) return 'VL';
    if (usn.contains('EI')) return 'EI';
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final profile = ref.watch(currentProfileProvider);
    final userBranch = _getUserBranch(profile);
    final isJunior = _isJuniorWingOrLowerYear(profile);

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: LitLifeAppBar(
        title: isJunior ? 'Club Members' : 'Leaderboard',
        showBack: Navigator.canPop(context),
      ),
      body: isJunior
          ? _buildClubMembersSection(context, ref)
          : leaderboardAsync.when(

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
                const SizedBox(height: 130),
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

  bool _isJuniorWingOrLowerYear(Profile? profile) {
    if (profile == null) return false;
    if (profile.role == UserRole.superAdmin) return false;
    if (profile.year == 4 || profile.academicYear == 4) return false;
    return profile.role == UserRole.juniorWing ||
        profile.year == 1 ||
        profile.year == 2 ||
        profile.academicYear == 1 ||
        profile.academicYear == 2;
  }

  Widget _buildClubMembersSection(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(activeProfilesStreamProvider);

    return profilesAsync.when(
      data: (profiles) {
        if (profiles.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              const SizedBox(height: 12),
              _buildMottoCard(),
              const SizedBox(height: 16),
              const ClayInsetCard(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No active club members found.',
                    style: TextStyle(color: LitColors.ash, fontSize: 13),
                  ),
                ),
              ),
            ],
          );
        }

        final Map<UserRole, List<Profile>> grouped = {};
        for (var p in profiles) {
          grouped.putIfAbsent(p.role, () => []).add(p);
        }

        // Sort members of each role by their academic year descending
        for (final role in grouped.keys) {
          grouped[role]!.sort((a, b) {
            final yearA = a.academicYear ?? 0;
            final yearB = b.academicYear ?? 0;
            if (yearA != yearB) {
              return yearB.compareTo(yearA); // Higher year first
            }
            return a.fullName.compareTo(b.fullName);
          });
        }

        final orderedRoles = UserRole.values.where((r) => grouped.containsKey(r)).toList();
        
        // Sort roles so they are ordered/aligned according to years
        orderedRoles.sort((a, b) {
          final membersA = grouped[a]!;
          final maxYearA = membersA.map((m) => m.academicYear ?? 0).fold<int>(0, (max, y) => y > max ? y : max);

          final membersB = grouped[b]!;
          final maxYearB = membersB.map((m) => m.academicYear ?? 0).fold<int>(0, (max, y) => y > max ? y : max);

          if (maxYearA != maxYearB) {
            return maxYearB.compareTo(maxYearA); // Higher year first
          }
          return a.hierarchyLevel.compareTo(b.hierarchyLevel);
        });

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeProfilesStreamProvider),
          color: LitColors.ember,
          backgroundColor: LitColors.clay,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              const SizedBox(height: 12),
              _buildMottoCard(),
              const SizedBox(height: 16),
              ...orderedRoles.map((role) {
                final roleMembers = grouped[role]!;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          role.label.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: LitColors.amber,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ...roleMembers.map((member) {
                        return ClayCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              UserAvatar(
                                name: member.fullName,
                                imageUrl: member.photoUrl ?? member.profileImage,
                                radius: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  member.fullName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: LitColors.bone,
                                  ),
                                ),
                              ),
                              if (member.academicYear != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: LitColors.clay2,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Year ${member.academicYear}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: LitColors.ash,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 130),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: LitColors.ember),
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Failed to load members: $e',
            style: GoogleFonts.plusJakartaSans(color: LitColors.coral),
          ),
        ),
      ),
    );
  }

  Widget _buildMottoCard() {
    return ClayCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      borderColor: LitColors.ember.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote_rounded, color: LitColors.ember, size: 20),
              const SizedBox(width: 8),
              Text(
                'Motto',
                style: GoogleFonts.fredoka(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: LitColors.ember,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"To foster the talents and assorted interests of blooming Engineers with creative skills and a penchant for literature."',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: LitColors.bone.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}


