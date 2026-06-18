import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/enums.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sarvottam/screens/leaderboard_screen.dart';

class ScoreEntryScreen extends ConsumerStatefulWidget {
  final String eventId;
  const ScoreEntryScreen({super.key, required this.eventId});
  @override
  ConsumerState<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends ConsumerState<ScoreEntryScreen> {
  List<Map<String, dynamic>> _registrations = [];
  final Map<String, String> _scoreCtrls = {};
  final Map<String, ResultPosition?> _positions = {};
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() { super.initState(); _loadRegistrations(); }

  Future<void> _loadRegistrations() async {
    setState(() => _loading = true);
    final data = await SupabaseConfig.client.from(SupabaseTables.registrations)
        .select('id,student_id,student_master(name,usn)').eq('event_id', widget.eventId).eq('is_cancelled', false);
    setState(() {
      _registrations = List<Map<String, dynamic>>.from(data as List);
      for (final r in _registrations) { _scoreCtrls[r['id']] = ''; _positions[r['id']] = null; }
      _loading = false;
    });
  }

  Future<void> _publishResults() async {
    setState(() => _saving = true);
    final profile = ref.read(currentProfileProvider);
    try {
      for (final reg in _registrations) {
        final position = _positions[reg['id']];
        if (position != null) {
          await SupabaseConfig.client.from(SupabaseTables.results).insert({
            'event_id': widget.eventId, 'registration_id': reg['id'],
            'position': position.value,
            'score': double.tryParse(_scoreCtrls[reg['id']] ?? ''),
            'published_at': DateTime.now().toIso8601String(),
            'published_by': profile!.id,
          });
        }
      }
      await SupabaseConfig.client.from(SupabaseTables.events).update({'status': 'results_published'}).eq('id', widget.eventId);
      ref.invalidate(leaderboardProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Results published!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Score Entry & Results', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
        actions: [
          if (_registrations.isNotEmpty)
            TextButton(onPressed: _saving ? null : _publishResults, child: const Text('Publish', style: TextStyle(color: Color(0xFFFF6A2C), fontWeight: FontWeight.bold))),
        ],
      ),
      body: _loading ? const LoadingView() : _registrations.isEmpty
          ? const EmptyView(icon: Icons.people_outline, title: 'No registrations')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _registrations.length,
              itemBuilder: (ctx, i) {
                final reg = _registrations[i];
                final student = reg['student_master'] as Map<String, dynamic>?;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student?['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(student?['usn'] ?? '', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(labelText: 'Score', isDense: true),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (v) => _scoreCtrls[reg['id']] = v,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<ResultPosition>(
                                initialValue: _positions[reg['id']],
                                decoration: const InputDecoration(labelText: 'Position', isDense: true),
                                items: ResultPosition.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                                onChanged: (v) => setState(() => _positions[reg['id']] = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
