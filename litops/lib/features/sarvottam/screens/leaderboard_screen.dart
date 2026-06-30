import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/enums/enums.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../results/screens/results_screen.dart'; // To use ResultsStandingsSheet

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
    'CSE', 'ISE', 'CI', 'CB', 'RI', 'ECE', 'VL', 'EI', 'EE', 'CV', 'ME'
  ];

  // Watch for changes in results and events to rebuild standings in real-time
  final resultsStream = SupabaseConfig.client
      .from(SupabaseTables.results)
      .stream(primaryKey: ['id']);

  final eventsStream = SupabaseConfig.client
      .from(SupabaseTables.events)
      .stream(primaryKey: ['id']);

  final controller = StreamController<void>();
  final sub1 = resultsStream.listen((_) => controller.add(null));
  final sub2 = eventsStream.listen((_) => controller.add(null));

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    controller.close();
  });

  // Seed initial pull
  controller.add(null);

  await for (final _ in controller.stream) {
    try {
      // Fetch published events
      final eventsData = await SupabaseConfig.client
          .from(SupabaseTables.events)
          .select()
          .eq('status', EventStatus.resultsPublished.value);

      if (eventsData.isEmpty) {
        // Return empty standings list initialized to 0 points
        final emptyList = allDepartments.asMap().entries.map((entry) {
          return DepartmentResult(
            department: entry.value,
            totalPoints: 0,
            rank: entry.key + 1,
            eventResults: [],
          );
        }).toList();
        yield emptyList;
        continue;
      }

      final publishedEventIds = eventsData.map((e) => e['id'] as String).toList();

      // Create a map for quick event lookup
      final eventMap = <String, String>{};
      for (final event in eventsData) {
        final id = event['id'] as String?;
        if (id == null) continue;
        final name = event['title'] ?? event['name'] ?? 'Unknown Event';
        eventMap[id] = name;
      }

      // Fetch all results for these published events (including registrations and student_master)
      final resultsData = await SupabaseConfig.client
          .from(SupabaseTables.results)
          .select('event_id, position, registrations!inner(student_master(branch))')
          .inFilter('event_id', publishedEventIds);

      final departmentData = <String, Map<String, dynamic>>{};
      final eventPointsPerBranch = <String, Map<String, Map<String, dynamic>>>{};

      // Initialize ALL departments with 0 points
      for (final dept in allDepartments) {
        departmentData[dept] = {
          'totalPoints': 0,
          'eventResults': <EventResult>[],
        };
        eventPointsPerBranch[dept] = {};
      }

      for (final row in resultsData as List) {
        final reg = row['registrations'] as Map<String, dynamic>?;
        final student = reg != null ? reg['student_master'] as Map<String, dynamic>? : null;
        if (student == null) continue;

        final rawBranch = student['branch'] as String?;
        if (rawBranch == null) continue;

        final branch = AppUtils.mapUsnBranchToOfficial(rawBranch);
        if (!allDepartments.contains(branch)) continue;

        final eventId = row['event_id'] as String;
        final position = row['position'] as String?;
        if (position == null) continue;

        int pointsVal = 0;
        if (position == 'winner') pointsVal = 10;
        else if (position == 'runner_up') pointsVal = 7;
        else if (position == 'second_runner_up') pointsVal = 5;
        else if (position == 'participation') pointsVal = 1;

        // Update total branch points
        departmentData[branch]!['totalPoints'] = (departmentData[branch]!['totalPoints'] as int) + pointsVal;

        // Group by event
        if (!eventPointsPerBranch[branch]!.containsKey(eventId)) {
          eventPointsPerBranch[branch]![eventId] = {
            'eventId': eventId,
            'eventName': eventMap[eventId] ?? 'Unknown Event',
            'position': position,
            'totalEventPoints': 0,
          };
        }
        final eventInfo = eventPointsPerBranch[branch]![eventId]!;
        eventInfo['totalEventPoints'] = (eventInfo['totalEventPoints'] as int) + pointsVal;

        // Keep winner/runner_up preference for display position
        if (position == 'winner' || eventInfo['position'] == 'participation') {
          eventInfo['position'] = position;
        }
      }

      // Build eventResults lists
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

      // Sort departments by total points descending
      final sortedBranches = departmentData.entries.toList()
        ..sort((a, b) => (b.value['totalPoints'] as int).compareTo(a.value['totalPoints'] as int));

      // Convert to DepartmentResult
      final resultList = <DepartmentResult>[];
      int currentRank = 1;
      for (int i = 0; i < sortedBranches.length; i++) {
        final entry = sortedBranches[i];
        final pts = entry.value['totalPoints'] as int;
        if (i > 0 && pts < (sortedBranches[i - 1].value['totalPoints'] as int)) {
          currentRank = i + 1;
        }
        resultList.add(
          DepartmentResult(
            department: entry.key,
            totalPoints: pts,
            rank: currentRank,
            eventResults: entry.value['eventResults'] as List<EventResult>,
          ),
        );
      }

      yield resultList;
    } catch (e, stack) {
      debugPrint('Error computing leaderboard: $e');
      debugPrintStack(stackTrace: stack);
      // Yield empty initialized list on error to prevent crash
      final emptyList = allDepartments.asMap().entries.map((entry) {
        return DepartmentResult(
          department: entry.value,
          totalPoints: 0,
          rank: entry.key + 1,
          eventResults: [],
        );
      }).toList();
      yield emptyList;
    }
  }
});

