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
import '../../../core/utils/responsive.dart';

final completedEventsProvider = StreamProvider<List<Event>>((ref) {
  return SupabaseConfig.client
      .from(SupabaseTables.events)
      .stream(primaryKey: ['id'])
      .order('updated_at', ascending: false)
      .map((data) {
        final events = data.map((e) => Event.fromJson(e)).toList();
        return events.where((e) {
          return [EventStatus.completed, EventStatus.resultsPublished].contains(e.status);
        }).toList();
      });
});

final eventResultsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) {
  return SupabaseConfig.client
      .from(SupabaseTables.results)
      .stream(primaryKey: ['id'])
      .eq('event_id', eventId)
      .map((data) {
        // We need to fetch the related data for each result since stream doesn't support direct joins easily
        // We'll use a Future to fetch the related data for each result
        // So we need to create a stream that first fetches the related data
        // Wait, let's use a separate approach! Let's use a FutureProvider that is invalidated by the stream!
        // Or, let's create a new provider that combines the stream with the future to fetch related data!
        // Okay, let's create a combined provider!
        return List<Map<String, dynamic>>.from(data);
      });
});

final eventResultsWithDetailsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  // Watch the stream to re-trigger fetching when results change

  ref.watch(eventResultsProvider(eventId));
  
  // Fetch the results with related data
  final data = await SupabaseConfig.client
      .from(SupabaseTables.results)
      .select('position, score, remarks, registrations!inner(student_master(id, name, usn, branch)), teams(id, team_name)')
      .eq('event_id', eventId);
  
  return List<Map<String, dynamic>>.from(data as List);
});

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});
  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _AnimatedTrophyIcon extends StatefulWidget {
  final bool isPublished;

  const _AnimatedTrophyIcon({required this.isPublished});

  @override
  State<_AnimatedTrophyIcon> createState() => _AnimatedTrophyIconState();
}

