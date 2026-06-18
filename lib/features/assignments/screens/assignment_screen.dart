import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../auth/providers/auth_provider.dart';

class AssignmentScreen extends ConsumerStatefulWidget {
  final Event? initialEvent;
  const AssignmentScreen({super.key, this.initialEvent});
  @override
  ConsumerState<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends ConsumerState<AssignmentScreen> {
  Event? _selectedEvent;
  List<Event> _events = [];
  List<EventAssignment> _assignments = [];
  List<Profile> _users = [];
  bool _loading = false;
  String _searchQuery = '';

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final eventData = await SupabaseConfig.client.from(SupabaseTables.events).select().order('title');
    final userData = await SupabaseConfig.client.from(SupabaseTables.profiles).select().eq('is_active', true);
    setState(() {
      _events = (eventData as List).map((e) => Event.fromJson(e)).toList();
      _users = (userData as List).map((u) => Profile.fromJson(u)).toList();
      if (widget.initialEvent != null) {
        _selectedEvent = _events.firstWhere(
          (e) => e.id == widget.initialEvent!.id,
          orElse: () => widget.initialEvent!,
        );
        _loadAssignments(_selectedEvent!.id);
      }
    });
  }

  Future<void> _loadAssignments(String eventId) async {
    setState(() => _loading = true);
    final data = await SupabaseConfig.client.from(SupabaseTables.eventAssignments).select().eq('event_id', eventId);
    setState(() { _assignments = (data as List).map((a) => EventAssignment.fromJson(a)).toList(); _loading = false; });
  }

  Future<void> _assign(String userId, AssignmentRole role) async {
    if (_selectedEvent == null) return;
    final profile = ref.read(currentProfileProvider);
    try {
      await SupabaseConfig.client.from(SupabaseTables.eventAssignments).insert({
        'event_id': _selectedEvent!.id, 'user_id': userId,
        'assignment_role': role.value, 'assigned_by': profile!.id,
      });
      _loadAssignments(_selectedEvent!.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assigned'), backgroundColor: LitColors.moss));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: LitColors.coral));
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    final profile = ref.watch(currentProfileProvider);
    final isAuthorized = role.canAssignMembers || profile?.year == 4;

    final filteredUsers = _users.where((u) {
      final query = _searchQuery.toLowerCase();
      return u.fullName.toLowerCase().contains(query) ||
          u.role.label.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Event Assignments', style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16, color: LitColors.bone)),
      ),
      body: Column(
        children: [
          // Select Event dropdown card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClayCard(
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
                      value: _selectedEvent,
                      dropdownColor: LitColors.clay,
                      decoration: const InputDecoration(border: InputBorder.none),
                      items: _events.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 13)))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedEvent = v);
                        if (v != null) _loadAssignments(v.id);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (_selectedEvent != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ClayTextField(
                hintText: 'Search members...',
                prefixIcon: const Icon(Icons.search),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            
          Expanded(
            child: _selectedEvent == null
                ? Center(child: Text('Select an event to view and manage assignments.', style: GoogleFonts.plusJakartaSans(color: LitColors.ash)))
                : _loading
                    ? const LoadingView()
                    : filteredUsers.isEmpty
                        ? Center(child: Text('No members found.', style: GoogleFonts.plusJakartaSans(color: LitColors.ash)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredUsers.length,
                            itemBuilder: (ctx, i) {
                              final user = filteredUsers[i];
                              final userAssignments = _assignments
                                  .where((a) => a.userId == user.id)
                                  .toList();

                              return ClayCard(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    UserAvatar(name: user.fullName),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.fullName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: LitColors.bone,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                user.role.label,
                                                style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 11),
                                              ),
                                              if (userAssignments.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                const StatusChip(label: 'Assigned'),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isAuthorized)
                                      ClayButton(
                                        width: 84,
                                        height: 36,
                                        borderRadius: 10,
                                        isDanger: userAssignments.isNotEmpty,
                                        isGhost: userAssignments.isEmpty,
                                        onPressed: userAssignments.isNotEmpty
                                            ? () async {
                                                for (final a in userAssignments) {
                                                  await SupabaseConfig.client
                                                      .from(SupabaseTables.eventAssignments)
                                                      .delete()
                                                      .eq('id', a.id);
                                                }
                                                _loadAssignments(_selectedEvent!.id);
                                              }
                                            : () => _assign(user.id, AssignmentRole.volunteer),
                                        child: Text(
                                          userAssignments.isNotEmpty ? 'Unassign' : 'Assign',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
