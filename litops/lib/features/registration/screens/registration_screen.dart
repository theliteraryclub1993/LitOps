import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
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
import '../../../core/utils/app_utils.dart';

final activeEventsProvider = FutureProvider<List<Event>>((ref) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.events)
      .select()
      .inFilter('status', ['registration_open', 'ongoing'])
      .order('title');
  return (data as List).map((e) => Event.fromJson(e)).toList();
});

const _branchDisplayNames = {
  'CS': 'Computer Science',
  'IS': 'Information Science',
  'CI': 'Artificial Intelligence and Machine Learning',
  'CB': 'Computer Science and Business Studies',
  'RI': 'Robotics & Intelligence',
  'EC': 'Electronics & Communication',
  'VL': 'VLSI',
  'EI': 'Electronics & Instrumentation',
  'EE': 'Electrical & Electronics',
  'CV': 'Civil',
  'ME': 'Mechanical',
};

class RegistrationScreen extends ConsumerStatefulWidget {
  final Event? initialEvent;
  const RegistrationScreen({super.key, this.initialEvent});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> with SingleTickerProviderStateMixin {
  // Step 1 state
  Event? _selectedEvent;
  List<Event> _events = [];
  bool _loadingEvents = true;
  
  // Team name = first participant's department
  String? _teamDepartment;
  
  // Participants list
  List<Student?> _participants = [];
  
  // Active slot for adding participants
  int _activeSlotIndex = 0;
  
  // Search/autocomplete variables
  final _searchController = TextEditingController();
  List<Student> _searchSuggestions = [];
  Timer? _debounceTimer;
  bool _searching = false;
  bool _loadingSuggestions = false;
  
  // UI state
  int _currentStep = 0; // 0: select event, 1: add participants, 2: review & submit
  int _registrationMode = 0; // 0: barcode, 1: manual
  
  // Form state (for manual entry if student not found)
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _branch = 'CS';
  int _year = 1;
  Student? _selectedStudentFromSearch;
  bool _isNewStudent = false;
  
  // Submission state
  bool _submitting = false;
  bool _scanEnabled = true;
  
  final List<String> _branches = [
    'CS', 'IS', 'CI', 'CB', 'RI', 'EC', 'VL', 'EI', 'EE', 'CV', 'ME'
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _searchController.addListener(_onSearchUsnChanged);
  }

  void _onSearchUsnChanged() {
    final usn = _searchController.text.trim().toUpperCase();
    final usnRegExp = RegExp(r'^\d[A-Z]{2}\d{2}[A-Z]{2}\d{3}$');
    if (usnRegExp.hasMatch(usn)) {
      final yearPart = usn.substring(3, 5);
      final branchPart = usn.substring(5, 7);
      
      final admissionYear = int.tryParse("20$yearPart");
      int? inferredYear;
      if (admissionYear != null) {
        final now = DateTime.now();
        final currentYear = now.year;
        final currentMonth = now.month;
        int studyYear = currentYear - admissionYear;
        if (currentMonth >= 8) {
          studyYear += 1;
        }
        if (studyYear >= 1 && studyYear <= 4) {
          inferredYear = studyYear;
        }
      }
      
      setState(() {
        if (_branches.contains(branchPart)) {
          _branch = branchPart;
        }
        if (inferredYear != null) {
          _year = inferredYear;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchUsnChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final data = await SupabaseConfig.client
          .from(SupabaseTables.events)
          .select()
          .inFilter('status', ['registration_open', 'ongoing'])
          .order('title');
      
      setState(() {
        _events = (data as List).map((e) => Event.fromJson(e)).toList();
        if (widget.initialEvent != null) {
          _selectedEvent = _events.firstWhere(
            (e) => e.id == widget.initialEvent!.id,
            orElse: () => widget.initialEvent!,
          );
        }
        _loadingEvents = false;
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
      setState(() => _loadingEvents = false);
    }
  }

  void _initializeSlots() {
    if (_selectedEvent == null) return;
    int size = _selectedEvent!.isTeamEvent ? _selectedEvent!.teamSize : 1;
    _participants = List.filled(size, null);
    _teamDepartment = null;
    _activeSlotIndex = 0;
    _clearSearchAndForm();
  }

  void _clearSearchAndForm() {
    _searchController.clear();
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    setState(() {
      _searchSuggestions = [];
      _selectedStudentFromSearch = null;
      _branch = 'CS';
      _year = 1;
      _isNewStudent = false;
      _scanEnabled = true;
    });
  }

  Future<void> _searchStudents(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _loadingSuggestions = false;
      });
      return;
    }

    final searchQuery = query.trim().toUpperCase();
    setState(() => _loadingSuggestions = true);

    try {
      // First search in student_master
      final studentData = await SupabaseConfig.client
          .from(SupabaseTables.studentMaster)
          .select()
          .ilike('usn', '%$searchQuery%')
          .limit(10);

      List<Student> students = (studentData as List).map((s) => Student.fromJson(s)).toList();

      // Then search in profiles
      if (students.length < 10) {
        final profileData = await SupabaseConfig.client
            .from(SupabaseTables.profiles)
            .select()
            .ilike('usn', '%$searchQuery%')
            .limit(10 - students.length);

        for (var p in profileData) {
          final profile = Profile.fromJson(p);
          final exists = students.any((s) => s.usn == profile.usn);
          if (!exists && profile.usn != null) {
            students.add(
              Student(
                id: '-1',
                usn: profile.usn!,
                name: profile.fullName,
                branch: profile.branch ?? 'CS',
                year: profile.year ?? 1,
                phone: profile.phone,
                email: profile.email,
                status: StudentStatus.active,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
          }
        }
      }

      setState(() {
        _searchSuggestions = students;
        _loadingSuggestions = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _searchSuggestions = [];
        _loadingSuggestions = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchStudents(query);
    });
  }

  Future<void> _selectStudentFromSearch(Student student) async {
    setState(() {
      _selectedStudentFromSearch = student;
      _searchController.text = student.usn;
      _searchSuggestions = [];
      _nameController.text = student.name;
      _phoneController.text = student.phone ?? '';
      _emailController.text = student.email ?? '';
      _branch = _branches.contains(student.branch.toUpperCase()) 
          ? student.branch.toUpperCase() 
          : _branches.first;
      _year = student.year;
      _isNewStudent = false;
    });
  }

  Future<void> _confirmParticipant() async {
    if (_selectedEvent == null) return;

    // For team events, check department matching
    if (_selectedEvent!.isTeamEvent && _teamDepartment != null) {
      if (_branch != _teamDepartment) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This team already belongs to ${_branchDisplayNames[_teamDepartment]}. Only ${_branchDisplayNames[_teamDepartment]} students can be added.'),
              backgroundColor: LitColors.amber,
            ),
          );
        }
        return;
      }
    }

    Student? student;

    if (_selectedStudentFromSearch != null) {
      final modifiedStudent = _selectedStudentFromSearch!.copyWith(
        branch: _branch,
        year: _year,
      );
      // If we have a real student from DB
      if (modifiedStudent.id != '-1') {
        student = modifiedStudent;
        try {
          await SupabaseConfig.client
              .from(SupabaseTables.studentMaster)
              .update({
                'branch': _branch,
                'year': _year,
              })
              .eq('id', student.id);
        } catch (e) {
          debugPrint('Error updating student master in DB: $e');
        }
      } else {
        // It's a profile student, we need to upsert to student_master
        student = await _upsertStudentFromProfile(modifiedStudent);
      }
    } else {
      // Manual entry, must validate and upsert
      if (!_formKey.currentState!.validate()) return;
      student = await _upsertStudentManual();
    }

    if (student == null) return;

    // Check if already in participants
    if (_participants.any((p) => p?.id == student!.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.name} is already added!'),
            backgroundColor: LitColors.amber,
          ),
        );
      }
      return;
    }

