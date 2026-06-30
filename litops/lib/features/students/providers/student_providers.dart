import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../admin/providers/admin_providers.dart';
import '../../../core/enums/enums.dart';
import '../models/student_models.dart';

// Global indicator to check if import is actively running
final isImportingActiveProvider = StateProvider<bool>((ref) => false);

// Provider of all students from student_master (with realtime changes)
final studentMasterListProvider = FutureProvider<List<Student>>((ref) async {
  // Subscribe to real-time postgres changes to invalidate the provider
  final channel = SupabaseConfig.client.channel('student_master_realtime').onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: SupabaseTables.studentMaster,
    callback: (payload) {
      final isImporting = ref.read(isImportingActiveProvider);
      if (!isImporting) {
        ref.invalidateSelf();
      }
    },
  );
  
  channel.subscribe();
  
  ref.onDispose(() {
    SupabaseConfig.client.removeChannel(channel);
  });

  final data = await SupabaseConfig.client
      .from(SupabaseTables.studentMaster)
      .select();
      
  return (data as List).map((e) => Student.fromJson(e)).toList();
});

// Provider of all registrations
final registrationsListProvider = FutureProvider<List<Registration>>((ref) async {
  final channel = SupabaseConfig.client.channel('registrations_realtime').onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: SupabaseTables.registrations,
    callback: (payload) {
      ref.invalidateSelf();
    },
  );
  
  channel.subscribe();
  
  ref.onDispose(() {
    SupabaseConfig.client.removeChannel(channel);
  });

  final data = await SupabaseConfig.client
      .from(SupabaseTables.registrations)
      .select();
      
  return (data as List).map((e) => Registration.fromJson(e)).toList();
});

// Provider of all yearly imports
final yearlyImportsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final channel = SupabaseConfig.client.channel('yearly_imports_realtime').onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: SupabaseTables.yearlyImports,
    callback: (payload) {
      final isImporting = ref.read(isImportingActiveProvider);
      if (!isImporting) {
        ref.invalidateSelf();
      }
    },
  );
  
  channel.subscribe();
  
  ref.onDispose(() {
    SupabaseConfig.client.removeChannel(channel);
  });

  final data = await SupabaseConfig.client
      .from(SupabaseTables.yearlyImports)
      .select();
      
  return List<Map<String, dynamic>>.from(data as List);
});

