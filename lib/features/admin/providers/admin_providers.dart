import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';

// Providers for reading data
final memberListProvider = FutureProvider<List<ClubMember>>((ref) async {
  final profilesData = await SupabaseConfig.client
      .from(SupabaseTables.profiles)
      .select('*, member_assignments!member_assignments_user_id_fkey(*)')
      .order('created_at', ascending: false);

  return (profilesData as List).map((p) {
    final assignments = p['member_assignments'] as List?;
    final assignment = (assignments != null && assignments.isNotEmpty) ? assignments.first : null;
    
    return ClubMember(
      id: assignment?['id'] ?? p['id'], // Fallback to profile id
      userId: p['id'],
      role: UserRole.fromString(p['role'] as String), // Role directly from profile
      status: assignment != null 
          ? MemberStatus.fromString(assignment['status']) 
          : (p['is_active'] == false ? MemberStatus.inactive : MemberStatus.active),
      assignedBy: assignment?['assigned_by'] ?? 'system',
      assignedAt: assignment != null 
          ? DateTime.parse(assignment['assigned_at']) 
          : DateTime.parse(p['created_at']),
      suspendedAt: assignment?['suspended_at'] != null 
          ? DateTime.parse(assignment['suspended_at']) 
          : null,
      suspendedReason: assignment?['suspended_reason'],
      reactivatedAt: assignment?['reactivated_at'] != null 
          ? DateTime.parse(assignment['reactivated_at']) 
          : null,
      notes: assignment?['notes'],
      createdAt: DateTime.parse(p['created_at']),
      updatedAt: DateTime.parse(p['updated_at']),
      memberName: p['full_name'],
      memberEmail: p['email'],
      memberPhone: p['phone'],
    );
  }).toList();
});

final auditLogsProvider = FutureProvider<List<AuditExtended>>((ref) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.auditExtended)
      .select()
      .order('created_at', ascending: false);
  return (data as List).map((e) => AuditExtended.fromJson(e)).toList();
});

final yearlyArchivesProvider = FutureProvider<List<YearlyArchive>>((ref) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.yearlyArchives)
      .select()
      .order('fest_year', ascending: false);
  return (data as List).map((e) => YearlyArchive.fromJson(e)).toList();
});

final _pointsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.eventPoints).stream(primaryKey: ['id']));
final _resultsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.results).stream(primaryKey: ['id']));
final _registrationsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.registrations).stream(primaryKey: ['id']));

final departmentRankingsProvider = FutureProvider<List<DepartmentRanking>>((ref) async {
  // List of ALL participating departments
  final allDepartments = [
    'CSE', 'ISE', 'ECE', 'EEE', 'ME', 'CE', 'IPE', 'IEM', 'CH', 'MCA'
  ];

  // Watch points stream to trigger re-calculation
  ref.watch(_pointsStream);
  
  try {
    // 1. Fetch all event points (single source of truth)
    final pointsData = await SupabaseConfig.client
        .from(SupabaseTables.eventPoints)
        .select();
    final manualPoints = (pointsData as List).map((e) => EventPoint.fromJson(e)).toList();

    // 2. Group and sum by branch - initialize ALL departments with 0
    final Map<String, Map<String, dynamic>> branchStats = {};
    for (final dept in allDepartments) {
      branchStats[dept] = {'points': 0, 'wins': 0, 'runnerUps': 0, 'secondRunnerUps': 0};
    }
    
    void addPoints(String branch, int points, {bool isWin = false, bool isRunner = false, bool isSecondRunner = false}) {
      final b = branch.toUpperCase();
      if (!branchStats.containsKey(b)) return; // Skip if not in allDepartments
      branchStats[b]!['points'] += points;
      if (isWin) branchStats[b]!['wins'] += 1;
      if (isRunner) branchStats[b]!['runnerUps'] += 1;
      if (isSecondRunner) branchStats[b]!['secondRunnerUps'] += 1;
    }

    // Process all event points
    for (var p in manualPoints) {
      addPoints(p.branch, p.points, 
        isWin: p.position == ResultPosition.winner,
        isRunner: p.position == ResultPosition.runnerUp,
        isSecondRunner: p.position == ResultPosition.secondRunnerUp);
    }

    // 3. Convert to DepartmentRanking list and sort
    final List<DepartmentRanking> rankings = branchStats.entries.map((entry) {
      return DepartmentRanking(
        id: entry.key,
        festYear: 2024,
        branch: entry.key,
        totalPoints: entry.value['points'],
        totalWins: entry.value['wins'],
        totalRunnerUps: entry.value['runnerUps'],
        totalSecondRunnerUps: entry.value['secondRunnerUps'],
        lastCalculatedAt: DateTime.now(),
      );
    }).toList();

    rankings.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    return rankings;
  } catch (e) {
    debugPrint('Error calculating live rankings: $e');
    final data = await SupabaseConfig.client
        .from(SupabaseTables.departmentRankings)
        .select()
        .order('total_points', ascending: false);
    return (data as List).map((e) => DepartmentRanking.fromJson(e)).toList();
  }
});

