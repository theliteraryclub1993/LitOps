import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/enums/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../admin/providers/admin_providers.dart';
import '../../admin/screens/points_management_screen.dart'; // for adminEventsProvider
import '../providers/scheduling_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class EventSchedulingScreen extends ConsumerStatefulWidget {
  const EventSchedulingScreen({super.key});

  @override
  ConsumerState<EventSchedulingScreen> createState() => _EventSchedulingScreenState();
}

class _EventSchedulingScreenState extends ConsumerState<EventSchedulingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Event? _focusedEvent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(adminEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Operations & Scheduling'),
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: const Color(0xFFF3ECE2),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6A2C),
          labelColor: const Color(0xFFF3ECE2),
          unselectedLabelColor: const Color(0xFF8C857C),
          tabs: const [
            Tab(text: 'Schedules', icon: Icon(Icons.calendar_month_rounded)),
            Tab(text: 'Staff Assignments', icon: Icon(Icons.assignment_ind_rounded)),
            Tab(text: 'Branch Limits', icon: Icon(Icons.rule_folder_rounded)),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const EmptyView(
              icon: Icons.event_busy_rounded,
              title: 'No events registered',
              subtitle: 'Ensure events are loaded in the database first.',
            );
          }

          // If no event is focused yet, default to the first one
          _focusedEvent ??= events.first;

          return TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Schedules list & creation
              _buildSchedulesTab(events),

              // Tab 2: Assignments for focused event
              _buildAssignmentsTab(events),

              // Tab 3: Branch constraints
              _buildConstraintsTab(events),
            ],
          );
        },
        loading: () => const LoadingView(message: 'Loading operation database...'),
        error: (e, _) => ErrorView(
          message: 'Failed to load operation database: $e',
          onRetry: () => ref.invalidate(adminEventsProvider),
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 1: SCHEDULES LIST
  // ============================================================================
  Widget _buildSchedulesTab(List<Event> events) {
    final schedulesAsync = ref.watch(eventSchedulesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showScheduleForm(context, events),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: schedulesAsync.when(
        data: (schedules) {
          if (schedules.isEmpty) {
            return const EmptyView(
              icon: Icons.date_range_rounded,
              title: 'No schedules registered',
              subtitle: 'Tap the + button to configure dates and venues.',
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final schedule = schedules[index];
              return _buildScheduleCard(schedule, events);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading schedules: $e', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(EventSchedule schedule, List<Event> events) {
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(schedule.scheduleDate);
    final isParallel = schedule.isParallel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        schedule.eventName ?? 'Unknown Event',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isParallel) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PARALLEL',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFF59E0B),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(schedule.venue, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time_rounded, color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${schedule.startTime.substring(0, 5)} - ${schedule.endTime.substring(0, 5)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  if (schedule.coordinatorName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Coordinator: ${schedule.coordinatorName}',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF90CAF9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white54),
                  onPressed: () => _showScheduleForm(context, events, schedule: schedule),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => _confirmDeleteSchedule(schedule.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSchedule(String id) {
    ConfirmDialog.show(
      context,
      title: 'Remove Event Schedule',
      message: 'Are you sure you want to cancel and delete this schedule slot?',
      confirmText: 'Remove',
      confirmColor: Colors.redAccent,
      onConfirm: () async {
        try {
          await ref.read(schedulingControllerProvider).deleteEventSchedule(id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule removed successfully')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete schedule: $e')),
          );
        }
      },
    );
  }

  void _showScheduleForm(BuildContext context, List<Event> events, {EventSchedule? schedule}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131324),
          title: Text(
            schedule != null ? 'Edit Schedule Slot' : 'Create Schedule Slot',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: _ScheduleForm(events: events, schedule: schedule),
          ),
        );
      },
    );
  }

  // ============================================================================
  // TAB 2: STAFF ASSIGNMENTS
  // ============================================================================
  Widget _buildAssignmentsTab(List<Event> events) {
    final role = ref.watch(currentUserRoleProvider);
    final profile = ref.watch(currentProfileProvider);
    final isAuthorized = role.canAssignMembers || profile?.year == 4;

    final assignmentsAsync = ref.watch(eventAssignmentsProvider(_focusedEvent!.id));
    final membersAsync = ref.watch(memberListProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Event Picker
          _buildFocusedEventHeader(events),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assigned Crew members',
                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
              if (isAuthorized)
                membersAsync.when(
                  data: (members) => TextButton.icon(
                    onPressed: () => _showAddAssignmentDialog(members),
                    icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981), size: 16),
                    label: const Text('Assign Crew', style: TextStyle(color: Color(0xFF10B981))),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Crew List
          Expanded(
            child: assignmentsAsync.when(
              data: (assignments) {
                if (assignments.isEmpty) {
                  return const EmptyView(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'No staff assigned yet',
                    subtitle: 'Coordinators and volunteer handlers will appear here.',
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: assignments.length,
                  itemBuilder: (context, index) {
                    final ass = assignments[index];
                    final memberProfile = ass['profiles'] as Map<String, dynamic>?;
                    final roleVal = ass['assignment_role'] as String? ?? 'volunteer';
                    final assignmentRole = AssignmentRole.fromString(roleVal);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(name: memberProfile?['full_name'] ?? '?', radius: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  memberProfile?['full_name'] ?? 'Unknown Member',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  assignmentRole.label,
                                  style: const TextStyle(color: Color(0xFF90CAF9), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (isAuthorized)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _removeAssignment(ass['id']),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAssignmentDialog(List<ClubMember> members) {
    ClubMember? selectedMember;
    AssignmentRole selectedRole = AssignmentRole.volunteer;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131324),
          title: Text(
            'Assign Event Staff',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Member', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ClubMember>(
                        value: selectedMember,
                        dropdownColor: const Color(0xFF131324),
                        isExpanded: true,
                        hint: const Text('Choose Member', style: TextStyle(color: Colors.white30)),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedMember = val;
                          });
                        },
                        items: members.map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(m.memberName ?? 'Unknown'),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Assign Role', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AssignmentRole>(
                        value: selectedRole,
                        dropdownColor: const Color(0xFF131324),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedRole = val;
                            });
                          }
                        },
                        items: AssignmentRole.values.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text(r.label),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedMember == null) return;
                Navigator.pop(context);
                try {
                  final curUser = ref.read(currentProfileProvider);
                  await ref.read(schedulingControllerProvider).assignMember(
                        eventId: _focusedEvent!.id,
                        userId: selectedMember!.userId,
                        role: selectedRole,
                        assignedBy: curUser?.id ?? '',
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Staff assigned successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Assignment failed: $e')),
                  );
                }
              },
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeAssignment(String assignmentId) async {
    try {
      await ref.read(schedulingControllerProvider).removeAssignment(assignmentId, _focusedEvent!.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removal failed: $e')),
      );
    }
  }

  // ============================================================================
  // TAB 3: BRANCH CONSTRAINTS
  // ============================================================================
  Widget _buildConstraintsTab(List<Event> events) {
    final constraintsAsync = ref.watch(eventConstraintsProvider(_focusedEvent!.id));
    final List<String> branches = ['CS', 'IS', 'CI', 'CB', 'RI', 'EC', 'VL', 'EI', 'EE', 'CV', 'ME'];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFocusedEventHeader(events),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Branch Participation Limits',
                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () => _showAddConstraintDialog(branches),
                icon: const Icon(Icons.add_moderator_rounded, color: Color(0xFF10B981), size: 16),
                label: const Text('Add Rule', style: TextStyle(color: Color(0xFF10B981))),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: constraintsAsync.when(
              data: (constraints) {
                if (constraints.isEmpty) {
                  return const EmptyView(
                    icon: Icons.rule_rounded,
                    title: 'No branch constraints set',
                    subtitle: 'Registrations are currently unrestricted by department limits.',
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: constraints.length,
                  itemBuilder: (context, index) {
                    final c = constraints[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  c.branch,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFF59E0B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Max Limit: ${c.maxParticipants}',
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _deleteConstraint(c.id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddConstraintDialog(List<String> branches) {
    String selectedBranch = branches.first;
    final limitCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131324),
          title: Text(
            'Add Branch Limit',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Branch', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedBranch,
                    dropdownColor: const Color(0xFF131324),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) {
                      if (val != null) selectedBranch = val;
                    },
                    items: branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Maximum Participants limit', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. 15',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final limit = int.tryParse(limitCtrl.text);
                if (limit == null || limit <= 0) return;
                Navigator.pop(context);

                try {
                  await ref.read(schedulingControllerProvider).saveParticipationConstraint(
                        eventId: _focusedEvent!.id,
                        branch: selectedBranch,
                        maxParticipants: limit,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Branch limit saved successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save rule: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteConstraint(String id) async {
    try {
      await ref.read(schedulingControllerProvider).deleteParticipationConstraint(id, _focusedEvent!.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch limit deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  // ============================================================================
  // FOCUS HEADER
  // ============================================================================
  Widget _buildFocusedEventHeader(List<Event> events) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Managing Configurations For:',
                  style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _focusedEvent!.name,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showFocusedEventPicker(events),
            child: const Text('Switch Event', style: TextStyle(color: Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  void _showFocusedEventPicker(List<Event> events) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131324),
          title: const Text('Choose Focused Event', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: events.length,
              itemBuilder: (context, index) {
                final e = events[index];
                return ListTile(
                  onTap: () {
                    setState(() {
                      _focusedEvent = e;
                    });
                    Navigator.pop(context);
                  },
                  title: Text(e.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(e.category.label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  trailing: _focusedEvent!.id == e.id
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1))
                      : null,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// Form sheet to capture details of schedules
class _ScheduleForm extends ConsumerStatefulWidget {
  final List<Event> events;
  final EventSchedule? schedule;

  const _ScheduleForm({required this.events, this.schedule});

  @override
  ConsumerState<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends ConsumerState<_ScheduleForm> {
  final _formKey = GlobalKey<FormState>();
  
  late Event _selectedEvent;
  late DateTime _selectedDate;
  final _startTimeCtrl = TextEditingController();
  final _endTimeCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  bool _isParallel = false;
  final _parallelGroupCtrl = TextEditingController();
  final _volunteersCtrl = TextEditingController();
  ClubMember? _selectedCoordinator;
  final _notesCtrl = TextEditingController();
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.schedule != null) {
      final s = widget.schedule!;
      _selectedEvent = widget.events.firstWhere((e) => e.id == s.eventId, orElse: () => widget.events.first);
      _selectedDate = s.scheduleDate;
      _startTimeCtrl.text = s.startTime.substring(0, 5);
      _endTimeCtrl.text = s.endTime.substring(0, 5);
      _venueCtrl.text = s.venue;
      _isParallel = s.isParallel;
      _parallelGroupCtrl.text = s.parallelGroup ?? '';
      _volunteersCtrl.text = s.volunteerCount.toString();
      _notesCtrl.text = s.notes ?? '';
    } else {
      _selectedEvent = widget.events.first;
      _selectedDate = DateTime.now();
      _startTimeCtrl.text = '09:00';
      _endTimeCtrl.text = '11:00';
      _volunteersCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _venueCtrl.dispose();
    _parallelGroupCtrl.dispose();
    _volunteersCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(memberListProvider);

    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          // Event
          const Text('Event', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Event>(
                value: _selectedEvent,
                dropdownColor: const Color(0xFF131324),
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedEvent = val);
                },
                items: widget.events.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Date Picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                style: const TextStyle(color: Colors.white),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: const Text('Change Date', style: TextStyle(color: Color(0xFF6366F1))),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Start & End Time
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Time', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _startTimeCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'HH:MM',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('End Time', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _endTimeCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'HH:MM',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Venue
          const Text('Venue', style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _venueCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Auditorium, Seminar Hall',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter venue' : null,
          ),
          const SizedBox(height: 12),

          // Coordinator
          const Text('Event Coordinator', style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 6),
          membersAsync.when(
            data: (members) {
              // Try to resolve current selection
              if (widget.schedule?.coordinatorId != null && _selectedCoordinator == null) {
                _selectedCoordinator = members.firstWhere(
                  (m) => m.userId == widget.schedule!.coordinatorId,
                  orElse: () => members.first,
                );
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ClubMember?>(
                    value: _selectedCoordinator,
                    dropdownColor: const Color(0xFF131324),
                    isExpanded: true,
                    hint: const Text('Select coordinator (Optional)', style: TextStyle(color: Colors.white30)),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) {
                      setState(() {
                        _selectedCoordinator = val;
                      });
                    },
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...members.map((m) => DropdownMenuItem(value: m, child: Text(m.memberName ?? 'Unknown'))),
                    ],
                  ),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 12),

          // Volunteer count
          const Text('Required Volunteer Count', style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _volunteersCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          const SizedBox(height: 12),

          // Parallel Scheduling Toggle
          SwitchListTile(
            title: const Text('Parallel Event Scheduling', style: TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: const Text('Bypasses automated venue booking conflicts', style: TextStyle(color: Colors.white38, fontSize: 11)),
            value: _isParallel,
            activeThumbColor: const Color(0xFF6366F1),
            onChanged: (val) {
              setState(() {
                _isParallel = val;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          if (_isParallel) ...[
            const SizedBox(height: 12),
            const Text('Parallel Group Name', style: TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _parallelGroupCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Group A',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Notes
          const Text('Scheduling Notes', style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _notesCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // Save Button
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _isSaving = true);
                    
                    try {
                      final curUser = ref.read(currentProfileProvider);
                      final createdBy = curUser?.id ?? '';

                      await ref.read(schedulingControllerProvider).saveEventSchedule(
                            id: widget.schedule?.id,
                            eventId: _selectedEvent.id,
                            scheduleDate: _selectedDate,
                            startTime: '${_startTimeCtrl.text}:00',
                            endTime: '${_endTimeCtrl.text}:00',
                            venue: _venueCtrl.text.trim(),
                            isParallel: _isParallel,
                            parallelGroup: _isParallel ? _parallelGroupCtrl.text.trim() : null,
                            volunteerCount: int.tryParse(_volunteersCtrl.text) ?? 0,
                            coordinatorId: _selectedCoordinator?.userId,
                            notes: _notesCtrl.text.trim(),
                            createdBy: createdBy,
                          );

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Schedule slot saved successfully')),
                      );
                    } catch (e) {
                      setState(() => _isSaving = false);
                      String errMessage = e.toString();
                      if (errMessage.contains('Venue conflict detected')) {
                        _showConflictDialog(errMessage.replaceAll('Exception: ', ''));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save schedule: $e')),
                        );
                      }
                    }
                  },
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Slot'),
          ),
        ],
      ),
    );
  }

  void _showConflictDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131324),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text('Venue Conflict', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Acknowledge', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }
}