// Main unified students list provider
final unifiedStudentsProvider = Provider<AsyncValue<List<UnifiedStudent>>>((ref) {
  final studentsAsync = ref.watch(studentMasterListProvider);
  final regsAsync = ref.watch(registrationsListProvider);
  final importsAsync = ref.watch(yearlyImportsListProvider);
  final activeArchiveAsync = ref.watch(activeYearlyArchiveProvider);

  if (studentsAsync.isLoading || regsAsync.isLoading || importsAsync.isLoading || activeArchiveAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (studentsAsync.hasError) return AsyncValue.error(studentsAsync.error!, studentsAsync.stackTrace!);
  if (regsAsync.hasError) return AsyncValue.error(regsAsync.error!, regsAsync.stackTrace!);
  if (importsAsync.hasError) return AsyncValue.error(importsAsync.error!, importsAsync.stackTrace!);
  if (activeArchiveAsync.hasError) return AsyncValue.error(activeArchiveAsync.error!, activeArchiveAsync.stackTrace!);

  final students = studentsAsync.value ?? [];
  final regs = regsAsync.value ?? [];
  final imports = importsAsync.value ?? [];
  final activeArchive = activeArchiveAsync.value;

  final currentFestYear = activeArchive?.festYear ?? 2026;

  // Map to hold unique students by USN
  final Map<String, UnifiedStudent> usnToStudentMap = {};

  // First, parse all yearly imports to populate historical and current records
  // Sort imports by fest_year ascending, so newer imports overwrite older ones
  final sortedImports = List<Map<String, dynamic>>.from(imports)
    ..sort((a, b) => (a['fest_year'] as int? ?? 0).compareTo(b['fest_year'] as int? ?? 0));

  for (final imp in sortedImports) {
    final festYear = imp['fest_year'] as int? ?? 0;
    final importDataRaw = imp['import_data'];
    if (importDataRaw == null) continue;

    final List<dynamic> records = importDataRaw is String 
        ? jsonDecode(importDataRaw) 
        : importDataRaw;

    for (final r in records) {
      if (r is! Map) continue;
      final usn = (r['usn'] as String?)?.toUpperCase().trim();
      if (usn == null || usn.isEmpty) continue;

      String? acadYear = r['academic_year'] as String?;
      if (acadYear == null || acadYear.isEmpty) {
        acadYear = '${festYear - 1}-${festYear.toString().substring(2)}';
      } else {
        acadYear = acadYear.replaceAll('–', '-').replaceAll('—', '-').trim();
      }

      final branch = r['branch'] as String? ?? 'CSE';
      final yearVal = int.tryParse(r['year']?.toString() ?? '') ?? 1;

      // Create a student placeholder for this import
      final bool isCurrentYear = festYear == currentFestYear;
      final dataSource = isCurrentYear ? 'Current Year' : 'Previous Years';

      usnToStudentMap[usn] = UnifiedStudent(
        id: usn, // Temporary ID equal to USN since they might not be in student_master yet
        usn: usn,
        name: r['name'] as String? ?? 'Imported Student',
        branch: branch,
        year: yearVal,
        section: r['section'] as String?,
        phone: r['phone']?.toString(),
        email: r['email'] as String?,
        gender: r['gender'] as String?,
        stream: r['stream'] as String?,
        status: StudentStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        academicYear: acadYear,
        festYear: festYear,
        isRegistered: false, // will check registrations next
        dataSource: dataSource,
      );
    }
  }

  // Active registrations set (only non-cancelled)
  final activeRegsStudentIds = regs
      .where((r) => !r.isCancelled)
      .map((r) => r.studentId)
      .toSet();

  for (final s in students) {
    final usnUpper = s.usn.toUpperCase().trim();
    final isRegistered = activeRegsStudentIds.contains(s.id);

    // Let's resolve the fest year and academic year for this student_master entry
    final existingImport = usnToStudentMap[usnUpper];
    final int resolvedFestYear = existingImport?.festYear ?? currentFestYear;
    final String resolvedAcadYear = (existingImport?.academicYear ?? 
        '${currentFestYear - 1}-${currentFestYear.toString().substring(2)}').replaceAll('–', '-').replaceAll('—', '-').trim();

    final bool isCurrentYear = isRegistered || 
        resolvedFestYear == currentFestYear || 
        existingImport == null;

    final dataSource = isCurrentYear ? 'Current Year' : 'Previous Years';

    // Update or insert the student in usnToStudentMap
    final mergedStudent = UnifiedStudent(
      id: s.id, // Use actual UUID from student_master
      usn: s.usn,
      name: s.name,
      branch: s.branch,
      year: s.year,
      section: s.section ?? existingImport?.section,
      phone: s.phone ?? existingImport?.phone,
      email: s.email ?? existingImport?.email,
      gender: s.gender ?? existingImport?.gender,
      stream: s.stream ?? existingImport?.stream,
      photoUrl: s.photoUrl,
      status: s.status,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      academicYear: resolvedAcadYear,
      festYear: resolvedFestYear,
      isRegistered: isRegistered,
      dataSource: dataSource,
    );

    if (usnUpper.isNotEmpty) {
      usnToStudentMap[usnUpper] = mergedStudent;
    } else {
      // If student has no USN, just add them with their UUID as key to avoid collisions
      usnToStudentMap[s.id] = mergedStudent;
    }
  }

  final List<UnifiedStudent> unifiedList = usnToStudentMap.values.toList();

  // Sort by name ascending
  unifiedList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return AsyncValue.data(unifiedList);
});

// Provider for a single student detail with their registrations and events
final studentRegistrationsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  // Fetch registrations, joining events and teams
  final data = await SupabaseConfig.client
      .from(SupabaseTables.registrations)
      .select('*, events(*), teams(team_name)')
      .eq('student_id', studentId)
      .eq('is_cancelled', false);
      
  return List<Map<String, dynamic>>.from(data as List);
});
