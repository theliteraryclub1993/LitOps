import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/responsive.dart';

final studentListProvider = FutureProvider<List<Student>>((ref) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.studentMaster)
      .select()
      .order('name');
  return (data as List).map((e) => Student.fromJson(e)).toList();
});

final studentSearchQueryProvider = StateProvider<String>((ref) => '');

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentListProvider);
    final searchQuery = ref.watch(studentSearchQueryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Student Database', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: const Color(0xFFF3ECE2))),
      ),
      body: studentsAsync.when(
        data: (students) {
          final filteredStudents = students.where((student) {
            final query = searchQuery.toLowerCase();
            return student.name.toLowerCase().contains(query) ||
                student.usn.toLowerCase().contains(query) ||
                student.branch.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    ref.read(studentSearchQueryProvider.notifier).state = val.trim();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by USN or Name',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(studentSearchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: filteredStudents.isEmpty
                    ? EmptyView(
                        icon: Icons.person_off_outlined,
                        title: 'No students found',
                        subtitle: 'Add a new student or adjust your search filter.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(studentListProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 130),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF262220), width: 1.2),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    student.name.isNotEmpty ? student.name[0] : '?',
                                    style: GoogleFonts.plusJakartaSans(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(student.name,
                                    style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFF3ECE2),
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    '${student.usn} • ${student.branch} • Year ${student.year}',
                                    style: const TextStyle(color: Color(0xFF8C857C))),
                                trailing: const Icon(Icons.chevron_right, color: Color(0xFF8C857C)),
                                onTap: () => context.push('/students/${student.id}'),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => LoadingView(),
        error: (err, _) => Center(child: Text('Error loading students: $err', style: const TextStyle(color: Color(0xFFFF5C5C)))),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120, right: 8),
        child: FloatingActionButton(
          onPressed: () => context.push('/students/add'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: const Color(0xFF1A0D05),
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }
}

