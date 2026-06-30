import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../auth/providers/auth_settings_provider.dart';
import '../../students/providers/student_providers.dart';

// Providers for reading data
final pendingProfilesProvider = FutureProvider<List<Profile>>((ref) async {
  final profilesData = await SupabaseConfig.client
      .from(SupabaseTables.profiles)
      .select()
      .eq('profile_completed', true)
      .eq('profile_status', 'pending_review')
      .order('created_at', ascending: false);

  return (profilesData as List).map((p) => Profile.fromJson(p)).toList();
});

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

final _yearlyArchivesStream = StreamProvider((ref) => 
  SupabaseConfig.client.from(SupabaseTables.yearlyArchives).stream(primaryKey: ['id'])
);

final yearlyArchivesProvider = FutureProvider<List<YearlyArchive>>((ref) async {
  ref.watch(_yearlyArchivesStream);
  final data = await SupabaseConfig.client
      .from(SupabaseTables.yearlyArchives)
      .select()
      .order('fest_year', ascending: false);
  return (data as List).map((e) => YearlyArchive.fromJson(e)).toList();
});

final activeYearlyArchiveProvider = FutureProvider<YearlyArchive?>((ref) async {
  ref.watch(_yearlyArchivesStream);
  final data = await SupabaseConfig.client
      .from(SupabaseTables.yearlyArchives)
      .select()
      .eq('is_active', true)
      .maybeSingle();
  if (data == null) return null;
  return YearlyArchive.fromJson(data);
});

final _pointsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.eventPoints).stream(primaryKey: ['id']));
final _resultsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.results).stream(primaryKey: ['id']));
final _registrationsStream = StreamProvider((ref) => SupabaseConfig.client.from(SupabaseTables.registrations).stream(primaryKey: ['id']));

