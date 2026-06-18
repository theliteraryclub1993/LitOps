import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../auth/providers/auth_provider.dart';

final completedEventsProvider = FutureProvider<List<Event>>((ref) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.events)
      .select()
      .inFilter('status', ['completed', 'results_published', 'ongoing'])
      .order('title');
  return (data as List).map((e) => Event.fromJson(e)).toList();
});

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});
  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _loadingStandings = false;

  Future<void> _showResultsStandingsSheet(Event event) async {
    setState(() => _loadingStandings = true);
    List<Map<String, dynamic>> resultsList = [];
    try {
      final data = await SupabaseConfig.client
          .from(SupabaseTables.results)
          .select('position, score, remarks, registrations(student_master(name, usn, branch)), teams(team_name)')
          .eq('event_id', event.id);

      resultsList = List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      debugPrint('Error loading standings: $e');
    } finally {
      setState(() => _loadingStandings = false);
    }

    if (!mounted) return;

    if (resultsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No results records found for this event.')),
      );
      return;
    }

    // Sort results: winner (0) -> runnerUp (1) -> secondRunnerUp (2)
    resultsList.sort((a, b) {
      final posA = ResultPosition.fromString(a['position']);
      final posB = ResultPosition.fromString(b['position']);
      return posA.index.compareTo(posB.index);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClayCard(
          color: LitColors.clay,
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: GoogleFonts.fredoka(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: LitColors.bone,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${event.category.label} • Results Standing',
                          style: GoogleFonts.plusJakartaSans(
                            color: LitColors.ash,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: LitColors.clay2,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: LitColors.ash, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: resultsList.map((res) {
                      final pos = ResultPosition.fromString(res['position']);
                      final isWinner = pos == ResultPosition.winner;
                      final isRunnerUp = pos == ResultPosition.runnerUp;

                      Color trophyColor = LitColors.ember; // gold/ember for winner
                      if (isRunnerUp) trophyColor = LitColors.amber; // silver/amber
                      if (pos == ResultPosition.secondRunnerUp) trophyColor = LitColors.ash; // bronze/ash

                      final reg = res['registrations'] as Map<String, dynamic>?;
                      final student = reg != null ? reg['student_master'] as Map<String, dynamic>? : null;
                      final team = res['teams'] as Map<String, dynamic>?;
                      final displayName = team != null ? team['team_name'] : (student != null ? student['name'] : 'Unknown');
                      final subtitle = team != null ? 'Team Entry' : (student != null ? '${student['usn']} • ${student['branch']}' : '');

                      return ClayCard(
                        color: LitColors.clay2,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        borderColor: isWinner ? LitColors.ember.withOpacity(0.3) : Colors.transparent,
                        child: Row(
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              color: trophyColor,
                              size: isWinner ? 36 : 28,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pos.label,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: trophyColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isWinner ? 12 : 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    displayName ?? 'Unknown',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: LitColors.bone,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isWinner ? 15 : 13.5,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: LitColors.ash,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  res['score'] != null ? '${res['score']} pts' : '--',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: LitColors.bone,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isWinner ? 14 : 12.5,
                                  ),
                                ),
                                if (res['remarks'] != null && (res['remarks'] as String).isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    res['remarks'],
                                    style: GoogleFonts.plusJakartaSans(
                                      color: LitColors.ash,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ClayButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/certificates');
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('View Certificates'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    final eventsAsync = ref.watch(completedEventsProvider);

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: const LitLifeAppBar(title: 'Results & Standings'),
      body: Stack(
        children: [
          eventsAsync.when(
            data: (events) => events.isEmpty
                ? const EmptyView(icon: Icons.emoji_events_outlined, title: 'No events with results')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (ctx, i) {
                      final e = events[i];
                      final isPublished = e.status == EventStatus.resultsPublished;
                      return ClayCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        onTap: () {
                          if (isPublished) {
                            _showResultsStandingsSheet(e);
                          } else {
                            if (role.canManageResults) {
                              context.push('/results/score/${e.id}');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Results are not published yet for this event.')),
                              );
                            }
                          }
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: LitColors.clay2,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    offset: const Offset(2, 2),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.emoji_events,
                                color: isPublished ? LitColors.amber : LitColors.ash,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.name,
                                    style: GoogleFonts.fredoka(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: LitColors.bone,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${e.category.label} • ${isPublished ? "Results Published" : "Pending Scoring"}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: LitColors.ash,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: LitColors.ash,
                              size: 20,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
          ),
          if (_loadingStandings)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: LitColors.ember)),
            ),
        ],
      ),
    );
  }
}

