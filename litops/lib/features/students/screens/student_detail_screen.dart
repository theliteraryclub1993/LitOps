import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/utils/responsive.dart';

final studentDetailProvider = FutureProvider.family<Student, String>((ref, id) async {
  final data = await SupabaseConfig.client.from(SupabaseTables.studentMaster).select().eq('id', id).single();
  return Student.fromJson(data);
});

class StudentDetailScreen extends ConsumerWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentDetailProvider(studentId));
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Student Details', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
      ),
      body: studentAsync.when(
        data: (s) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(radius: 48, child: Text(s.name[0].toUpperCase(), style: const TextStyle(fontSize: 36))),
              const SizedBox(height: 16),
              Text(s.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StatusChip(label: s.status.label),
              const SizedBox(height: 24),
              Card(child: ListTile(title: const Text('USN'), subtitle: Text(s.usn))),
              Card(child: ListTile(title: const Text('Branch'), subtitle: Text(s.branch))),
              Card(child: ListTile(title: const Text('Year'), subtitle: Text('Year ${s.year}'))),
              if (s.section != null) Card(child: ListTile(title: const Text('Section'), subtitle: Text(s.section!))),
              if (s.phone != null) Card(child: ListTile(title: const Text('Phone'), subtitle: Text(s.phone!))),
              if (s.email != null) Card(child: ListTile(title: const Text('Email'), subtitle: Text(s.email!))),
              Card(child: ListTile(title: const Text('Added'), subtitle: Text(AppUtils.formatDateTime(s.createdAt)))),
            ],
          ),
        ),
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
      ),
    );
  }
}