class _AnimatedTrophyIconState extends State<_AnimatedTrophyIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _translateAnimation = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _colorAnimation = ColorTween(begin: LitColors.ash, end: LitColors.amber).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isPublished) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedTrophyIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPublished != oldWidget.isPublished) {
      if (widget.isPublished) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateAnimation.value),
          child: Icon(
            Icons.emoji_events,
            color: _colorAnimation.value,
            size: r.icon(20),
          ),
        );
      },
    );
  }
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _loadingStandings = false;

  void _showResultsStandingsSheet(Event event) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ResultsStandingsSheet(event: event);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    final eventsAsync = ref.watch(completedEventsProvider);
    final r = context.r;

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: const LitLifeAppBar(title: 'Results & Standings', showBack: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: r.pagePadding,
          right: r.pagePadding,
          top: r.h(16),
          bottom: r.listBottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            eventsAsync.when(
              data: (events) => events.isEmpty
                  ? const EmptyView(icon: Icons.emoji_events_outlined, title: 'No events with results')
                  : Column(
                      children: events.asMap().entries.map((entry) {
                        final e = entry.value;
                        final isPublished = e.status == EventStatus.resultsPublished;
                        return ClayCard(
                          margin: EdgeInsets.only(bottom: r.h(12)),
                          padding: EdgeInsets.all(r.w(14)),
                          borderColor: isPublished ? LitColors.moss.withValues(alpha: 0.4) : null,
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
                                width: r.w(44),
                                height: r.w(44),
                                decoration: BoxDecoration(
                                  color: LitColors.clay2,
                                  borderRadius: BorderRadius.circular(r.radius(12)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      offset: Offset(r.w(2), r.w(2)),
                                      blurRadius: r.radius(5),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: _AnimatedTrophyIcon(isPublished: isPublished),
                              ),
                              SizedBox(width: r.w(14)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.name,
                                      style: GoogleFonts.fredoka(
                                        fontWeight: FontWeight.bold,
                                        fontSize: r.sp(14.5),
                                        color: LitColors.bone,
                                      ),
                                    ),
                                    SizedBox(height: r.h(4)),
                                    Text(
                                      '${e.category.label} • ${isPublished ? "Results Published" : "Pending Scoring"}',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: isPublished ? LitColors.moss : LitColors.ash,
                                        fontSize: r.sp(11),
                                        fontWeight: isPublished ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: LitColors.ash,
                                size: r.icon(20),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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
      ),
    );
  }
}

class _ResultsStandingsSheet extends ConsumerWidget {
  final Event event;

  const _ResultsStandingsSheet({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(eventResultsWithDetailsProvider(event.id));
    final r = context.r;

    return ClayCard(
      color: LitColors.clay,
      borderRadius: r.radius(24),
      padding: EdgeInsets.fromLTRB(r.w(20), r.h(24), r.w(20), r.h(24) + r.bottomSafeArea),
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
                        fontSize: r.sp(20),
                        fontWeight: FontWeight.bold,
                        color: LitColors.bone,
                      ),
                    ),
                    SizedBox(height: r.h(2)),
                    Text(
                      '${event.category.label} • Results Standing',
                      style: GoogleFonts.plusJakartaSans(
                        color: LitColors.ash,
                        fontSize: r.sp(12),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(r.w(6)),
                  decoration: const BoxDecoration(
                    color: LitColors.clay2,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: LitColors.ash, size: r.icon(18)),
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(20)),
          Flexible(
            child: resultsAsync.when(
              data: (results) {
                if (results.isEmpty) {
                  return Center(
                    child: Text(
                      'No results found for this event.',
                      style: GoogleFonts.plusJakartaSans(
                        color: LitColors.ash,
                        fontSize: r.sp(12),
                      ),
                    ),
                  );
                }
                final sortedResults = List<Map<String, dynamic>>.from(results)..sort((a, b) {
                  final posA = ResultPosition.fromString(a['position']);
                  final posB = ResultPosition.fromString(b['position']);
                  return posA.index.compareTo(posB.index);
                });
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: sortedResults.map((res) {
                      final pos = ResultPosition.fromString(res['position']);
                      final isWinner = pos == ResultPosition.winner;
                      final isRunnerUp = pos == ResultPosition.runnerUp;

                      Color trophyColor = LitColors.ember;
                      if (isRunnerUp) trophyColor = LitColors.amber;
                      if (pos == ResultPosition.secondRunnerUp) trophyColor = LitColors.ash;

                      final reg = res['registrations'] as Map<String, dynamic>?;
                      final student = reg != null ? reg['student_master'] as Map<String, dynamic>? : null;
                      final team = res['teams'] as Map<String, dynamic>?;
                      final displayName = team != null ? team['team_name'] : (student != null ? student['name'] : 'Unknown');
                      final subtitle = team != null ? 'Team Entry' : (student != null ? '${student['usn']} • ${student['branch']}' : '');

                      return ClayCard(
                        color: LitColors.clay2,
                        margin: EdgeInsets.only(bottom: r.h(12)),
                        padding: EdgeInsets.all(r.w(14)),
                        borderColor: isWinner ? LitColors.ember.withValues(alpha: 0.3) : Colors.transparent,
                        child: Row(
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              color: trophyColor,
                              size: isWinner ? r.icon(36) : r.icon(28),
                            ),
                            SizedBox(width: r.w(14)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pos.label,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: trophyColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isWinner ? r.sp(12) : r.sp(11),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: r.h(2)),
                                  Text(
                                    displayName ?? 'Unknown',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: LitColors.bone,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isWinner ? r.sp(15) : r.sp(13.5),
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    SizedBox(height: r.h(2)),
                                    Text(
                                      subtitle,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: LitColors.ash,
                                        fontSize: r.sp(10.5),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(width: r.w(8)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                  Text(
                                    res['score'] != null ? '${res['score']} pts' : '--',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: LitColors.bone,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isWinner ? r.sp(14) : r.sp(12.5),
                                    ),
                                  ),
                                  if (res['remarks'] != null && (res['remarks'] as String).isNotEmpty) ...[
                                    SizedBox(height: r.h(2)),
                                    Text(
                                      res['remarks'],
                                      style: GoogleFonts.plusJakartaSans(
                                        color: LitColors.ash,
                                        fontSize: r.sp(9),
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
                  );
                },
                error: (e, _) => ErrorView(message: 'Error loading results: $e'),
                loading: () => const LoadingView(),
              ),
            ),
            SizedBox(height: r.h(16)),
            ClayButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/certificates');
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_rounded, size: r.icon(16)),
                  SizedBox(width: r.w(8)),
                  const Text('View Certificates'),
                ],
              ),
            ),
          ],
        ),
      );
  }
}
