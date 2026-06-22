import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/top_notification.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/theme/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../events/screens/event_detail_screen.dart';
import '../../events/screens/events_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../attendance/screens/attendance_screen.dart';

final activeEventsProvider = FutureProvider<List<Event>>((ref) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.events)
      .select()
      .inFilter('status', ['registration_open', 'ongoing'])
      .order('created_at', ascending: false);
  return (data as List).map((e) => Event.fromJson(e)).toList();
});

class RegistrationScreen extends ConsumerStatefulWidget {
  final Event? initialEvent;
  const RegistrationScreen({super.key, this.initialEvent});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Active state
  Event? _selectedEvent;
  List<Event> _events = [];
  bool _loadingEvents = false;
  bool _saving = false;
  bool _searchingStudent = false;
  bool _scanEnabled = true;

  // Form fields
  final _formKey = GlobalKey<FormState>();
  final _usnController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  String _branch = 'CS';
  int _year = 1;
  String _section = 'A';

  final List<String> _branches = [
    'CS', 'IS', 'CI', 'CB', 'RI', 'EC', 'VL', 'EI', 'EE', 'CV', 'ME'
  ];

  // Team registration variables
  final _teamNameController = TextEditingController();
  List<Student?> _participants = [];
  int _activeSlotIndex = 0;
  bool _isNewStudent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedEvent = widget.initialEvent;
    _initializeSlots();
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usnController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _teamNameController.dispose();
    super.dispose();
  }

  void _initializeSlots() {
    if (_selectedEvent == null) {
      _participants = [];
      _activeSlotIndex = 0;
    } else {
      int size = _selectedEvent!.isTeamEvent ? _selectedEvent!.teamSize : 1;
      _participants = List.filled(size, null);
      _activeSlotIndex = 0;
    }
    _clearStudentForm();
  }

  void _clearStudentForm() {
    _usnController.clear();
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    setState(() {
      _branch = 'CS';
      _year = 1;
      _section = 'A';
      _isNewStudent = false;
    });
  }

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final data = await SupabaseConfig.client
          .from(SupabaseTables.events)
          .select()
          .inFilter('status', ['registration_open', 'ongoing'])
          .order('title');
      
      setState(() {
        _events = (data as List).map((e) => Event.fromJson(e)).toList();
        if (_selectedEvent != null) {
          _selectedEvent = _events.firstWhere((e) => e.id == _selectedEvent!.id, orElse: () => _selectedEvent!);
          _initializeSlots();
        }
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
    } finally {
      setState(() => _loadingEvents = false);
    }
  }

  // Lookup student details by USN in the master list
  Future<void> _searchStudent(String usn) async {
    if (usn.trim().isEmpty) return;
    
    setState(() {
      _searchingStudent = true;
      _scanEnabled = false;
    });

    final searchUsn = usn.trim().toUpperCase();

    try {
      // First try student_master
      final studentData = await SupabaseConfig.client
          .from(SupabaseTables.studentMaster)
          .select()
          .ilike('usn', searchUsn)
          .eq('status', 'active')
          .maybeSingle();

      Student? student;
      if (studentData != null) {
        student = Student.fromJson(studentData);
      } else {
        // Try profiles table for club members
        final profileData = await SupabaseConfig.client
            .from(SupabaseTables.profiles)
            .select()
            .ilike('usn', searchUsn)
            .maybeSingle();
        
        if (profileData != null) {
          final profile = Profile.fromJson(profileData);
          // Try to insert, if duplicate key exists, just fetch existing student
          try {
            final studentInsertData = <String, dynamic>{
              'usn': profile.usn ?? searchUsn,
              'name': profile.fullName,
              'branch': profile.branch ?? 'CS',
              'year': profile.year ?? 1,
              'phone': profile.phone,
              'email': profile.email,
              'status': 'active',
            };
            final newStudentRows = await SupabaseConfig.client
                .from(SupabaseTables.studentMaster)
                .insert(studentInsertData)
                .select();
            if (newStudentRows.isNotEmpty) {
              student = Student.fromJson(newStudentRows[0]);
            }
          } catch (e) {
            // Duplicate key error, fetch the existing student
            final existingStudentData = await SupabaseConfig.client
                .from(SupabaseTables.studentMaster)
                .select()
                .ilike('usn', searchUsn)
                .eq('status', 'active')
                .maybeSingle();
            if (existingStudentData != null) {
              student = Student.fromJson(existingStudentData);
            }
          }
        }
      }
          
      if (student != null) {
        // Check if student is already added in another slot for this team
        if (_participants.any((p) => p?.id == student!.id)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Student already added to the participant list'),
                backgroundColor: LitColors.amber,
              ),
            );
          }
          _clearStudentForm();
        } else {
          // Pre-fill the form with existing student details
          _usnController.text = student!.usn;
          _nameController.text = student!.name;
          _phoneController.text = student!.phone ?? '';
          _emailController.text = student!.email ?? '';
          setState(() {
            _branch = _branches.contains(student!.branch.toUpperCase()) ? student!.branch.toUpperCase() : _branches.first;
            _year = student!.year;
            _section = student!.section ?? 'A';
            _isNewStudent = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Found student: ${student!.name}. Details auto-filled!'),
                backgroundColor: LitColors.moss,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // If not found, pre-fill USN and let user enter other details manually
        _clearStudentForm();
        _usnController.text = searchUsn;
        setState(() {
          _isNewStudent = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student not found in database. Please enter details manually.'),
              backgroundColor: LitColors.amber,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e'), backgroundColor: LitColors.coral),
        );
      }
    } finally {
      setState(() {
        _searchingStudent = false;
        _scanEnabled = true;
      });
    }
  }

  // Save/Update student in StudentMaster and return the Student object
  Future<Student?> _upsertStudent() async {
    final name = _nameController.text.trim();
    final usn = _usnController.text.trim().toUpperCase();
    
    if (name.isEmpty || usn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and USN are required fields'), backgroundColor: LitColors.coral),
      );
      return null;
    }

    try {
      final existing = await SupabaseConfig.client
          .from(SupabaseTables.studentMaster)
          .select()
          .ilike('usn', usn)
          .maybeSingle();

      final studentData = {
        'usn': usn,
        'name': name,
        'branch': _branch,
        'year': _year,
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'status': 'active',
      };

      if (existing != null) {
        final updated = await SupabaseConfig.client
            .from(SupabaseTables.studentMaster)
            .update(studentData)
            .eq('id', existing['id'])
            .select()
            .single();
        return Student.fromJson(updated);
      } else {
        final inserted = await SupabaseConfig.client
            .from(SupabaseTables.studentMaster)
            .insert(studentData)
            .select()
            .single();
        return Student.fromJson(inserted);
      }
    } catch (e) {
      debugPrint('Error upserting student: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save student details: $e'), backgroundColor: LitColors.coral),
        );
      }
      return null;
    }
  }

  // Lock a participant into the selected team slot
  Future<void> _confirmParticipantForSlot() async {
    if (_selectedEvent == null) return;
    
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final student = await _upsertStudent();
    setState(() => _saving = false);

    if (student == null) return;

    setState(() {
      _participants[_activeSlotIndex] = student;
      _clearStudentForm();
      
      if (_activeSlotIndex == 0 && _teamNameController.text.trim().isEmpty) {
        _teamNameController.text = student.branch;
      }

      _moveToNextEmptySlot();
    });
  }

  void _moveToNextEmptySlot() {
    for (int i = 0; i < _participants.length; i++) {
      if (_participants[i] == null) {
        setState(() {
          _activeSlotIndex = i;
        });
        return;
      }
    }
    setState(() {
      _activeSlotIndex = _participants.length;
    });
  }

  void _removeParticipantFromSlot(int index) {
    setState(() {
      _participants[index] = null;
      if (_activeSlotIndex > index || _activeSlotIndex == _participants.length) {
        _activeSlotIndex = index;
      }
    });
  }

  // Final submit registration to DB
  Future<void> _submitRegistration() async {
    if (_selectedEvent == null) return;

    if (_selectedEvent!.isTeamEvent) {
      if (_participants.any((p) => p == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all team member slots before registering'), backgroundColor: LitColors.amber),
        );
        return;
      }
      if (_teamNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a team name'), backgroundColor: LitColors.amber),
        );
        return;
      }

      // Check if any team member is already registered for this event
      for (final student in _participants) {
        if (student != null) {
          final duplicate = await SupabaseConfig.client
              .from(SupabaseTables.registrations)
              .select('id')
              .eq('event_id', _selectedEvent!.id)
              .eq('student_id', student.id)
              .eq('is_cancelled', false)
              .maybeSingle();

          if (duplicate != null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${student.name} is already registered for this event!'), backgroundColor: LitColors.amber),
              );
            }
            setState(() => _saving = false);
            return;
          }
        }
      }
    } else {
      if (_participants.isEmpty || _participants[0] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill participant details'), backgroundColor: LitColors.amber),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final profile = ref.read(currentProfileProvider);
      final userId = profile!.id;
      final method = _tabController.index == 0 ? 'barcode' : 'manual';

      if (!_selectedEvent!.isTeamEvent) {
        final student = _participants[0]!;

        final duplicate = await SupabaseConfig.client
            .from(SupabaseTables.registrations)
            .select('id')
            .eq('event_id', _selectedEvent!.id)
            .eq('student_id', student.id)
            .eq('is_cancelled', false)
            .maybeSingle();

        if (duplicate != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Student is already registered for this event'), backgroundColor: LitColors.amber),
            );
          }
          setState(() => _saving = false);
          return;
        }

        // Insert registration
        final regData = await SupabaseConfig.client.from(SupabaseTables.registrations).insert({
          'event_id': _selectedEvent!.id,
          'student_id': student.id,
          'registration_method': method,
          'registered_by': userId,
        }).select().single();

        // Auto mark attendance
        final existingAttendance = await SupabaseConfig.client
            .from(SupabaseTables.attendance)
            .select('id')
            .eq('event_id', _selectedEvent!.id)
            .eq('registration_id', regData['id'])
            .maybeSingle();

        if (existingAttendance == null) {
          await SupabaseConfig.client.from(SupabaseTables.attendance).insert({
            'event_id': _selectedEvent!.id,
            'registration_id': regData['id'],
            'student_id': student.id,
            'marked_by': userId,
          });
        }

        if (mounted) {
          showTopNotification(context, 'Successfully registered ${student.name} for ${_selectedEvent!.name}!', type: NotificationType.success);
        }
      } else {
        final teamName = _teamNameController.text.trim();
        final captain = _participants[0]!;

        final teamData = await SupabaseConfig.client
            .from(SupabaseTables.teams)
            .insert({
              'event_id': _selectedEvent!.id,
              'team_name': teamName,
              'captain_id': captain.id,
              'registered_by': userId,
            })
            .select()
            .single();

        final teamId = teamData['id'];

        for (int i = 0; i < _participants.length; i++) {
          final student = _participants[i]!;
          final isCaptain = (i == 0);

          // First, check if team member already exists (shouldn't, but just in case)
          final existingTeamMember = await SupabaseConfig.client
              .from(SupabaseTables.teamMembers)
              .select('id')
              .eq('team_id', teamId)
              .eq('student_id', student.id)
              .maybeSingle();

          if (existingTeamMember == null) {
            await SupabaseConfig.client.from(SupabaseTables.teamMembers).insert({
              'team_id': teamId,
              'student_id': student.id,
              'is_captain': isCaptain,
            });
          }

          final duplicate = await SupabaseConfig.client
              .from(SupabaseTables.registrations)
              .select('id')
              .eq('event_id', _selectedEvent!.id)
              .eq('student_id', student.id)
              .eq('is_cancelled', false)
              .maybeSingle();

          String regId;
          if (duplicate == null) {
            final regData = await SupabaseConfig.client.from(SupabaseTables.registrations).insert({
              'event_id': _selectedEvent!.id,
              'student_id': student.id,
              'team_id': teamId,
              'registration_method': method,
              'registered_by': userId,
            }).select().single();
            regId = regData['id'];
          } else {
            regId = duplicate['id'];
          }

          // Auto mark attendance
          final existingAttendance = await SupabaseConfig.client
              .from(SupabaseTables.attendance)
              .select('id')
              .eq('event_id', _selectedEvent!.id)
              .eq('registration_id', regId)
              .maybeSingle();

          if (existingAttendance == null) {
            await SupabaseConfig.client.from(SupabaseTables.attendance).insert({
              'event_id': _selectedEvent!.id,
              'registration_id': regId,
              'student_id': student.id,
              'marked_by': userId,
            });
          }
        }

        if (mounted) {
          showTopNotification(context, 'Successfully registered team "$teamName" for ${_selectedEvent!.name}!', type: NotificationType.success);
        }
      }

      ref.invalidate(eventRegistrationsCountProvider(_selectedEvent!.id));
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(eventConstraintsSummaryProvider(_selectedEvent!.id));
      ref.invalidate(eventsListProvider);
      ref.invalidate(eventAttendanceProvider(_selectedEvent!.id));
      ref.invalidate(activeEventsProvider);
      
      setState(() {
        _initializeSlots();
        _teamNameController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration error: $e'), backgroundColor: LitColors.coral),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    final profile = ref.watch(currentProfileProvider);
    
    // Allow access if:
    // 1. User has canRegisterParticipants or canManualEntry
    // 2. Or user is in 1st, 2nd, 3rd, or 4th year (any year)
    final year = profile?.year;
    final isAllowed = role.canRegisterParticipants || role.canManualEntry || (year != null && year >= 1 && year <= 4);
    if (!isAllowed) {
      return const Scaffold(
        backgroundColor: LitColors.void_,
        body: EmptyView(
          icon: Icons.lock_outline,
          title: 'Access Restricted',
          subtitle: 'You do not have permissions to register participants.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Registration Center',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16, color: LitColors.bone),
        ),
      ),
      body: _loadingEvents
          ? const LoadingView(message: 'Loading active events...')
          : _events.isEmpty
              ? const EmptyView(
                  icon: Icons.event_busy_rounded,
                  title: 'No Active Events',
                  subtitle: 'There are no ongoing or registration-open events.',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 950;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 130),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEventSelectorCard(),
                          const SizedBox(height: 16),
                          if (_selectedEvent != null)
                            isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildEventDetailsSummary(),
              const SizedBox(height: 14),
              if (_selectedEvent!.isTeamEvent) _buildTeamNameCard(),
              const SizedBox(height: 14),
              _buildParticipantSlotsCard(),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              if (_activeSlotIndex < _participants.length) ...[
                _buildRegistrationFormWorkspace(),
              ] else ...[
                _buildAllSlotsFilledCard(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildEventDetailsSummary(),
        const SizedBox(height: 14),
        if (_selectedEvent!.isTeamEvent) ...[
          _buildTeamNameCard(),
          const SizedBox(height: 14),
        ],
        _buildParticipantSlotsCard(),
        const SizedBox(height: 14),
        if (_activeSlotIndex < _participants.length) ...[
          _buildRegistrationFormWorkspace(),
        ] else ...[
          _buildAllSlotsFilledCard(),
        ],
      ],
    );
  }

  Widget _buildEventSelectorCard() {
    return ClayCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Event',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: LitColors.bone,
            ),
          ),
          const SizedBox(height: 12),
          ClayInsetCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<Event>(
              value: _selectedEvent,
              dropdownColor: LitColors.clay,
              hint: Text('Choose an active event', style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 13)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              items: _events.map((e) {
                return DropdownMenuItem<Event>(
                  value: e,
                  child: Text(
                    '${e.name} (${e.isTeamEvent ? "Team Size ${e.teamSize}" : "Solo"})',
                    style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (event) {
                setState(() {
                  _selectedEvent = event;
                  _initializeSlots();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetailsSummary() {
    if (_selectedEvent == null) return const SizedBox.shrink();
    
    final categoryColor = AppTheme.getCategoryColor(_selectedEvent!.category.value);
    
    return ClayCard(
      borderColor: categoryColor.withOpacity(0.2),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedEvent!.category.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: categoryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              StatusChip(label: _selectedEvent!.status.label),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _selectedEvent!.name,
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: LitColors.bone,
            ),
          ),
          const SizedBox(height: 6),
          if (_selectedEvent!.description != null && _selectedEvent!.description!.isNotEmpty)
            Text(
              _selectedEvent!.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 11.5),
            ),
          const Divider(height: 20, color: Color(0xFF262220)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailMiniCol(Icons.location_on_outlined, 'Venue', _selectedEvent!.venue ?? 'TBA'),
              _buildDetailMiniCol(
                Icons.groups_outlined,
                'Type',
                _selectedEvent!.isTeamEvent ? 'Team (${_selectedEvent!.teamSize})' : 'Solo',
              ),
              _buildDetailMiniCol(
                Icons.people_outline,
                'Limit',
                _selectedEvent!.capacity != null ? '${_selectedEvent!.capacity}' : 'Unlimited',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMiniCol(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: LitColors.ash),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: LitColors.ash)),
            Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: LitColors.bone)),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamNameCard() {
    return ClayCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team Configuration',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: LitColors.bone,
            ),
          ),
          const SizedBox(height: 12),
          ClayTextField(
            controller: _teamNameController,
            hintText: 'Team Name (e.g. Ground Shakers)',
            prefixIcon: const Icon(Icons.people_alt_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantSlotsCard() {
    return ClayCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedEvent!.isTeamEvent ? 'Team Members Slots' : 'Participant Details',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: LitColors.bone,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _participants.length,
            itemBuilder: (context, index) {
              final student = _participants[index];
              final isActiveSlot = index == _activeSlotIndex;
              final roleName = index == 0 ? 'Captain' : 'Member ${index + 1}';
              
              return ClayCard(
                margin: const EdgeInsets.only(bottom: 8),
                color: student != null
                    ? const Color(0xFF11261B)
                    : (isActiveSlot ? const Color(0xFF2B1C15) : LitColors.clay2),
                borderColor: isActiveSlot
                    ? LitColors.ember
                    : (student != null ? LitColors.moss : null),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: student != null
                          ? LitColors.moss
                          : (isActiveSlot ? LitColors.ember : LitColors.clay3),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Color(0xFF1A0D05), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  title: Text(
                    student != null ? student.name : (isActiveSlot ? 'Awaiting Scan / Fill...' : 'Empty Slot'),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: student != null
                          ? LitColors.moss
                          : (isActiveSlot ? LitColors.ember : LitColors.ash),
                    ),
                  ),
                  subtitle: student != null 
                      ? Text('${student.usn} • ${student.branch} • ${student.year} Yr', style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 11))
                      : Text(roleName, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: LitColors.ash)),
                  trailing: student != null
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: LitColors.coral, size: 20),
                          onPressed: () => _removeParticipantFromSlot(index),
                        )
                      : null,
                  onTap: () {
                    if (student == null) {
                      setState(() {
                        _activeSlotIndex = index;
                        _clearStudentForm();
                      });
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationFormWorkspace() {
    final label = _selectedEvent!.isTeamEvent 
        ? (_activeSlotIndex == 0 ? 'Team Captain' : 'Team Member ${_activeSlotIndex + 1}')
        : 'Participant';
        
    return ClayCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: LitColors.ember.withOpacity(0.08),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: LitColors.ember, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Form for $label',
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: LitColors.ember,
                  ),
                ),
              ],
            ),
          ),
          
          // Custom Styled TabBar
          TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: const Color(0xFF262220),
            indicatorColor: LitColors.ember,
            labelColor: LitColors.ember,
            unselectedLabelColor: LitColors.ash,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.qr_code_scanner_rounded, size: 18), text: 'Barcode Scan'),
              Tab(icon: Icon(Icons.text_snippet_rounded, size: 18), text: 'Manual Input'),
            ],
            onTap: (index) {
              _clearStudentForm();
            },
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 440,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBarcodeScannerSection(),
                  _buildManualFormSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeScannerSection() {
    return Column(
      children: [
        // Camera Scanner View
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    onDetect: (capture) {
                      if (!_scanEnabled) return;
                      final barcode = capture.barcodes.first;
                      if (barcode.rawValue != null) {
                        _searchStudent(barcode.rawValue!);
                      }
                    },
                    errorBuilder: (context, error, child) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.white, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'Scanner Error',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                _getErrorMessage(error),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ClayButton(
                              width: 120,
                              height: 40,
                              onPressed: () => setState(() {}),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Dotted scan frame overlay replicating html design exactly
                  Container(
                    width: 220,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: LitColors.ember.withOpacity(0.55),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, color: LitColors.ember, size: 28),
                        const SizedBox(height: 4),
                        Text(
                          'Align barcode in frame',
                          style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  if (_searchingStudent)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: LitColors.ember),
                            SizedBox(height: 12),
                            Text('Auto-filling details...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Scanned Results or Custom Input Search
        Row(
          children: [
            Expanded(
              child: ClayTextField(
                controller: _usnController,
                hintText: 'Enter USN to query manually',
                prefixIcon: const Icon(Icons.badge_outlined),
                onChanged: (val) {
                  if (val.trim().length >= 10) {
                    _searchStudent(val);
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
              onPressed: () => _searchStudent(_usnController.text),
              child: const Icon(Icons.search_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_usnController.text.isNotEmpty && !_searchingStudent) ...[
          Expanded(
            child: SingleChildScrollView(
              child: _buildPopulatedFormDetails(),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Scan student barcode ID card or enter USN to fetch details.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 11.5),
            ),
          ),
        ],
      ],
    );
  }

  String _getErrorMessage(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Camera permission denied. Please enable it in settings.';
      case MobileScannerErrorCode.unsupported:
        return 'Scanning is not supported on this device.';
      default:
        return 'An unexpected error occurred: ${error.errorDetails?.message ?? 'Unknown'}';
    }
  }

  Widget _buildManualFormSection() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ClayTextField(
                    controller: _usnController,
                    hintText: 'USN (Required)',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    validator: (val) => val == null || val.trim().isEmpty ? 'USN is required' : null,
                    onChanged: (val) {
                      if (val.trim().length >= 10) {
                        _searchStudent(val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ClayTextField(
                    controller: _nameController,
                    hintText: 'Full Name (Required)',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClayInsetCard(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonFormField<String>(
                            value: _branch,
                            dropdownColor: LitColors.clay,
                            decoration: const InputDecoration(border: InputBorder.none),
                            items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (val) => setState(() => _branch = val ?? 'CS'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClayInsetCard(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonFormField<int>(
                            value: _year,
                            dropdownColor: LitColors.clay,
                            decoration: const InputDecoration(border: InputBorder.none),
                            items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('$y Year', style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (val) => setState(() => _year = val ?? 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClayTextField(
                    controller: _phoneController,
                    hintText: 'Phone Number (Optional)',
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_android_rounded),
                  ),
                  const SizedBox(height: 12),
                  ClayTextField(
                    controller: _emailController,
                    hintText: 'Email Address (Optional)',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClayButton(
            onPressed: _saving ? null : _confirmParticipantForSlot,
            child: _saving 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF1A0D05), strokeWidth: 2))
                : Text(_selectedEvent!.isTeamEvent ? 'Confirm & Add Member' : 'Verify & Register Student'),
          ),
        ],
      ),
    );
  }

  Widget _buildPopulatedFormDetails() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (_isNewStudent)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2B1C15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LitColors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: LitColors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'New Student! Please fill details to save record.',
                      style: GoogleFonts.plusJakartaSans(color: LitColors.amber, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ClayTextField(
            controller: _nameController,
            hintText: 'Full Name',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClayInsetCard(
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<String>(
                    value: _branch,
                    dropdownColor: LitColors.clay,
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) => setState(() => _branch = val ?? 'CS'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClayInsetCard(
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<int>(
                    value: _year,
                    dropdownColor: LitColors.clay,
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('$y Yr', style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) => setState(() => _year = val ?? 1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClayTextField(
            controller: _phoneController,
            hintText: 'Phone (Optional)',
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(Icons.phone_android_rounded),
          ),
          const SizedBox(height: 12),
          ClayButton(
            onPressed: _saving ? null : _confirmParticipantForSlot,
            child: _saving 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF1A0D05), strokeWidth: 2))
                : Text(_selectedEvent!.isTeamEvent ? 'Confirm Member' : 'Confirm & Register Student'),
          ),
        ],
      ),
    );
  }

  Widget _buildAllSlotsFilledCard() {
    return ClayCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, size: 56, color: LitColors.moss),
          const SizedBox(height: 12),
          Text(
            'All Details Verified!',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: LitColors.moss,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedEvent!.isTeamEvent
                ? 'Ready to register team "${_teamNameController.text}"'
                : 'Ready to register participant for this event.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ClayButton(
            onPressed: _saving ? null : _submitRegistration,
            child: _saving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF1A0D05), strokeWidth: 2))
                : Text(_selectedEvent!.isTeamEvent ? 'Register Team Now' : 'Complete Registration'),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _activeSlotIndex = 0;
              });
            },
            child: Text(
              'Back to Edit Members',
              style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