final eventPointsProvider = StreamProvider<List<EventPoint>>((ref) {
  return SupabaseConfig.client
      .from(SupabaseTables.eventPoints)
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((data) => data.map((e) => EventPoint.fromJson(e)).toList());
});

// Non-member profiles search (to add them as members)
final nonMemberProfilesProvider = FutureProvider<List<Profile>>((ref) async {
  // 1. Get all members' user_ids
  final membersData = await SupabaseConfig.client
      .from(SupabaseTables.memberAssignments)
      .select('user_id');
  final memberIds = (membersData as List).map((e) => e['user_id'] as String).toList();

  // 2. Get profiles that are NOT in the members list
  var query = SupabaseConfig.client.from(SupabaseTables.profiles).select();
  if (memberIds.isNotEmpty) {
    query = query.not('id', 'in', memberIds);
  }
  
  final profilesData = await query.order('full_name');
  return (profilesData as List).map((e) => Profile.fromJson(e)).toList();
});

// Controller for mutating data
class AdminController {
  final Ref _ref;
  AdminController(this._ref);

  // Club Member actions
  Future<void> addMember(String userId, UserRole role, String assignedBy, {String? notes}) async {
    // 1. Add assignment
    await SupabaseConfig.client.from(SupabaseTables.memberAssignments).insert({
      'user_id': userId,
      'role': role.value,
      'status': MemberStatus.active.value,
      'assigned_by': assignedBy,
      'notes': notes,
    });

    // 2. Update profiles table to match
    await SupabaseConfig.client
        .from(SupabaseTables.profiles)
        .update({'role': role.value})
        .eq('id', userId);

    // Invalidate list
    _ref.invalidate(memberListProvider);
    _ref.invalidate(nonMemberProfilesProvider);
  }