final departmentRankingsProvider = FutureProvider<List<DepartmentRanking>>((ref) async {
  // List of ALL participating departments
  final allDepartments = [
    'CS', 'IS', 'CI', 'CB', 'RI', 'EC', 'VL', 'EI', 'EE', 'CV', 'ME'
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

  Future<void> approveProfile(String profileId) async {
    await SupabaseConfig.client
        .from(SupabaseTables.profiles)
        .update({
          'profile_status': 'approved',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', profileId);
    _ref.invalidate(pendingProfilesProvider);
    _ref.invalidate(memberListProvider);
  }

  Future<void> rejectProfile(String profileId, String reason) async {
    await SupabaseConfig.client
        .from(SupabaseTables.profiles)
        .update({
          'profile_status': 'rejected',
          'rejection_reason': reason,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', profileId);
    _ref.invalidate(pendingProfilesProvider);
  }

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
    DateTime? dob,
    String? usn,
    String? branch,
    String? department,
    int? year,
    UserRole? role,
    bool? isActive,
    List<String>? customPermissions,
    String? photoUrl,
  }) async {
    final updateData = <String, dynamic>{};
    if (memberName != null) updateData['full_name'] = memberName;
    if (memberEmail != null) updateData['email'] = memberEmail;
    if (memberPhone != null) updateData['phone'] = memberPhone;
    if (dob != null) updateData['date_of_birth'] = dob.toIso8601String().split('T').first;
    if (usn != null) updateData['usn'] = usn;
    if (branch != null) updateData['branch'] = branch;
    if (department != null) updateData['department'] = department;
    if (year != null) updateData['year'] = year;
    if (role != null) updateData['role'] = role.value;
    if (isActive != null) updateData['is_active'] = isActive;
    if (customPermissions != null) updateData['custom_permissions'] = customPermissions;
    if (photoUrl != null) updateData['photo_url'] = photoUrl;

    if (updateData.isNotEmpty) {
      // If email is being updated, call RPC to sync auth.users and auth.identities
      if (memberEmail != null) {
        await SupabaseConfig.client.rpc(
          'admin_update_user_auth',
          params: {
            'p_user_id': userId,
            'p_email': memberEmail,
          },
        );
      }

      await SupabaseConfig.client
          .from(SupabaseTables.profiles)
          .update(updateData)
          .eq('id', userId);

      // Also update member_assignments if role is changed
      if (role != null) {
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
        }
      }

      // Also update member_assignments status if isActive is changed
      if (isActive != null) {
        final existing = await SupabaseConfig.client
            .from(SupabaseTables.memberAssignments)
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (existing != null) {
          await SupabaseConfig.client
              .from(SupabaseTables.memberAssignments)
              .update({
                'status': isActive ? MemberStatus.active.value : MemberStatus.suspended.value,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId);
        }
      }

      _ref.invalidate(memberListProvider);
    }
  }

  Future<void> removeMember(String assignmentId, String userId) async {
    // Call the delete_member_profile RPC to permanently remove the user,
    // revert/nullify foreign keys, clean up assignments, and delete auth user.
    await SupabaseConfig.client.rpc(
      'delete_member_profile',
      params: {'target_user_id': userId},
    );

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

  /// Deletes a yearly archive and cascades to yearly_imports and student_master.
  /// Only removes students from student_master whose USNs do NOT appear in
  /// any other remaining yearly_imports record (cross-year safety).
  Future<void> deleteYearlyArchive(String archiveId, int festYear) async {
    // 1. Fetch all yearly_imports rows for this fest_year to extract USNs
    final importsData = await SupabaseConfig.client
        .from(SupabaseTables.yearlyImports)
        .select('id, import_data')
        .eq('fest_year', festYear);

    final importRows = importsData as List;
    final Set<String> usnsToDelete = {};

    for (final row in importRows) {
      final rawData = row['import_data'];
      if (rawData == null) continue;
      final List<dynamic> records =
          rawData is String ? jsonDecode(rawData) : rawData;
      for (final r in records) {
        if (r is! Map) continue;
        final usn = (r['usn'] as String?)?.toUpperCase().trim();
        if (usn != null && usn.isNotEmpty) {
          usnsToDelete.add(usn);
        }
      }
    }

    // 2. Cross-year safety: find USNs that appear in OTHER years' imports
    if (usnsToDelete.isNotEmpty) {
      final otherImports = await SupabaseConfig.client
          .from(SupabaseTables.yearlyImports)
          .select('import_data')
          .neq('fest_year', festYear);

      final Set<String> usnsInOtherYears = {};
      for (final row in (otherImports as List)) {
        final rawData = row['import_data'];
        if (rawData == null) continue;
        final List<dynamic> records =
            rawData is String ? jsonDecode(rawData) : rawData;
        for (final r in records) {
          if (r is! Map) continue;
          final usn = (r['usn'] as String?)?.toUpperCase().trim();
          if (usn != null && usn.isNotEmpty) {
            usnsInOtherYears.add(usn);
          }
        }
      }

      // Only delete USNs that are NOT referenced by any other year
      usnsToDelete.removeAll(usnsInOtherYears);
    }

    // 3. Delete orphaned students from student_master in chunks
    if (usnsToDelete.isNotEmpty) {
      final usnList = usnsToDelete.toList();
      const chunkSize = 100;
      for (int i = 0; i < usnList.length; i += chunkSize) {
        final end = (i + chunkSize > usnList.length)
            ? usnList.length
            : i + chunkSize;
        final chunk = usnList.sublist(i, end);
        await SupabaseConfig.client
            .from(SupabaseTables.studentMaster)
            .delete()
            .inFilter('usn', chunk);
      }
    }

    // 4. Delete yearly_imports rows for this fest_year
    await SupabaseConfig.client
        .from(SupabaseTables.yearlyImports)
        .delete()
        .eq('fest_year', festYear);

    // 5. Delete the yearly_archives row
    await SupabaseConfig.client
        .from(SupabaseTables.yearlyArchives)
        .delete()
        .eq('id', archiveId);

    // 6. Invalidate all affected providers
    _ref.invalidate(yearlyArchivesProvider);
    _ref.invalidate(studentMasterListProvider);
    _ref.invalidate(yearlyImportsListProvider);
  }

  // ── Sign-In / Registration Control ─────────────────────────────────
  Future<void> toggleSignIn(bool enabled) async {
    await upsertAppSetting('sign_in_enabled', enabled.toString());
    _ref.invalidate(authSettingsProvider);
  }

  Future<void> toggleRegistration(bool enabled) async {
    await upsertAppSetting('registration_enabled', enabled.toString());
    _ref.invalidate(authSettingsProvider);
  }

  Future<void> updateSignInDisabledMessage(String message) async {
    await upsertAppSetting('sign_in_disabled_message', message.trim());
    _ref.invalidate(authSettingsProvider);
  }
}

final adminControllerProvider = Provider((ref) => AdminController(ref));
