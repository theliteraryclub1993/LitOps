import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../admin/providers/admin_providers.dart';
import '../models/student_models.dart';

// Global indicator to check if import is actively running
final isImportingActiveProvider = StateProvider<bool>((ref) => false);

// Provider of all students from student_master (with realtime changes)
final studentMasterListProvider = FutureProvider<List<Student>>((ref) async {
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

// Stream/fetch history of import jobs from import_batches table
final importBatchesListProvider = FutureProvider<List<ImportBatch>>((ref) async {
  final channel = SupabaseConfig.client.channel('import_batches_realtime').onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'import_batches',
    callback: (payload) {
      ref.invalidateSelf();
    },
  );
  
  channel.subscribe();
  
  ref.onDispose(() {
    SupabaseConfig.client.removeChannel(channel);
  });

  final data = await SupabaseConfig.client
      .from('import_batches')
      .select()
      .order('created_at', ascending: false);
      
  return (data as List).map((e) => ImportBatch.fromJson(e)).toList();
});

// Model for student filters
class StudentFilterState {
  final int page;
  final int pageSize;
  final String searchQuery;
  final String academicYear;
  final String department;
  final String year;
  final String section;

  const StudentFilterState({
    this.page = 1,
    this.pageSize = 20,
    this.searchQuery = '',
    this.academicYear = 'All',
    this.department = 'All',
    this.year = 'All',
    this.section = 'All',
  });

  StudentFilterState copyWith({
    int? page,
    int? pageSize,
    String? searchQuery,
    String? academicYear,
    String? department,
    String? year,
    String? section,
  }) {
    return StudentFilterState(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      searchQuery: searchQuery ?? this.searchQuery,
      academicYear: academicYear ?? this.academicYear,
      department: department ?? this.department,
      year: year ?? this.year,
      section: section ?? this.section,
    );
  }
}

// StateNotifier for student pagination/filters
class StudentFilterNotifier extends StateNotifier<StudentFilterState> {
  StudentFilterNotifier() : super(const StudentFilterState());

  void setPage(int page) => state = state.copyWith(page: page);
  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query, page: 1);
  void setAcademicYear(String year) => state = state.copyWith(academicYear: year, page: 1);
  void setDepartment(String dept) => state = state.copyWith(department: dept, page: 1);
  void setYear(String y) => state = state.copyWith(year: y, page: 1);
  void setSection(String sec) => state = state.copyWith(section: sec, page: 1);
  
  void reset() => state = const StudentFilterState();
}

final studentFilterProvider = StateNotifierProvider<StudentFilterNotifier, StudentFilterState>((ref) {
  return StudentFilterNotifier();
});

class PaginatedStudentsResult {
  final List<Student> students;
  final int totalCount;

  const PaginatedStudentsResult({
    required this.students,
    required this.totalCount,
  });
}

// Server-side paginated student provider
final paginatedStudentsProvider = FutureProvider<PaginatedStudentsResult>((ref) async {
  final filters = ref.watch(studentFilterProvider);
  
  // Realtime subscription mapping for updates
  ref.watch(studentMasterListProvider);
  
  var query = SupabaseConfig.client
      .from(SupabaseTables.studentMaster)
      .select('*');

  // Search Query
  if (filters.searchQuery.isNotEmpty) {
    query = query.or('usn.ilike.%${filters.searchQuery}%,name.ilike.%${filters.searchQuery}%');
  }

  // Academic Year
  if (filters.academicYear != 'All') {
    query = query.eq('academic_year', filters.academicYear);
  }

  // Department
  if (filters.department != 'All') {
    query = query.eq('branch', filters.department);
  }

  // Study Year
  if (filters.year != 'All') {
    final y = int.tryParse(filters.year);
    if (y != null) {
      query = query.eq('year', y);
    }
  }

  // Section
  if (filters.section != 'All') {
    query = query.eq('section', filters.section);
  }

  final finalQuery = query.order('name', ascending: true);

  // Range
  final from = (filters.page - 1) * filters.pageSize;
  final to = from + filters.pageSize - 1;

  final response = await finalQuery.range(from, to).count(CountOption.exact);
  final studentsList = (response.data as List).map((e) => Student.fromJson(e as Map<String, dynamic>)).toList();
  final totalCount = response.count;

  return PaginatedStudentsResult(
    students: studentsList,
    totalCount: totalCount,
  );
});

