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
import '../../../core/utils/app_utils.dart';

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
  final bool _loadingStandings = false;

  void _showResultsStandingsSheet(Event event) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ResultsStandingsSheet(event: event);
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
                            _showResultsStandingsSheet(e);
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

class ResultsStandingsSheet extends ConsumerWidget {
  final Event event;

  const ResultsStandingsSheet({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final resultsAsync = ref.watch(eventResultsWithDetailsProvider(event.id));
    final r = context.r;
    final isPublished = event.status == EventStatus.resultsPublished;

    // To get the user's branch for highlighting
    final profile = ref.watch(currentProfileProvider);
    final userBranch = _getUserBranch(profile);

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
          SizedBox(height: r.h(12)),
          // Show Last Updated Timestamp
          Text(
            'Last updated: ${AppUtils.formatDateTime(event.updatedAt)}',
            style: GoogleFonts.plusJakartaSans(
              color: LitColors.ash,
              fontSize: r.sp(10.5),
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: r.h(20)),
          Flexible(
            child: !isPublished
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: r.h(30)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_empty_rounded,
                            color: LitColors.ash,
                            size: r.icon(48),
                          ),
                          SizedBox(height: r.h(16)),
                          Text(
                            'Results have not been published yet.',
                            style: GoogleFonts.plusJakartaSans(
                              color: LitColors.bone,
                              fontSize: r.sp(14),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: r.h(6)),
                          Text(
                            'The event rankings will appear here once official points are submitted.',
                            style: GoogleFonts.plusJakartaSans(
                              color: LitColors.ash,
                              fontSize: r.sp(11.5),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : resultsAsync.when(
                    data: (results) {
                      final standings = AppUtils.calculateEventStandings(results);
                      
                      return SingleChildScrollView(
                        child: ClayInsetCard(
                          borderRadius: r.radius(12),
                          padding: EdgeInsets.symmetric(vertical: r.h(12), horizontal: r.w(8)),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(1.2), // Rank / Medal
                              1: FlexColumnWidth(3),   // Department Name
                              2: FlexColumnWidth(1.2), // Branch code
                              3: FlexColumnWidth(1.2), // Points
                            },
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            border: TableBorder.symmetric(
                              inside: BorderSide(color: LitColors.ash.withValues(alpha: 0.1), width: 1),
                            ),
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: LitColors.clay.withValues(alpha: 0.3),
                                ),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: r.h(8)),
                                    child: _tableHeader('Rank', r),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: r.h(8)),
                                    child: _tableHeader('Department', r),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: r.h(8)),
                                    child: _tableHeader('Code', r),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: r.h(8)),
                                    child: _tableHeader('Total', r),
                                  ),
                                ],
                              ),
                              ...standings.map((standing) {
                                final branch = standing['branch'] as String;
                                final name = standing['name'] as String;
                                final points = standing['points'] as int;
                                final rank = standing['rank'] as int;
                                final isTie = standing['isTie'] as bool;
                                
                                final isMyBranch = userBranch != null && branch.toUpperCase() == userBranch.toUpperCase();
                                
                                return TableRow(
                                  decoration: BoxDecoration(
                                    color: isMyBranch ? LitColors.ember.withValues(alpha: 0.08) : null,
                                  ),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: r.h(10)),
                                      child: Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _getRankWidget(rank, r),
                                            if (isTie)
                                              Text(
                                                '=',
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: LitColors.amber,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: r.sp(12),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: r.h(10), horizontal: r.w(6)),
                                      child: Text(
                                        name,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: isMyBranch ? LitColors.ember : LitColors.bone,
                                          fontWeight: isMyBranch ? FontWeight.bold : FontWeight.w500,
                                          fontSize: r.sp(11.5),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: r.h(10)),
                                      child: Center(
                                        child: Text(
                                          branch,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: isMyBranch ? LitColors.ember : LitColors.ash,
                                            fontWeight: isMyBranch ? FontWeight.bold : FontWeight.normal,
                                            fontSize: r.sp(11),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: r.h(10)),
                                      child: Center(
                                        child: Text(
                                          '$points',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: points > 0 ? LitColors.moss : LitColors.ash,
                                            fontWeight: FontWeight.bold,
                                            fontSize: r.sp(12),
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
                      );
                    },
                    loading: () => const LoadingView(),
                    error: (e, _) => ErrorView(message: e.toString()),
                  ),
          ),
          SizedBox(height: r.h(16)),
          // Manage Results / score entry for admins
          if (role.canManageResults) ...[
            ClayButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/results/score/${event.id}');
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note_rounded, size: r.icon(18)),
                  SizedBox(width: r.w(8)),
                  Text(isPublished ? 'Edit Results' : 'Manage Results'),
                ],
              ),
            ),
            SizedBox(height: r.h(10)),
          ],
          ClayButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/certificates');
            },
            isGhost: role.canManageResults,
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

  Widget _tableHeader(String text, Responsive r) {
    return Text(
      text,
      style: GoogleFonts.fredoka(
        color: LitColors.bone,
        fontSize: r.sp(11),
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _getRankWidget(int rank, Responsive r) {
    if (rank == 1) {
      return Text('🥇', style: TextStyle(fontSize: r.sp(16)));
    } else if (rank == 2) {
      return Text('🥈', style: TextStyle(fontSize: r.sp(16)));
    } else if (rank == 3) {
      return Text('🥉', style: TextStyle(fontSize: r.sp(16)));
    } else {
      return Text(
        '$rank',
        style: GoogleFonts.jetBrainsMono(
          color: LitColors.ash,
          fontWeight: FontWeight.bold,
          fontSize: r.sp(12),
        ),
      );
    }
  }

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
}
