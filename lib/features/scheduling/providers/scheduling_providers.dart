import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';

// Fetch schedules
final eventSchedulesProvider = FutureProvider<List<EventSchedule>>((ref) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.eventSchedules)
      .select('*, events:event_id(title), coordinator:coordinator_id(full_name)')
      .order('schedule_date')
      .order('start_time');
  return (data as List).map((e) => EventSchedule.fromJson(e)).toList();
});

// Fetch assignments for an event, joining profiles
final eventAssignmentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.eventAssignments)
      .select('*, profiles!user_id(full_name, email, phone)')
      .eq('event_id', eventId);
  return List<Map<String, dynamic>>.from(data as List);
});

// Fetch participation constraints for an event
final eventConstraintsProvider = FutureProvider.family<List<ParticipationConstraint>, String>((ref, eventId) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.participationConstraints)
      .select()
      .eq('event_id', eventId);
  return (data as List).map((e) => ParticipationConstraint.fromJson(e)).toList();
});

// Controller for scheduling mutations
class SchedulingController {
  final Ref _ref;
  SchedulingController(this._ref);

  Future<void> saveEventSchedule({
    String? id,
    required String eventId,
    required DateTime scheduleDate,
    required String startTime,
    required String endTime,
    required String venue,
    bool isParallel = false,
    String? parallelGroup,
    int volunteerCount = 0,
    String? coordinatorId,
    String? notes,
    required String createdBy,
  }) async {
    final scheduleData = {
      'event_id': eventId,
      'schedule_date': scheduleDate.toIso8601String().split('T').first,
      'start_time': startTime,
      'end_time': endTime,
      'venue': venue,
      'is_parallel': isParallel,
      'parallel_group': parallelGroup,
      'volunteer_count': volunteerCount,
      'coordinator_id': coordinatorId,
      'notes': notes,
      'created_by': createdBy,
      'status': 'scheduled',
    };

    if (id != null) {
      await SupabaseConfig.client
          .from(SupabaseTables.eventSchedules)
          .update(scheduleData)
          .eq('id', id);
    } else {
      await SupabaseConfig.client
          .from(SupabaseTables.eventSchedules)
          .insert(scheduleData);
    }

    _ref.invalidate(eventSchedulesProvider);
  }

  Future<void> deleteEventSchedule(String id) async {
    await SupabaseConfig.client
        .from(SupabaseTables.eventSchedules)
        .delete()
        .eq('id', id);

    _ref.invalidate(eventSchedulesProvider);
  }

  Future<void> assignMember({
    required String eventId,
    required String userId,
    required AssignmentRole role,
    required String assignedBy,
  }) async {
    await SupabaseConfig.client.from(SupabaseTables.eventAssignments).insert({
      'event_id': eventId,
      'user_id': userId,
      'assignment_role': role.value,
      'assigned_by': assignedBy,
    });

    _ref.invalidate(eventAssignmentsProvider(eventId));
  }

  Future<void> removeAssignment(String assignmentId, String eventId) async {
    await SupabaseConfig.client
        .from(SupabaseTables.eventAssignments)
        .delete()
        .eq('id', assignmentId);

    _ref.invalidate(eventAssignmentsProvider(eventId));
  }

  Future<void> saveParticipationConstraint({
    required String eventId,
    required String branch,
    required int maxParticipants,
  }) async {
    await SupabaseConfig.client.from(SupabaseTables.participationConstraints).upsert({
      'event_id': eventId,
      'branch': branch,
      'max_participants': maxParticipants,
    }, onConflict: 'event_id, branch');

    _ref.invalidate(eventConstraintsProvider(eventId));
  }

  Future<void> deleteParticipationConstraint(String id, String eventId) async {
    await SupabaseConfig.client
        .from(SupabaseTables.participationConstraints)
        .delete()
        .eq('id', id);

    _ref.invalidate(eventConstraintsProvider(eventId));
  }
}

final schedulingControllerProvider = Provider((ref) => SchedulingController(ref));
