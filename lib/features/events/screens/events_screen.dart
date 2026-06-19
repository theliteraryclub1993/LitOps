import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/app_utils.dart';
import '../../auth/providers/auth_provider.dart';

final eventsListProvider = StreamProvider<List<Event>>((ref) async* {
  print('📡 [Realtime] eventsListProvider stream starting');
  
  try {
    final stream = SupabaseConfig.client
        .from(SupabaseTables.events)
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false);

    await for (final data in stream) {
      print('📡 [Realtime] eventsListProvider received ${data.length} events');
      for (var e in data) {
        print('   - Event: ${e['id']} - ${e['title']} - status: ${e['status']}');
      }
      yield data.map((e) => Event.fromJson(e)).toList();
    }
  } catch (e) {
    print('❌ [Realtime] eventsListProvider error: $e');
    rethrow;
  }
});

final eventSearchQueryProvider = StateProvider<String>((ref) => '');
final eventCategoryFilterProvider = StateProvider<EventCategory?>((ref) => null);

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsListProvider);
    final searchQuery = ref.watch(eventSearchQueryProvider);
    final categoryFilter = ref.watch(eventCategoryFilterProvider);

    final role = ref.watch(currentUserRoleProvider);
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Events',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16, color: LitColors.bone),
        ),
        actions: [
          if (role.canManageEventSchedule || profile?.year == 4)
            IconButton(
              icon: const Icon(Icons.calendar_month_rounded, color: LitColors.bone, size: 20),
              onPressed: () => context.push('/scheduling'),
              tooltip: 'Schedule Events',
            ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) {
          final filteredEvents = events.where((event) {
            final query = searchQuery.toLowerCase();
            final matchesSearch = event.name.toLowerCase().contains(query) ||
                (event.venue?.toLowerCase().contains(query) ?? false);
            final matchesCategory = categoryFilter == null || event.category == categoryFilter;
            return matchesSearch && matchesCategory;
          }).toList();

          // Apply Sorting Logic
          filteredEvents.sort((a, b) {
            // 1. Status Priority (Top/Active -> Future -> Bottom/Closed)
            int getStatusPriority(EventStatus status) {
              switch (status) {
                case EventStatus.ongoing:
                case EventStatus.registrationOpen:
                  return 0;
                case EventStatus.upcoming:
                  return 1;
                case EventStatus.draft:
                  return 2;
                case EventStatus.registrationClosed:
                case EventStatus.completed:
                case EventStatus.resultsPublished:
                case EventStatus.archived:
                  return 3;
              }
            }

            final pA = getStatusPriority(a.status);
            final pB = getStatusPriority(b.status);
            
            if (pA != pB) return pA.compareTo(pB);

            // 2. Category Priority (Balwaan -> Buddhimaan -> Darpan -> Kalakruthi)
            if (a.category.index != b.category.index) {
              return a.category.index.compareTo(b.category.index);
            }

            // 3. Recency (Newest first if same status and category)
            return b.createdAt.compareTo(a.createdAt);
          });

          return Column(
            children: [
              // Search and Category Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ClayTextField(
                      controller: _searchCtrl,
                      hintText: 'Search events...',
                      prefixIcon: const Icon(Icons.search),
                      onChanged: (val) {
                        ref.read(eventSearchQueryProvider.notifier).state = val.trim();
                      },
                      suffixIcon: searchQuery.isNotEmpty
                          ? GestureDetector(
                              child: const Icon(Icons.clear),
                              onTap: () {
                                _searchCtrl.clear();
                                ref.read(eventSearchQueryProvider.notifier).state = '';
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          CategoryChip(
                            category: 'All',
                            active: categoryFilter == null,
                            onTap: () {
                              ref.read(eventCategoryFilterProvider.notifier).state = null;
                            },
                          ),
                          ...EventCategory.values.map((cat) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: CategoryChip(
                                category: cat.value,
                                active: categoryFilter == cat,
                                onTap: () {
                                  ref.read(eventCategoryFilterProvider.notifier).state = cat;
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredEvents.isEmpty
                    ? const EmptyView(
                        icon: Icons.event_busy_outlined,
                        title: 'No events found',
                        subtitle: 'Check the search term or category filter.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(eventsListProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredEvents.length,
                          itemBuilder: (context, index) {
                            final event = filteredEvents[index];
                            return _buildEventCard(context, event);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (err, _) => Center(child: Text('Error loading events: $err', style: GoogleFonts.plusJakartaSans(color: LitColors.coral))),
      ),
      floatingActionButton: ref.watch(currentUserRoleProvider).canCreateEvents
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12, right: 8),
              child: ClayButton(
                width: 130,
                height: 48,
                borderRadius: 24,
                onPressed: () => context.push('/events/create'),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16),
                    SizedBox(width: 6),
                    Text('New Event'),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEventCard(BuildContext context, Event event) {
    return ClayCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/events/${event.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Raised Category Icon Container
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: LitColors.clay2,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              _getCategoryIcon(event.category),
              color: AppTheme.getCategoryColor(event.category.value),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        event.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fredoka(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: LitColors.bone,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(label: event.status.label),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.description ?? 'No description provided.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: LitColors.ash),
                    const SizedBox(width: 4),
                    Text(
                      event.venue ?? 'TBD',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: LitColors.ash),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today_outlined, size: 12, color: LitColors.ash),
                    const SizedBox(width: 4),
                    Text(
                      event.eventDate != null
                          ? AppUtils.formatDate(event.eventDate!)
                          : 'TBD',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: LitColors.ash),
                    ),
                  ],
                ),
                EventConstraintBadges(eventId: event.id),
              ],
            ),
          ),
        ],
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
}

final eventConstraintsSummaryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  try {
    final constraints = await SupabaseConfig.client
        .from(SupabaseTables.participationConstraints)
        .select()
        .eq('event_id', eventId);
        
    if ((constraints as List).isEmpty) return [];

    final regs = await SupabaseConfig.client
        .from(SupabaseTables.registrations)
        .select('student_master(branch)')
        .eq('event_id', eventId)
        .eq('is_cancelled', false);

    final counts = <String, int>{};
    for (final r in regs as List) {
      final student = r['student_master'] as Map<String, dynamic>?;
      if (student != null) {
        final branch = student['branch'] as String?;
        if (branch != null) {
          counts[branch] = (counts[branch] ?? 0) + 1;
        }
      }
    }

    return constraints.map((c) {
      final branch = c['branch'] as String;
      final maxVal = c['max_participants'] as int;
      final current = counts[branch] ?? 0;
      return {
        'branch': branch,
        'current': current,
        'max': maxVal,
      };
    }).toList();
  } catch (_) {
    return [];
  }
});

class EventConstraintBadges extends ConsumerWidget {
  final String eventId;
  const EventConstraintBadges({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(eventConstraintsSummaryProvider(eventId));
    return summaryAsync.when(
      data: (summary) {
        if (summary.isEmpty) return const SizedBox();
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: summary.map((s) {
              final branch = s['branch'] as String;
              final current = s['current'] as int;
              final maxVal = s['max'] as int;
              final isFull = current >= maxVal;

              final badgeColor = isFull ? LitColors.coral : LitColors.moss;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: badgeColor.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  '$branch: $current/$maxVal',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}
