import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sarvottam/screens/leaderboard_screen.dart';
import '../../../core/utils/responsive.dart';

class ScoreEntryScreen extends ConsumerStatefulWidget {
  final String eventId;
  const ScoreEntryScreen({super.key, required this.eventId});
  @override
  ConsumerState<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends ConsumerState<ScoreEntryScreen> {
  Event? _event;
  List<Map<String, dynamic>> _registrations = [];
  final Map<String, ResultPosition?> _positions = {};
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadEventAndRegistrations();
  }

  Future<void> _loadEventAndRegistrations() async {
    setState(() => _loading = true);
    try {
      // Load event
      final eventData = await SupabaseConfig.client
          .from(SupabaseTables.events)
          .select()
          .eq('id', widget.eventId)
          .single();
      setState(() => _event = Event.fromJson(eventData));

      // Load registrations
      final regData = await SupabaseConfig.client
          .from(SupabaseTables.registrations)
          .select('id, student_id, team_id, student_master(id, name, usn, branch), teams(id, team_name)')
          .eq('event_id', widget.eventId)
          .eq('is_cancelled', false);

      setState(() {
        _registrations = List<Map<String, dynamic>>.from(regData as List);
        for (final reg in _registrations) {
          _positions[reg['id']] = null;
        }
      });
    } catch (e) {
      debugPrint('Error loading: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _publishResults() async {
    // First check: at least one position selected
    final hasAnyPosition = _positions.values.any((p) => p != null);
    if (!hasAnyPosition) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one position (Winner/Runner-Up) before publishing!'),
            backgroundColor: Colors.amber,
          ),
        );
      }
      return;
    }

    setState(() => _saving = true);
    final profile = ref.read(currentProfileProvider);
    try {
      // Delete existing results for this event first
      await SupabaseConfig.client.from(SupabaseTables.results).delete().eq('event_id', widget.eventId);
      // Delete existing event points for this event
      await SupabaseConfig.client.from(SupabaseTables.eventPoints).delete().eq('event_id', widget.eventId);
      
      int insertedCount = 0;
      // Insert new results
      for (final reg in _registrations) {
        final position = _positions[reg['id']];
        if (position != null) {
          debugPrint('Inserting result for reg ${reg['id']}: ${position.label}');
          await SupabaseConfig.client.from(SupabaseTables.results).insert({
            'event_id': widget.eventId,
            'registration_id': reg['id'],
            'team_id': reg['team_id'],
            'position': position.value,
            'score': null,
            'published_at': DateTime.now().toIso8601String(),
            'published_by': profile!.id,
          });
          insertedCount++;

          // Insert Sarvottam point (only per branch/registration, no student tracking)
          final student = reg['student_master'] as Map<String, dynamic>?;
          final team = reg['teams'] as Map<String, dynamic>?;
          
          String? branch;
          if (student != null) {
            branch = student['branch'] as String?;
          }
          
          if (branch == null && team != null) {
            // For team events, get branch from one of team members if needed, but for now assume student master exists for at least one
          }
          
          if (branch != null) {
            await SupabaseConfig.client.from(SupabaseTables.eventPoints).insert({
              'event_id': widget.eventId,
              'branch': branch,
              'student_id': null, // No individual student tracking
              'team_id': reg['team_id'],
              'points': position.points,
              'reason': 'Event result - ${position.label}',
              'position': position.value,
              'allocated_by': profile.id,
            });
          }
        }
      }

      debugPrint('Inserted $insertedCount results');

      // Update event status and updated_at
      await SupabaseConfig.client.from(SupabaseTables.events).update({
        'status': EventStatus.resultsPublished.value,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.eventId);

      // Refresh leaderboard
      ref.invalidate(leaderboardProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully published $insertedCount results!')),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('Error publishing: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error publishing: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    if (!role.canManageResults) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFF3ECE2)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Access Denied', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
        ),
        body: const Center(
          child: EmptyView(
            icon: Icons.lock_outline,
            title: 'Not Authorized',
            subtitle: 'You don\'t have permission to publish results.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF3ECE2)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _event?.name ?? 'Result Entry',
          style: const TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_registrations.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _publishResults,
              child: const Text('Publish', style: TextStyle(color: Color(0xFFFF6A2C), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _registrations.isEmpty
              ? const EmptyView(icon: Icons.people_outline, title: 'No registrations')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _registrations.length,
                  itemBuilder: (ctx, i) {
                    final reg = _registrations[i];
                    final student = reg['student_master'] as Map<String, dynamic>?;
                    final team = reg['teams'] as Map<String, dynamic>?;
                    final displayName = team != null
                        ? team['team_name'] as String?
                        : student != null
                            ? student['name'] as String?
                            : 'Unknown';
                    
                    // Get branch for display
                    String? branch;
                    if (student != null) {
                      branch = student['branch'] as String?;
                    }
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: const Color(0xFF1D1A18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF262220), width: 1.2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName ?? 'Unknown',
                              style: const TextStyle(
                                color: Color(0xFFF3ECE2),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (student != null && student['usn'] != null)
                              Text(
                                student['usn'],
                                style: const TextStyle(color: Color(0xFF8C857C), fontSize: 11),
                              ),
                            if (branch != null)
                              Text(
                                'Branch: $branch',
                                style: const TextStyle(color: Color(0xFF8C857C), fontSize: 11),
                              ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<ResultPosition>(
                              value: _positions[reg['id']],
                              style: const TextStyle(color: Color(0xFFF3ECE2)),
                              dropdownColor: const Color(0xFF1D1A18),
                              decoration: InputDecoration(
                                labelText: 'Position (${_positions[reg['id']]?.points ?? 0} pts)',
                                labelStyle: const TextStyle(color: Color(0xFF8C857C)),
                                enabledBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF262220)),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFFF6A2C)),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                              ),
                              items: ResultPosition.values.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Text('${p.label} (+${p.points} pts)'),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _positions[reg['id']] = v),
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