// Dynamic academic years list retrieved from unique database records
final distinctAcademicYearsProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(studentMasterListProvider);
  final response = await SupabaseConfig.client
      .from(SupabaseTables.studentMaster)
      .select('academic_year');
      
  final list = response as List;
  final years = list
      .map((e) => e['academic_year'] as String?)
      .where((e) => e != null && e.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();
      
  years.sort((a, b) => b.compareTo(a)); // Sort descending (newest first)
  return years;
});

// Dynamic sections list retrieved from unique database records
final distinctSectionsProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(studentMasterListProvider);
  final response = await SupabaseConfig.client
      .from(SupabaseTables.studentMaster)
      .select('section');
      
  final list = response as List;
  final sections = list
      .map((e) => e['section'] as String?)
      .where((e) => e != null && e.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();
      
  sections.sort();
  return sections;
});

// Family provider to check registrations of currently paginated/displayed student IDs
final pageRegistrationsProvider = FutureProvider.family<Set<String>, List<String>>((ref, studentIds) async {
  if (studentIds.isEmpty) return {};
  
  // Real-time invalidations on registration list
  ref.watch(registrationsListProvider);

  final data = await SupabaseConfig.client
      .from(SupabaseTables.registrations)
      .select('student_id')
      .inFilter('student_id', studentIds)
      .eq('is_cancelled', false);
      
  final Set<String> registered = {};
  for (final row in (data as List)) {
    final sId = row['student_id'] as String?;
    if (sId != null) {
      registered.add(sId);
    }
  }
  return registered;
});

// Fetch detailed information for a single student by UUID
final studentDetailsProvider = FutureProvider.family<Student?, String>((ref, studentId) async {
  ref.watch(studentMasterListProvider);
  final response = await SupabaseConfig.client
      .from(SupabaseTables.studentMaster)
      .select()
      .eq('id', studentId)
      .maybeSingle();
      
  if (response == null) return null;
  return Student.fromJson(response);
});

// Unified students list provider (backward compatibility for any external pages)
final unifiedStudentsProvider = Provider<AsyncValue<List<UnifiedStudent>>>((ref) {
  final studentsAsync = ref.watch(studentMasterListProvider);
  final activeArchiveAsync = ref.watch(activeYearlyArchiveProvider);

  if (studentsAsync.isLoading || activeArchiveAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (studentsAsync.hasError) return AsyncValue.error(studentsAsync.error!, studentsAsync.stackTrace!);
  if (activeArchiveAsync.hasError) return AsyncValue.error(activeArchiveAsync.error!, activeArchiveAsync.stackTrace!);

  final students = studentsAsync.value ?? [];
  final activeArchive = activeArchiveAsync.value;
  final currentFestYear = activeArchive?.festYear ?? 2026;
  final currentAcadYear = '${currentFestYear - 1}-${currentFestYear.toString().substring(2)}';

  final list = students.map((s) {
    final bool isCurrent = s.academicYear == currentAcadYear || s.academicYear == null;
    return UnifiedStudent(
      id: s.id,
      usn: s.usn,
      name: s.name,
      branch: s.branch,
      year: s.year,
      section: s.section,
      phone: s.phone,
      email: s.email,
      gender: s.gender,
      stream: s.stream,
      photoUrl: s.photoUrl,
      status: s.status,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      academicYear: s.academicYear ?? currentAcadYear,
      festYear: currentFestYear,
      isRegistered: false,
      dataSource: isCurrent ? 'Current Year' : 'Previous Years',
    );
  }).toList();
  
  return AsyncValue.data(list);
});

// Provider for a student's registrations and events
final studentRegistrationsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  ref.watch(registrationsListProvider);
  final data = await SupabaseConfig.client
      .from(SupabaseTables.registrations)
      .select('*, events(*), teams(team_name)')
      .eq('student_id', studentId)
      .eq('is_cancelled', false);
      
  return List<Map<String, dynamic>>.from(data as List);
});
