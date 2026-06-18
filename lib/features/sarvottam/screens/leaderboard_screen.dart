import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';

final leaderboardProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.sarvottamPoints)
      .select();

  final branchPoints = <String, int>{};
  for (final row in (data as List)) {
    final branch = row['branch'].toString().toUpperCase();
    final points = int.tryParse(row['points'].toString()) ?? 0;
    branchPoints[branch] = (branchPoints[branch] ?? 0) + points;
  }

  final sortedList = branchPoints.entries.map((entry) {
    return {
      'name': entry.key,
      'points': entry.value,
    };
  }).toList();
  sortedList.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

  for (int i = 0; i < sortedList.length; i++) {
    sortedList[i]['rank'] = i + 1;
  }

  return sortedList;
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
        data: (branches) {
          if (branches.isEmpty) {
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

          final maxPoints = branches.first['points'] as int;
          final maxPointsVal = maxPoints > 0 ? maxPoints : 1;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(leaderboardProvider),
            color: LitColors.ember,
            backgroundColor: LitColors.clay,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // Header section matching HTML spec
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

                // List of branch cards
                ...branches.map((branch) {
                  final name = branch['name'] as String;
                  final points = branch['points'] as int;
                  final rank = branch['rank'] as int;
                  final ratio = points / maxPointsVal;
                  final isUserBranch = userBranch != null && name.toUpperCase() == userBranch.toUpperCase();

                  return ClayCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    borderColor: isUserBranch ? LitColors.ember : Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$rank · $name',
                              style: GoogleFonts.plusJakartaSans(
                                color: LitColors.bone,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$points pts',
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