    setState(() {
      _participants[_activeSlotIndex] = student;
      
      // Set team department on first participant
      if (_selectedEvent!.isTeamEvent && _activeSlotIndex == 0) {
        _teamDepartment = student!.branch;
      }

      // Move to next empty slot
      for (int i = 0; i < _participants.length; i++) {
        if (_participants[i] == null) {
          _activeSlotIndex = i;
          break;
        }
      }
      
      _clearSearchAndForm();
    });
  }

  Future<Student?> _upsertStudentFromProfile(Student tempStudent) async {
    try {
      final studentData = {
        'usn': tempStudent.usn,
        'name': tempStudent.name,
        'branch': tempStudent.branch,
        'year': tempStudent.year,
        'phone': tempStudent.phone,
        'email': tempStudent.email,
        'status': 'active',
      };

      final existing = await SupabaseConfig.client
          .from(SupabaseTables.studentMaster)
          .select()
          .ilike('usn', tempStudent.usn)
          .maybeSingle();

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
      debugPrint('Upsert error: $e');
      return null;
    }
  }

  Future<Student?> _upsertStudentManual() async {
    final name = _nameController.text.trim();
    final usn = _searchController.text.trim().toUpperCase();
    
    if (name.isEmpty || usn.isEmpty) return null;

    try {
      final studentData = {
        'usn': usn,
        'name': name,
        'branch': _branch,
        'year': _year,
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'status': 'active',
      };

      final existing = await SupabaseConfig.client
          .from(SupabaseTables.studentMaster)
          .select()
          .ilike('usn', usn)
          .maybeSingle();

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
      debugPrint('Upsert error: $e');
      return null;
    }
  }

  void _removeParticipant(int index) {
    setState(() {
      _participants[index] = null;
      // Reset team department if removing first participant
      if (_selectedEvent!.isTeamEvent && index == 0) {
        _teamDepartment = null;
      }
      _activeSlotIndex = index;
    });
  }

  void _editStudentBranchAndYear(int index) {
    final student = _participants[index];
    if (student == null) return;

    String selectedBranch = student.branch;
    int selectedYear = student.year;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: LitColors.clay,
              title: Text(
                'Edit Details for ${student.name}',
                style: GoogleFonts.fredoka(color: LitColors.bone, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedBranch,
                    dropdownColor: LitColors.clay,
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      labelStyle: TextStyle(color: LitColors.ash),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: LitColors.clay2)),
                    ),
                    items: _branches
                        .map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(
                                _branchDisplayNames[b] ?? b,
                                style: const TextStyle(color: LitColors.bone),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedBranch = v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: selectedYear,
                    dropdownColor: LitColors.clay,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      labelStyle: TextStyle(color: LitColors.ash),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: LitColors.clay2)),
                    ),
                    items: [1, 2, 3, 4]
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text(
                                '$y Year',
                                style: const TextStyle(color: LitColors.bone),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedYear = v);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: LitColors.ash)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final updatedStudent = student.copyWith(
                      branch: selectedBranch,
                      year: selectedYear,
                    );
                    
                    setState(() {
                      _participants[index] = updatedStudent;
                    });
                    
                    Navigator.pop(context);

                    try {
                      await SupabaseConfig.client
                          .from(SupabaseTables.studentMaster)
                          .update({
                            'branch': selectedBranch,
                            'year': selectedYear,
                          })
                          .eq('id', student.id);
                    } catch (e) {
                      debugPrint('Error updating student details in DB: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LitColors.moss,
                    foregroundColor: const Color(0xFF1A0D05),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitRegistration() async {
    if (_selectedEvent == null) return;
    
    setState(() => _submitting = true);

    try {
      final profile = ref.read(currentProfileProvider);
      final userId = profile!.id;
      final method = _registrationMode == 0 ? 'barcode' : 'manual';

      if (!_selectedEvent!.isTeamEvent) {
        final student = _participants[0]!;

        // Check duplicates
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
              const SnackBar(content: Text('Student already registered!'), backgroundColor: LitColors.amber),
            );
          }
          setState(() => _submitting = false);
          return;
        }

        // Insert registration
        final regData = await SupabaseConfig.client
            .from(SupabaseTables.registrations)
            .insert({
              'event_id': _selectedEvent!.id,
              'student_id': student.id,
              'registration_method': method,
              'registered_by': userId,
            })
            .select()
            .single();

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
          showTopNotification(
            context,
            'Successfully registered ${student.name} for ${_selectedEvent!.name}!',
            type: NotificationType.success,
          );
        }
      } else {
        final teamName = _branchDisplayNames[_teamDepartment] ?? _teamDepartment!;
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
          showTopNotification(
            context,
            'Successfully registered team "$teamName" for ${_selectedEvent!.name}!',
            type: NotificationType.success,
          );
        }
      }

      ref.invalidate(eventRegistrationsCountProvider(_selectedEvent!.id));
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(eventConstraintsSummaryProvider(_selectedEvent!.id));
      ref.invalidate(eventsListProvider);
      ref.invalidate(eventAttendanceProvider(_selectedEvent!.id));
      ref.invalidate(activeEventsProvider);
      
      // Reset to step 0
      setState(() {
        _currentStep = 0;
        _initializeSlots();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration error: $e'), backgroundColor: LitColors.coral),
        );
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    final profile = ref.watch(currentProfileProvider);
    
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
              : _currentStep == 0
                  ? _buildStepSelectEvent()
                  : _currentStep == 1
                      ? _buildStepAddParticipants()
                      : _buildStepReview(),
    );
  }

  Widget _buildStepSelectEvent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 1: Select Event',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: LitColors.bone,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose an ongoing event to register for',
            style: GoogleFonts.plusJakartaSans(
              color: LitColors.ash,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _events.length,
            itemBuilder: (context, index) {
              final event = _events[index];
              final isSelected = _selectedEvent?.id == event.id;
              final categoryColor = AppTheme.getCategoryColor(event.category.value);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedEvent = event;
                      _initializeSlots();
                      _currentStep = 1;
                    });
                  },
                  child: ClayCard(
                    borderColor: isSelected ? categoryColor : null,
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
                                event.category.label,
                                style: GoogleFonts.plusJakartaSans(
                                  color: categoryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const Spacer(),
                            StatusChip(label: event.status.label),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          event.name,
                          style: GoogleFonts.fredoka(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: LitColors.bone,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: event.isTeamEvent 
                                    ? LitColors.ember.withOpacity(0.15)
                                    : LitColors.moss.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                event.isTeamEvent 
                                    ? 'Team Event (${event.teamSize})'
                                    : 'Individual Event',
                                style: GoogleFonts.plusJakartaSans(
                                  color: event.isTeamEvent ? LitColors.ember : LitColors.moss,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_outlined, size: 14, color: LitColors.ash),
                                const SizedBox(width: 4),
                                Text(
                                  event.venue ?? 'TBA',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: LitColors.ash,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            if (event.eventDate != null) ...[
                              const SizedBox(width: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time_outlined, size: 14, color: LitColors.ash),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppUtils.formatDate(event.eventDate!),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: LitColors.ash,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildStepAddParticipants() {
    final isTeam = _selectedEvent!.isTeamEvent;
    final allSlotsFilled = _participants.every((p) => p != null);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: LitColors.bone),
                  onPressed: () => setState(() => _currentStep = 0),
                ),
                Expanded(
                  child: Text(
                    'Step 2: Add Participants',
                    style: GoogleFonts.fredoka(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: LitColors.bone,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClayCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedEvent!.name,
                    style: GoogleFonts.fredoka(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: LitColors.bone,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        isTeam ? 'Team Size: ${_participants.length}' : 'Individual Event',
                        style: GoogleFonts.plusJakartaSans(
                          color: LitColors.ash,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 100,
                        height: 6,
                        decoration: BoxDecoration(
                          color: LitColors.clay3,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: _participants.where((p) => p != null).length / _participants.length,
                          child: Container(
                            decoration: BoxDecoration(
                              color: LitColors.ember,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_participants.where((p) => p != null).length}/${_participants.length}',
                        style: GoogleFonts.plusJakartaSans(
                          color: LitColors.ember,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isTeam) ...[
              ClayCard(
                borderColor: LitColors.moss,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team Name (Department)',
                      style: GoogleFonts.plusJakartaSans(
                        color: LitColors.ash,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClayInsetCard(
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _teamDepartment,
                        dropdownColor: LitColors.clay,
                        hint: Text('Select Team Department', style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 12)),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        items: _branches.map((b) => DropdownMenuItem<String>(
                          value: b,
                          child: Text(
                            _branchDisplayNames[b] ?? b,
                            style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _teamDepartment = value;
                              // Clear participants that don't match the new department
                              for (int i = 0; i < _participants.length; i++) {
                                if (_participants[i] != null && _participants[i]!.branch != value) {
                                  _participants[i] = null;
                                }
                              }
                              // Reset active slot index to first empty slot
                              _activeSlotIndex = 0;
                              for (int i = 0; i < _participants.length; i++) {
                                if (_participants[i] == null) {
                                  _activeSlotIndex = i;
                                  break;
                                }
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ClayCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTeam ? 'Team Members' : 'Participant',
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
                      final isActive = index == _activeSlotIndex && student == null;
                      final roleName = index == 0 ? 'Captain' : 'Member ${index + 1}';
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClayCard(
                          color: student != null
                              ? const Color(0xFF11261B)
                              : (isActive ? const Color(0xFF2B1C15) : LitColors.clay2),
                          borderColor: isActive
                              ? LitColors.ember
                              : (student != null ? LitColors.moss : null),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: student != null
                                    ? LitColors.moss
                                    : (isActive ? LitColors.ember : LitColors.clay3),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Color(0xFF1A0D05), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            title: Text(
                              student != null 
                                  ? student.name 
                                  : (isActive ? 'Add $roleName' : 'Empty Slot'),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: student != null
                                    ? LitColors.moss
                                    : (isActive ? LitColors.ember : LitColors.ash),
                              ),
                            ),
                            subtitle: student != null
                                ? Text('${student.usn} • ${student.branch} • ${student.year} Yr', 
                                    style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 11))
                                : Text(roleName, style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 11)),
                            trailing: student != null
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: LitColors.moss, size: 20),
                                        onPressed: () => _editStudentBranchAndYear(index),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: LitColors.coral, size: 20),
                                        onPressed: () => _removeParticipant(index),
                                      ),
                                    ],
                                  )
                                : null,
                            onTap: () {
                              if (student == null) {
                                setState(() {
                                  _activeSlotIndex = index;
                                  _clearSearchAndForm();
                                });
                              } else {
                                _editStudentBranchAndYear(index);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_activeSlotIndex < _participants.length && _participants[_activeSlotIndex] == null) ...[
              ClayCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add ${_selectedEvent!.isTeamEvent ? (_activeSlotIndex == 0 ? "Captain" : "Member ${_activeSlotIndex + 1}") : "Participant"}',
                      style: GoogleFonts.fredoka(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: LitColors.ember,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _registrationMode = 0);
                            },
                            child: ClayCard(
                              color: _registrationMode == 0 
                                  ? LitColors.ember.withOpacity(0.2) 
                                  : LitColors.clay2,
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: _registrationMode == 0 ? LitColors.ember : LitColors.ash,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Barcode Scan',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: _registrationMode == 0 ? LitColors.ember : LitColors.ash,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _registrationMode = 1);
                            },
                            child: ClayCard(
                              color: _registrationMode == 1 
                                  ? LitColors.ember.withOpacity(0.2) 
                                  : LitColors.clay2,
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    color: _registrationMode == 1 ? LitColors.ember : LitColors.ash,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Manual Entry',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: _registrationMode == 1 ? LitColors.ember : LitColors.ash,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _registrationMode == 0 
                        ? _buildBarcodeScanSection()
                        : _buildManualEntrySection(),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (allSlotsFilled)
              ClayButton(
                width: double.infinity,
                height: 50,
                isGhost: false,
                onPressed: () => setState(() => _currentStep = 2),
                child: Text(
                  'Review & Submit',
                  style: GoogleFonts.plusJakartaSans(
                    color: LitColors.void_,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 120),
          ],
        ),
      );
  }

  Widget _buildBarcodeScanSection() {
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_scanEnabled)
                    MobileScanner(
                      onDetect: (capture) {
                        final barcode = capture.barcodes.first;
                        if (barcode.rawValue != null) {
                          final extractedUsn = AppUtils.extractUsnFromScan(barcode.rawValue!);
                          if (extractedUsn.isNotEmpty) {
                            setState(() {
                              _scanEnabled = false;
                              _searchController.text = extractedUsn;
                            });
                            _searchStudents(extractedUsn);
                          }
                        }
                      },
                    ),
                  if (!_scanEnabled)
                    Positioned.fill(
                      child: Container(
                        color: LitColors.clay2,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_scanner, color: LitColors.ash, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Scanner Stopped',
                              style: GoogleFonts.fredoka(
                                  color: LitColors.bone, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap the button below to start scanning',
                              style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ClayButton(
                              width: 160,
                              height: 40,
                              isGhost: false,
                              onPressed: () => setState(() => _scanEnabled = true),
                              child: Text(
                                'Open Scanner',
                                style: GoogleFonts.plusJakartaSans(
                                  color: LitColors.void_,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_scanEnabled)
                    Container(
                      width: 240,
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: LitColors.ember.withOpacity(0.55),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded, color: LitColors.ember, size: 32),
                          const SizedBox(height: 6),
                          Text(
                            'Align barcode in frame',
                            style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  if (_searching)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: LitColors.ember),
                            SizedBox(height: 12),
                            Text('Fetching details...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ClayTextField(
          controller: _searchController,
          hintText: 'Or enter USN manually...',
          prefixIcon: const Icon(Icons.badge_outlined),
          onChanged: _onSearchChanged,
        ),
        if (_selectedStudentFromSearch != null) ...[
          const SizedBox(height: 16),
          _buildStudentDetailsCard(),
        ] else if (_searchSuggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSuggestionsList(),
        ],
      ],
    );
  }

  Widget _buildManualEntrySection() {
    final hasSelectedStudent = _selectedStudentFromSearch != null;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClayTextField(
            controller: _searchController,
            hintText: 'Search/Enter USN...',
            prefixIcon: const Icon(Icons.badge_outlined),
            onChanged: (val) {
              if (hasSelectedStudent && val.trim().toUpperCase() != _selectedStudentFromSearch!.usn.toUpperCase()) {
                setState(() {
                  _selectedStudentFromSearch = null;
                  _nameController.clear();
                  _phoneController.clear();
                  _emailController.clear();
                });
              }
              _onSearchChanged(val);
            },
            suffixIcon: hasSelectedStudent
                ? IconButton(
                    icon: const Icon(Icons.clear, color: LitColors.ash),
                    onPressed: _clearSearchAndForm,
                  )
                : null,
          ),
          if (_searchSuggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSuggestionsList(),
          ],
          if (hasSelectedStudent) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: LitColors.moss.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: LitColors.moss.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: LitColors.moss, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Existing student loaded. Only Branch and Year can be updated.',
                      style: GoogleFonts.plusJakartaSans(color: LitColors.moss, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          ClayTextField(
            controller: _nameController,
            hintText: 'Student Name (Required)',
            prefixIcon: const Icon(Icons.person_outlined),
            readOnly: hasSelectedStudent,
            validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClayInsetCard(
                  borderRadius: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _branch,
                    dropdownColor: LitColors.clay,
                    hint: Text('Branch', style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 12)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    items: _branches.map((b) => DropdownMenuItem<String>(
                      value: b,
                      child: Text(
                        _branchDisplayNames[b] ?? b,
                        style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _branch = value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClayInsetCard(
                  borderRadius: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _year,
                    dropdownColor: LitColors.clay,
                    hint: Text('Year', style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 12)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    items: [1, 2, 3, 4].map((y) => DropdownMenuItem<int>(
                      value: y,
                      child: Text(
                        '$y Year',
                        style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _year = value);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClayTextField(
            controller: _phoneController,
            hintText: 'Phone (Optional)',
            prefixIcon: const Icon(Icons.phone_outlined),
            readOnly: hasSelectedStudent,
          ),
          const SizedBox(height: 12),
          ClayTextField(
            controller: _emailController,
            hintText: 'Email (Optional)',
            prefixIcon: const Icon(Icons.email_outlined),
            readOnly: hasSelectedStudent,
          ),
          const SizedBox(height: 16),
          ClayButton(
            width: double.infinity,
            height: 48,
            isGhost: false,
            onPressed: _confirmParticipant,
            child: Text(
              hasSelectedStudent ? 'Update & Add Participant' : 'Add Participant',
              style: GoogleFonts.plusJakartaSans(
                color: LitColors.void_,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      decoration: BoxDecoration(
        color: LitColors.clay2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LitColors.clay3),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: _searchSuggestions.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFF262220)),
        itemBuilder: (context, index) {
          final student = _searchSuggestions[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: LitColors.clay3,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                student.usn.length >= 3 ? student.usn.substring(student.usn.length - 3) : student.usn,
                style: GoogleFonts.plusJakartaSans(
                  color: LitColors.bone,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            title: Text(
              student.name,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: LitColors.bone,
              ),
            ),
            subtitle: Text(
              '${student.usn} • ${_branchDisplayNames[student.branch] ?? student.branch} • ${student.year} Yr',
              style: GoogleFonts.plusJakartaSans(
                color: LitColors.ash,
                fontSize: 10,
              ),
            ),
            onTap: () => _selectStudentFromSearch(student),
          );
        },
      ),
    );
  }

  Widget _buildStudentDetailsCard() {
    final student = _selectedStudentFromSearch!;
    return Column(
      children: [
        ClayCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: LitColors.moss,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      student.usn.length >= 3 ? student.usn.substring(student.usn.length - 3) : student.usn,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: GoogleFonts.fredoka(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: LitColors.bone,
                          ),
                        ),
                        Text(
                          student.usn,
                          style: GoogleFonts.plusJakartaSans(
                            color: LitColors.ash,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFF262220)),
              Row(
                children: [
                  Expanded(
                    child: ClayInsetCard(
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _branch,
                        dropdownColor: LitColors.clay,
                        hint: Text('Branch', style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 12)),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        items: _branches.map((b) => DropdownMenuItem<String>(
                          value: b,
                          child: Text(
                            _branchDisplayNames[b] ?? b,
                            style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _branch = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClayInsetCard(
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: _year,
                        dropdownColor: LitColors.clay,
                        hint: Text('Year', style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 12)),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        items: [1, 2, 3, 4].map((y) => DropdownMenuItem<int>(
                          value: y,
                          child: Text(
                            '$y Year',
                            style: GoogleFonts.plusJakartaSans(color: LitColors.bone, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _year = value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (student.phone != null && student.phone!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, color: LitColors.ash, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      student.phone!,
                      style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        ClayButton(
          width: double.infinity,
          height: 48,
          isGhost: false,
          onPressed: _confirmParticipant,
          child: Text(
            'Add Participant',
            style: GoogleFonts.plusJakartaSans(
              color: LitColors.void_,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepReview() {
    final isTeam = _selectedEvent!.isTeamEvent;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: LitColors.bone),
                  onPressed: () => setState(() => _currentStep = 1),
                ),
                Expanded(
                  child: Text(
                    'Step 3: Review & Submit',
                    style: GoogleFonts.fredoka(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: LitColors.bone,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClayCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event',
                    style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedEvent!.name,
                    style: GoogleFonts.fredoka(color: LitColors.bone, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 24, color: Color(0xFF262220)),
                  if (isTeam) ...[
                    Text(
                      'Team Name',
                      style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _branchDisplayNames[_teamDepartment] ?? _teamDepartment!,
                      style: GoogleFonts.fredoka(color: LitColors.moss, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Divider(height: 24, color: Color(0xFF262220)),
                  ],
                  Text(
                    isTeam ? 'Team Members' : 'Participant',
                    style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: 10),
                  ),
                  const SizedBox(height: 12),
                  ..._participants.asMap().entries.map((entry) {
                    final index = entry.key;
                    final student = entry.value!;
                    final role = index == 0 ? '(Captain)' : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClayCard(
                        color: const Color(0xFF11261B),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: LitColors.moss,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${student.name} $role',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: LitColors.moss,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${student.usn} • ${student.branch} • ${student.year} Yr',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: LitColors.ash,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ClayButton(
              width: double.infinity,
              height: 52,
              isGhost: false,
              onPressed: _submitting ? null : _submitRegistration,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF1A0D05),
                        ),
                      ),
                    )
                  : Text(
                      'Complete Registration',
                      style: GoogleFonts.plusJakartaSans(
                        color: LitColors.void_,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      );
  }
}