final publishedEventsProvider = StreamProvider<List<Event>>((ref) {
  return SupabaseConfig.client
      .from(SupabaseTables.events)
      .stream(primaryKey: ['id'])
      .eq('status', EventStatus.resultsPublished.value)
      .order('updated_at', ascending: false)
      .map((data) => data.map((e) => Event.fromJson(e)).toList());
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  String? _getUserBranch(Profile? profile) {
    if (profile == null || profile.usn == null) return null;
    final usn = profile.usn!.toUpperCase();
    if (usn.contains('CS')) return 'CSE';
    if (usn.contains('IS')) return 'ISE';
    if (usn.contains('EC')) return 'ECE';
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

    return DefaultTabController(
      length: isJunior ? 1 : 2,
      child: Scaffold(
        backgroundColor: LitColors.void_,
        appBar: LitLifeAppBar(
          title: isJunior ? 'Club Members' : 'Leaderboard',
          showBack: Navigator.canPop(context),
          bottom: isJunior
              ? null
              : TabBar(
                  indicatorColor: LitColors.ember,
                  labelColor: LitColors.bone,
                  unselectedLabelColor: LitColors.ash,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                  tabs: const [
                    Tab(text: 'Overall Standings'),
                    Tab(text: 'Published Events'),
                  ],
                ),
        ),
        body: isJunior
            ? _buildClubMembersSection(context, ref)
            : TabBarView(
                children: [
                  _buildOverallStandingsTab(context, ref, leaderboardAsync, userBranch),
                  _buildPublishedEventsTab(context, ref),
                ],
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
                          role.label,
                          style: GoogleFonts.dancingScript(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: LitColors.amber,
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

  Widget _buildOverallStandingsTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<DepartmentResult>> leaderboardAsync,
    String? userBranch,
  ) {
    return leaderboardAsync.when(
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

        final itemCount = 3 + departments.length; // header + legend + list + bottom
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(leaderboardProvider),
          color: LitColors.ember,
          backgroundColor: LitColors.clay,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                // Header section
                return const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: Column(
                      children: [
                        SizedBox(height: 12),
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 48,
                          color: LitColors.ember,
                        ),
                        SizedBox(height: 8),
                        _SarvottamTitle(),
                        SizedBox(height: 4),
                        _LiveStandingsText(),
                      ],
                    ),
                  ),
                );
              } else if (index == 1) {
                // Points System Legend Chips
                return const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: _LegendChips(),
                );
              } else if (index == itemCount - 1) {
                // Bottom padding
                return const SizedBox(height: 130);
              } else {
                // Department card
                final deptIndex = index - 2;
                final dept = departments[deptIndex];
                final isUserBranch = userBranch != null && dept.department.toUpperCase() == userBranch.toUpperCase();
                final ratio = dept.totalPoints / maxPointsVal;
                return RepaintBoundary(
                  child: _DepartmentCard(
                    dept: dept,
                    isUserBranch: isUserBranch,
                    ratio: ratio,
                    userBranch: userBranch,
                  ),
                );
              }
            },
          ),
        );
      },
      loading: () => const LoadingView(),
      error: (err, _) => ErrorView(
        message: 'Error loading leaderboard: $err',
        onRetry: () => ref.invalidate(leaderboardProvider),
      ),
    );
  }

  Widget _buildPublishedEventsTab(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(publishedEventsProvider);
    final r = Responsive(context);

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const EmptyView(
            icon: Icons.emoji_events_outlined,
            title: 'No published results',
            subtitle: 'Published event results will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(publishedEventsProvider),
          color: LitColors.ember,
          backgroundColor: LitColors.clay,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: events.length + 1,
            itemBuilder: (context, index) {
              if (index == events.length) {
                return const SizedBox(height: 130);
              }

              final event = events[index];
              return ClayCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: LitColors.clay2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: LitColors.amber,
                        size: 22,
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
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: LitColors.bone,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${event.category.label} • Published ${AppUtils.formatDate(event.updatedAt)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: LitColors.ash,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClayButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      borderRadius: 8,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          useRootNavigator: true,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => ResultsStandingsSheet(event: event),
                        );
                      },
                      child: Text(
                        'Rankings',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: LitColors.bone,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString()),
    );
  }

  Widget _buildMottoCard() {
    return ClayCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      borderColor: LitColors.ember.withValues(alpha: 0.2),
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
              color: LitColors.bone.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _SarvottamTitle extends StatelessWidget {
  const _SarvottamTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Sarvottam Trophy',
      style: GoogleFonts.fredoka(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: LitColors.bone,
      ),
    );
  }
}

