import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class TeamRegistrationScreen extends ConsumerStatefulWidget {
  const TeamRegistrationScreen({super.key});
  @override
  ConsumerState<TeamRegistrationScreen> createState() =>
      _TeamRegistrationScreenState();
}

class _TeamRegistrationScreenState
    extends ConsumerState<TeamRegistrationScreen> {
  final _teamNameCtrl = TextEditingController();
  final _usnCtrl = TextEditingController();
  Event? _selectedEvent;
  List<Event> _events = [];
  final List<Student> _members = [];
  Student? _captain;
  bool _saving = false;

  final List<String> _branches = [
    'CSE', 'ISE', 'CI', 'CB', 'RI', 'ECE', 'VL', 'EI', 'EE', 'CV', 'ME'
  ];

  static const _branchDisplayNames = {
    'CSE': 'Computer Science',
    'ISE': 'Information Science',
    'CI': 'Artificial Intelligence and Machine Learning',
    'CB': 'Computer Science and Business Studies',
    'RI': 'Robotics & Intelligence',
    'ECE': 'Electronics & Communication',
    'VL': 'VLSI',
    'EI': 'Electronics & Instrumentation',
    'EE': 'Electrical & Electronics',
    'CV': 'Civil',
    'ME': 'Mechanical',
  };

  @override
  void initState() {
    super.initState();
    _loadTeamEvents();
  }

  Future<void> _loadTeamEvents() async {
    final data = await SupabaseConfig.client
        .from(SupabaseTables.events)
        .select()
        .eq('is_team_event', true)
        .inFilter('status', ['registration_open', 'ongoing']).order('title');
    setState(
        () => _events = (data as List).map((e) => Event.fromJson(e)).toList());
  }

  Future<void> _addMember() async {
    final usn = _usnCtrl.text.trim().toUpperCase();
    if (usn.isEmpty) return;
    try {
      final data = await SupabaseConfig.client
          .from(SupabaseTables.studentMaster)
          .select()
          .ilike('usn', usn)
          .eq('status', 'active')
          .maybeSingle();
      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Student not found'),
              backgroundColor: LitColors.amber));
        }
        return;
      }
      final student = Student.fromJson(data);
      if (_members.any((m) => m.id == student.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Already added'), backgroundColor: LitColors.amber));
        }
        return;
      }

      // Check branch participation constraint
      final constraintsSummary = ref.read(eventConstraintsSummaryProvider(_selectedEvent!.id)).value ?? [];
      final constraint = constraintsSummary.firstWhere(
        (c) => c['branch'] == student.branch,
        orElse: () => {},
      );
      if (constraint.isNotEmpty) {
        final int maxParticipants = constraint['max'] as int;
        final int currentParticipants = constraint['current'] as int;
        final int pendingCount = _members.where((m) => m.branch == student.branch).length;
        
        if (currentParticipants + pendingCount + 1 > maxParticipants) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Limit exceeded! Only $maxParticipants participants from ${student.branch} are allowed for this event.'),
                backgroundColor: LitColors.coral,
              ),
            );
          }
          return;
        }
      }
      setState(() {
        _members.add(student);
        _captain ??= student;
        if (_members.length == 1 && _teamNameCtrl.text.isEmpty) {
          _teamNameCtrl.text = _branchDisplayNames[student.branch] ?? student.branch;
        }
        _usnCtrl.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: LitColors.coral));
      }
    }
  }

  Future<void> _saveTeam() async {
    if (_selectedEvent == null ||
        _teamNameCtrl.text.isEmpty ||
        _members.isEmpty) {
      return;
    }

    // Final safety check for branch participation constraints
    final constraintsSummary = ref.read(eventConstraintsSummaryProvider(_selectedEvent!.id)).value ?? [];
    for (final c in constraintsSummary) {
      final branch = c['branch'] as String;
      final maxVal = c['max'] as int;
      final current = c['current'] as int;
      
      final toRegisterCount = _members.where((m) => m.branch == branch).length;
      if (current + toRegisterCount > maxVal) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Branch limit reached: $branch has reached the maximum of $maxVal participants for this event.'),
              backgroundColor: LitColors.coral,
            ),
          );
        }
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final profile = ref.read(currentProfileProvider);
      final teamData = await SupabaseConfig.client
          .from(SupabaseTables.teams)
          .insert({
            'event_id': _selectedEvent!.id,
            'team_name': _teamNameCtrl.text.trim(),
            'captain_id': _captain?.id,
            'registered_by': profile!.id,
          })
          .select()
          .single();

      for (final member in _members) {
        await SupabaseConfig.client.from(SupabaseTables.teamMembers).insert({
          'team_id': teamData['id'],
          'student_id': member.id,
          'is_captain': member.id == _captain?.id,
        });
        final regData = await SupabaseConfig.client.from(SupabaseTables.registrations).insert({
          'event_id': _selectedEvent!.id,
          'student_id': member.id,
          'team_id': teamData['id'],
          'registration_method': 'barcode',
          'registered_by': profile.id,
        }).select().single();

        // Auto mark attendance
        await SupabaseConfig.client.from(SupabaseTables.attendance).insert({
          'event_id': _selectedEvent!.id,
          'registration_id': regData['id'],
          'student_id': member.id,
          'marked_by': profile.id,
          'method': 'barcode',
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Team "${_teamNameCtrl.text}" registered with ${_members.length} members'),
            backgroundColor: LitColors.moss));
        
        // Invalidate branch constraints summary
        ref.invalidate(eventConstraintsSummaryProvider(_selectedEvent!.id));

        setState(() {
          _members.clear();
          _teamNameCtrl.clear();
          _captain = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: LitColors.coral));
      }
    }
    setState(() => _saving = false);
  }

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    _usnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Team Registration', style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16, color: LitColors.bone)),
      ),
      body: ListView(
        padding: context.r.pageInsets,
        children: [
          // Event Dropdown Card
          ClayCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Event',
                  style: GoogleFonts.fredoka(fontSize: 13.5, fontWeight: FontWeight.bold, color: LitColors.bone),
                ),
                const SizedBox(height: 10),
                ClayInsetCard(
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<Event>(
                    initialValue: _selectedEvent,
                    dropdownColor: LitColors.clay,
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: _events
                        .map((e) => DropdownMenuItem(
                            value: e, child: Text('${e.name} (Size: ${e.teamSize})', style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedEvent = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Team Name Dropdown Field
          ClayCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Team Details',
                  style: GoogleFonts.fredoka(fontSize: 13.5, fontWeight: FontWeight.bold, color: LitColors.bone),
                ),
                const SizedBox(height: 10),
                ClayInsetCard(
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _teamNameCtrl.text.isEmpty ? null : _teamNameCtrl.text,
                    dropdownColor: LitColors.clay,
                    decoration: const InputDecoration(border: InputBorder.none),
                    hint: Text('Select Department (Team Name)', style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 13)),
                    items: _branches
                        .map((b) => DropdownMenuItem(
                            value: _branchDisplayNames[b] ?? b, 
                            child: Text(
                              _branchDisplayNames[b] ?? b, 
                              style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            )))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _teamNameCtrl.text = v;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Add Member Search Card
          ClayCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Member',
                  style: GoogleFonts.fredoka(fontSize: 13.5, fontWeight: FontWeight.bold, color: LitColors.bone),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClayTextField(
                        controller: _usnCtrl,
                        hintText: 'Student USN',
                        prefixIcon: const Icon(Icons.person_add_alt_1_outlined),
                        onChanged: (val) {
                          if (val.trim().length >= 10) {
                            _addMember();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClayButton(
                      width: 50,
                      height: 48,
                      isGhost: true,
                      padding: EdgeInsets.zero,
                      onPressed: _addMember,
                      child: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Members list section
          if (_members.isNotEmpty) ...[
            Text(
              'Members (${_members.length})',
              style: GoogleFonts.fredoka(fontSize: 15, fontWeight: FontWeight.w600, color: LitColors.bone),
            ),
            const SizedBox(height: 10),
            ..._members.map((m) => ClayCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(name: m.name),
                    title: Text(
                      m.name,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: LitColors.bone, fontSize: 13.5),
                    ),
                    subtitle: Text(
                      m.usn,
                      style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 11.5),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_captain?.id == m.id)
                          const StatusChip(label: 'Captain'),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: LitColors.coral, size: 20),
                          onPressed: () => setState(() {
                            _members.remove(m);
                            if (_captain?.id == m.id) {
                              _captain = _members.isNotEmpty ? _members.first : null;
                            }
                          }),
                        ),
                      ],
                    ),
                    onTap: () => setState(() => _captain = m),
                  ),
                )),
            ],
            const SizedBox(height: 16),
            ClayButton(
              onPressed: _saving ? null : _saveTeam,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF1A0D05), strokeWidth: 2))
                  : const Text('Register Team'),
            ),
          ],
      ),
    );
  }
}