  Future<void> updateMemberRole(String assignmentId, String userId, UserRole role) async {
    // 1. Check if assignment exists
    final existing = await SupabaseConfig.client
        .from(SupabaseTables.memberAssignments)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await SupabaseConfig.client
          .from(SupabaseTables.memberAssignments)
          .update({
            'role': role.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
    } else {
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id ?? 'system';
      await SupabaseConfig.client.from(SupabaseTables.memberAssignments).insert({
        'user_id': userId,
        'role': role.value,
        'status': MemberStatus.active.value,
        'assigned_by': currentUserId,
      });
    }

    // 2. Update profiles role
    await SupabaseConfig.client
        .from(SupabaseTables.profiles)
        .update({'role': role.value})
        .eq('id', userId);

    _ref.invalidate(memberListProvider);
  }

  Future<void> updateMemberStatus(
    String assignmentId,
    String userId,
    MemberStatus status, {
    String? reason,
  }) async {
    final updateData = <String, dynamic>{
      'status': status.value,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (status == MemberStatus.suspended) {
      updateData['suspended_at'] = DateTime.now().toIso8601String();
      updateData['suspended_reason'] = reason;
    } else if (status == MemberStatus.active) {
      updateData['reactivated_at'] = DateTime.now().toIso8601String();
      updateData['suspended_at'] = null;
      updateData['suspended_reason'] = null;
    }

    final existing = await SupabaseConfig.client
        .from(SupabaseTables.memberAssignments)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      // 1. Update assignment
      await SupabaseConfig.client
          .from(SupabaseTables.memberAssignments)
          .update(updateData)
          .eq('user_id', userId);
    } else {
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id ?? 'system';
      updateData['user_id'] = userId;
      updateData['role'] = UserRole.juniorWing.value;
      updateData['assigned_by'] = currentUserId;
      await SupabaseConfig.client.from(SupabaseTables.memberAssignments).insert(updateData);
    }

    // 2. If suspended or inactive, we disable active status, but keep their profile role
    await SupabaseConfig.client
        .from(SupabaseTables.profiles)
        .update({'is_active': status == MemberStatus.active})
        .eq('id', userId);

    _ref.invalidate(memberListProvider);
  }

  Future<void> updateMemberDetails({
    required String userId,
    String? memberName,
    String? memberEmail,
    String? memberPhone,
  }) async {
    final updateData = <String, dynamic>{};
    if (memberName != null) updateData['full_name'] = memberName;
    if (memberEmail != null) updateData['email'] = memberEmail;
    if (memberPhone != null) updateData['phone'] = memberPhone;

    if (updateData.isNotEmpty) {
      await SupabaseConfig.client
          .from(SupabaseTables.profiles)
          .update(updateData)
          .eq('id', userId);
      _ref.invalidate(memberListProvider);
    }
  }

  Future<void> removeMember(String assignmentId, String userId) async {
    // 1. Delete assignment
    await SupabaseConfig.client
        .from(SupabaseTables.memberAssignments)
        .delete()
        .eq('id', assignmentId);

    // 2. Revert profile role to junior wing
    await SupabaseConfig.client
        .from(SupabaseTables.profiles)
        .update({
          'role': UserRole.juniorWing.value,
          'is_active': true,
        })
        .eq('id', userId);

    _ref.invalidate(memberListProvider);
    _ref.invalidate(nonMemberProfilesProvider);
  }

  // Points actions
  Future<void> allocateEventPoints({
    required String eventId,
    required String branch,
    String? studentId,
    String? teamId,
    required int points,
    required String reason,
    ResultPosition? position,
    required String allocatedBy,
  }) async {
    await SupabaseConfig.client.from(SupabaseTables.eventPoints).insert({
      'event_id': eventId,
      'branch': branch,
      'student_id': studentId,
      'team_id': teamId,
      'points': points,
      'reason': reason,
      'position': position?.value,
      'allocated_by': allocatedBy,
    });

    _ref.invalidate(eventPointsProvider);
    _ref.invalidate(departmentRankingsProvider);
  }

  Future<void> deleteEventPoints(String pointId) async {
    await SupabaseConfig.client
        .from(SupabaseTables.eventPoints)
        .delete()
        .eq('id', pointId);

    _ref.invalidate(eventPointsProvider);
    _ref.invalidate(departmentRankingsProvider);
  }

  // Yearly Database actions
  Future<void> createYearlyArchive({
    required int year,
    required String festName,
    int totalEvents = 0,
    int totalRegistrations = 0,
    int totalParticipants = 0,
    int totalAttendance = 0,
    required String createdBy,
  }) async {
    await SupabaseConfig.client.from(SupabaseTables.yearlyArchives).insert({
      'fest_year': year,
      'fest_name': festName,
      'total_events': totalEvents,
      'total_registrations': totalRegistrations,
      'total_participants': totalParticipants,
      'total_attendance': totalAttendance,
      'created_by': createdBy,
    });

    _ref.invalidate(yearlyArchivesProvider);
  }

  Future<void> deleteYearlyArchive(String archiveId) async {
    await SupabaseConfig.client
        .from(SupabaseTables.yearlyArchives)
        .delete()
        .eq('id', archiveId);

    _ref.invalidate(yearlyArchivesProvider);
  }
}

final adminControllerProvider = Provider((ref) => AdminController(ref));
