import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/widgets/common_widgets.dart';

final registeredParticipantsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  final client = SupabaseConfig.client;
  
  // Fetch event first to know if it's a team event
  final eventResponse = await client
      .from(SupabaseTables.events)
      .select()
      .eq('id', eventId)
      .single();
  
  final event = Event.fromJson(eventResponse);
  
  // Rule-based check: isTeamEvent flag OR teamSize > 1
  final isTeamEvent = event.isTeamEvent || event.teamSize > 1;
  
  if (isTeamEvent) {
    // Fetch teams with captain details and member count
    final response = await client
        .from(SupabaseTables.teams)
        .select('*, captain:student_master!captain_id(*), team_members(count)')
        .eq('event_id', eventId)
        .order('created_at', ascending: false);
        
    return (response as List).map((t) => t as Map<String, dynamic>).toList();
  } else {
    // Fetch individual registrations with student details
    final response = await client
        .from(SupabaseTables.registrations)
        .select('*, student:student_master!student_id(*)')
        .eq('event_id', eventId)
        .eq('is_cancelled', false)
        .order('registered_at', ascending: false);
        
    return (response as List).map((r) => r as Map<String, dynamic>).toList();
  }
});

final eventProvider = FutureProvider.family<Event, String>((ref, eventId) async {
  final response = await SupabaseConfig.client
      .from(SupabaseTables.events)
      .select()
      .eq('id', eventId)
      .single();
  return Event.fromJson(response);
});

class RegisteredParticipantsScreen extends ConsumerWidget {
  final String eventId;
  final Event? event;
  const RegisteredParticipantsScreen({super.key, required this.eventId, this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(registeredParticipantsProvider(eventId));
    final eventAsync = event != null 
        ? AsyncValue.data(event!) 
        : ref.watch(eventProvider(eventId));

    return eventAsync.when(
      data: (eventData) {
        final isTeamEvent = eventData.isTeamEvent || eventData.teamSize > 1;
        
        return Scaffold(
          backgroundColor: LitColors.void_,
          appBar: LitLifeAppBar(
            showBack: true,
            title: isTeamEvent ? 'Registered Teams' : 'Registered Participants',
          ),
          body: participantsAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return EmptyView(
                  icon: isTeamEvent ? Icons.groups_outlined : Icons.person_outline_rounded,
                  title: isTeamEvent ? 'No Teams' : 'No Registrations',
                  subtitle: isTeamEvent 
                      ? 'No teams have registered for this event yet.'
                      : 'No participants have registered for this event yet.',
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.refresh(registeredParticipantsProvider(eventId).future),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    if (isTeamEvent) {
                      return _buildTeamCard(context, item);
                    } else {
                      return _buildIndividualCard(context, item);
                    }
                  },
                ),
              );
            },
            loading: () => const LoadingView(),
            error: (e, s) => ErrorView(message: e.toString()),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: LitColors.void_,
        body: LoadingView(),
      ),
      error: (e, s) => Scaffold(
        backgroundColor: LitColors.void_,
        body: ErrorView(message: e.toString()),
      ),
    );
  }

  Widget _buildTeamCard(BuildContext context, Map<String, dynamic> team) {
    final captain = team['captain'] != null ? Student.fromJson(team['captain']) : null;
    final membersData = team['team_members'] as List?;
    final memberCount = (membersData != null && membersData.isNotEmpty) 
        ? (membersData[0]['count'] ?? 0)
        : 0;

    return ClayCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  team['team_name'] ?? 'Unnamed Team',
                  style: GoogleFonts.fredoka(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: LitColors.bone,
                  ),
                ),
              ),
              const StatusChip(label: 'Confirmed'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: LitColors.ash),
              const SizedBox(width: 8),
              Text(
                'Captain: ${captain?.name ?? 'Unknown'}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: LitColors.ash,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.groups_outlined, size: 14, color: LitColors.ash),
              const SizedBox(width: 8),
              Text(
                'Members: $memberCount',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: LitColors.ash,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualCard(BuildContext context, Map<String, dynamic> registration) {
    if (registration['student'] == null) {
      return const SizedBox();
    }
    
    final student = Student.fromJson(registration['student']);
    final year = student.year;
    final String friendlyYear = (year >= 1 && year <= 4) 
        ? ['First Year', 'Second Year', 'Third Year', 'Fourth Year'][year - 1]
        : 'Year $year';

    return ClayCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          UserAvatar(name: student.name, radius: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: GoogleFonts.fredoka(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: LitColors.bone,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${student.branch} • $friendlyYear',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: LitColors.ash,
                  ),
                ),
                Text(
                  student.usn,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: LitColors.ash.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: LitColors.moss, size: 18),
        ],
      ),
    );
  }
}
