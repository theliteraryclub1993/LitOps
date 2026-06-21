import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/utils/responsive.dart';

class WaitingListScreen extends ConsumerStatefulWidget {
  final String eventId;
  const WaitingListScreen({super.key, required this.eventId});
  @override
  ConsumerState<WaitingListScreen> createState() => _WaitingListScreenState();
}

class _WaitingListScreenState extends ConsumerState<WaitingListScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadList(); }

  Future<void> _loadList() async {
    setState(() => _loading = true);
    final data = await SupabaseConfig.client.from(SupabaseTables.waitingList)
        .select('*,student_master(name,usn,branch)').eq('event_id', widget.eventId).eq('is_promoted', false).order('position');
    setState(() { _entries = List<Map<String, dynamic>>.from(data as List); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Waiting List', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
      ),
      body: _loading ? const LoadingView() : _entries.isEmpty
          ? const EmptyView(icon: Icons.hourglass_empty, title: 'Waiting list is empty')
          : RefreshIndicator(
              onRefresh: _loadList,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _entries.length,
                itemBuilder: (ctx, i) {
                  final entry = _entries[i];
                  final student = entry['student_master'] as Map<String, dynamic>?;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: Text('${entry['position']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      title: Text(student?['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${student?['usn'] ?? ''} • ${student?['branch'] ?? ''}'),
                      trailing: const Icon(Icons.hourglass_empty, color: Colors.orange),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