class _LiveStandingsText extends StatelessWidget {
  const _LiveStandingsText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Live branch standings',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: LitColors.ash,
      ),
    );
  }
}

class _LegendChips extends StatelessWidget {
  const _LegendChips();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: const [
        _LegendChip(text: 'Winner 10'),
        _LegendChip(text: 'Runner-Up 7'),
        _LegendChip(text: '2nd RU 5'),
        _LegendChip(text: 'Participation 1'),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String text;

  const _LegendChip({required this.text});

  @override
  Widget build(BuildContext context) {
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

class _DepartmentCard extends StatelessWidget {
  final DepartmentResult dept;
  final bool isUserBranch;
  final double ratio;
  final String? userBranch;

  const _DepartmentCard({
    required this.dept,
    required this.isUserBranch,
    required this.ratio,
    this.userBranch,
  });

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderColor: isUserBranch ? LitColors.ember : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DepartmentHeader(
            rank: dept.rank,
            department: dept.department,
            totalPoints: dept.totalPoints,
          ),
          const SizedBox(height: 10),
          ClayProgressBar(progress: ratio),
          if (isUserBranch) ...[
            const SizedBox(height: 8),
            const _YourBranchText(),
          ],
          const SizedBox(height: 16),
          _EventResultsTable(
            eventResults: dept.eventResults,
          ),
        ],
      ),
    );
  }
}

class _DepartmentHeader extends StatelessWidget {
  final int rank;
  final String department;
  final int totalPoints;

  const _DepartmentHeader({
    required this.rank,
    required this.department,
    required this.totalPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$rank · $department',
          style: GoogleFonts.plusJakartaSans(
            color: LitColors.bone,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '$totalPoints pts',
          style: GoogleFonts.jetBrainsMono(
            color: LitColors.bone,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _YourBranchText extends StatelessWidget {
  const _YourBranchText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Your branch',
      style: GoogleFonts.plusJakartaSans(
        color: LitColors.ember,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _EventResultsTable extends StatelessWidget {
  final List<EventResult> eventResults;

  const _EventResultsTable({required this.eventResults});

  @override
  Widget build(BuildContext context) {
    return ClayInsetCard(
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
          TableRow(
            decoration: BoxDecoration(
              color: LitColors.clay.withValues(alpha: 0.5),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: _TableHeaderText(text: 'Event'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: _TableHeaderText(text: 'Position'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: _TableHeaderText(text: 'Points'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: _TableHeaderText(text: 'Actions'),
              ),
            ],
          ),
          for (final result in eventResults)
            TableRow(
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
                    _getPositionText(result.position),
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
                  child: _ViewEventButton(eventId: result.eventId),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _getPositionText(String? position) {
    if (position == 'winner') {
      return 'Winner';
    } else if (position == 'runner_up') {
      return 'Runner-Up';
    } else if (position == 'second_runner_up') {
      return '2nd RU';
    } else {
      return 'Participation';
    }
  }
}

class _TableHeaderText extends StatelessWidget {
  final String text;

  const _TableHeaderText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.fredoka(
        color: LitColors.bone,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _ViewEventButton extends StatelessWidget {
  final String eventId;

  const _ViewEventButton({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/events/$eventId'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: LitColors.ember,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'View',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}


