import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';

class RoundsScreen extends ConsumerStatefulWidget {
  final String eventId;
  const RoundsScreen({super.key, required this.eventId});
  @override
  ConsumerState<RoundsScreen> createState() => _RoundsScreenState();
}

class _RoundsScreenState extends ConsumerState<RoundsScreen> {
  List<EventRound> _rounds = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _loadRounds(); }

  Future<void> _loadRounds() async {
    setState(() => _loading = true);
    final data = await SupabaseConfig.client.from(SupabaseTables.eventRounds).select().eq('event_id', widget.eventId).order('round_number');
    setState(() { _rounds = (data as List).map((r) => EventRound.fromJson(r)).toList(); _loading = false; });
  }

  Future<void> _addRound() async {
    final nameCtrl = TextEditingController();
    int roundNum = _rounds.length + 1;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('Add Round'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Round Name')),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(initialValue: roundNum, decoration: const InputDecoration(labelText: 'Round Number'),
          items: List.generate(10, (i) => DropdownMenuItem(value: i + 1, child: Text('Round ${i + 1}'))), onChanged: (v) => setS(() => roundNum = v!)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          await SupabaseConfig.client.from(SupabaseTables.eventRounds).insert({
            'event_id': widget.eventId, 'round_number': roundNum, 'round_name': nameCtrl.text.isNotEmpty ? nameCtrl.text : 'Round $roundNum',
          });
          Navigator.pop(ctx); _loadRounds();
        }, child: const Text('Add')),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Event Rounds', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.add, color: Color(0xFFF3ECE2)), onPressed: _addRound)],
      ),
      body: _loading ? const LoadingView() : _rounds.isEmpty
          ? const EmptyView(icon: Icons.layers_outlined, title: 'No rounds created')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rounds.length,
              itemBuilder: (ctx, i) {
                final r = _rounds[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${r.roundNumber}')),
                    title: Text(r.roundName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Status: ${r.status.label}'),
                    trailing: DropdownButton<RoundStatus>(
                      value: r.status,
                      items: RoundStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                      onChanged: (v) async {
                        await SupabaseConfig.client.from(SupabaseTables.eventRounds).update({'status': v!.value}).eq('id', r.id);
                        _loadRounds();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
