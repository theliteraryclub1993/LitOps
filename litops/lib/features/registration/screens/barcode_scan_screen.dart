import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../auth/providers/auth_provider.dart';
import '../../events/screens/event_detail_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import 'registration_screen.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/app_utils.dart';

class BarcodeScanScreen extends ConsumerStatefulWidget {
  final Event? initialEvent;
  const BarcodeScanScreen({super.key, this.initialEvent});

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final _usnController = TextEditingController();

  // Manual Entry controllers
  final _manualNameController = TextEditingController();
  final _manualUsnController = TextEditingController();
  final _manualPhoneController = TextEditingController();
  final _manualEmailController = TextEditingController();

  String _manualBranch = 'CSE';
  int _manualYear = 1;
  String _manualSection = 'A';
  final List<String> _branches = [
    'CSE',
    'ISE',
    'CI',
    'CB',
    'RI',
    'ECE',
    'VL',
    'EI',
    'EE',
    'CV',
    'ME'
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

  Event? _selectedEvent;
  List<Event> _events = [];
  bool _isLoading = false;
  bool _isRegistering = false;
  bool _scanEnabled = true;
  String? _teamDepartment;

  // Participant slots
  List<Student?> _participants = [];
  int _activeSlotIndex = 0;
  bool _showManualFormForActiveSlot = false;

  @override
  void initState() {
    super.initState();
    _selectedEvent = widget.initialEvent;
    _initializeSlots();
    _loadEvents();
    _manualUsnController.addListener(_onManualUsnChanged);
  }

  /// Pre-fills branch and year dropdowns in the manual entry form based on the typed USN.
  /// This is a UI CONVENIENCE ONLY — it never overwrites the stored USN.
  /// The admission year embedded in the USN (e.g., '22' in 4MC22CS001) is NEVER modified.
  void _onManualUsnChanged() {
    final usn = _manualUsnController.text.trim().toUpperCase();
    final inferredBranch = AppUtils.extractBranchFromUsn(usn);
    final inferredYear = AppUtils.inferCurrentStudyYearFromUsn(usn);
    
    setState(() {
      if (_branches.contains(inferredBranch)) {
        _manualBranch = inferredBranch;
      }
      if (inferredYear != null) {
        _manualYear = inferredYear;
      }
    });
  }

  void _initializeSlots() {
    if (_selectedEvent == null) {
      _participants = [];
      _activeSlotIndex = 0;
    } else {
      int size =
          _selectedEvent!.isTeamEvent ? (_selectedEvent!.teamSize ?? 2) : 1;
      _participants = List.filled(size, null);
      _activeSlotIndex = 0;
    }
    _showManualFormForActiveSlot = false;
    _teamDepartment = null;
  }

  Future<void> _loadEvents() async {
    final data = await SupabaseConfig.client
        .from(SupabaseTables.events)
        .select()
        .inFilter('status', ['registration_open', 'ongoing']).order('title');
    setState(() {
      _events = (data as List).map((e) => Event.fromJson(e)).toList();
      if (_selectedEvent != null) {
        _selectedEvent = _events.firstWhere((e) => e.id == _selectedEvent!.id,
            orElse: () => _selectedEvent!);
      }
    });
  }

  Future<void> _searchStudent(String usn) async {
    if (usn.isEmpty ||
        _selectedEvent == null ||
        _activeSlotIndex >= _participants.length) {
      return;
    }

    setState(() {
      _isLoading = true;
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
        // Check if already in slots
        if (_participants.any((p) => p?.id == student!.id)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Student is already in the participant list'),
                backgroundColor: Colors.orange));
          }
        } else {
          // Check branch participation constraint
          final constraintsSummary = ref.read(eventConstraintsSummaryProvider(_selectedEvent!.id)).value ?? [];
          final constraint = constraintsSummary.firstWhere(
            (c) => c['branch'] == student.branch,
            orElse: () => {},
          );
          if (constraint.isNotEmpty) {
            final int maxParticipants = constraint['max'] as int;
            final int currentParticipants = constraint['current'] as int;
            final int pendingCount = _participants.where((p) => p != null && p.branch == student.branch && p.id != student.id).length;
            
            if (currentParticipants + pendingCount + 1 > maxParticipants) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Limit exceeded! Only $maxParticipants participants from ${student.branch} are allowed for this event.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              setState(() {
                _isLoading = false;
                _scanEnabled = true;
              });
              return;
            }
          }

          if (_selectedEvent!.isTeamEvent && _teamDepartment != null) {
            if (student.branch != _teamDepartment) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('This team belongs to ${_branchDisplayNames[_teamDepartment]}. Only ${_branchDisplayNames[_teamDepartment]} students can be added.'),
                    backgroundColor: Colors.orange));
              }
              setState(() {
                _isLoading = false;
              });
              return;
            }
          }

          setState(() {
            _participants[_activeSlotIndex] = student;
            if (_selectedEvent!.isTeamEvent && _activeSlotIndex == 0) {
              _teamDepartment = student.branch;
            }
            _moveToNextEmptySlot();
          });
        }
      } else {
        setState(() {
          _showManualFormForActiveSlot = true;
          _manualUsnController.text = searchUsn;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Student not found. Please enter details manually.'),
              backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _moveToNextEmptySlot() {
    _showManualFormForActiveSlot = false;
    for (int i = 0; i < _participants.length; i++) {
      if (_participants[i] == null) {
        _activeSlotIndex = i;
        return;
      }
    }
    // If all filled, keep it at the last one or something
    _activeSlotIndex = _participants.length;
  }

  void _removeParticipant(int index) {
    setState(() {
      _participants[index] = null;
      if (_selectedEvent!.isTeamEvent && index == 0) {
        _teamDepartment = null;
      }
      if (_activeSlotIndex > index ||
          _activeSlotIndex == _participants.length) {
        _activeSlotIndex = index;
      }
      _showManualFormForActiveSlot = false;
    });
  }

  void _editStudentBranchAndYear(int index) {
    final student = _participants[index];
    if (student == null) return;

    final inferredBranch = AppUtils.extractBranchFromUsn(student.usn);
    String selectedBranch;
    if (_branches.contains(inferredBranch)) {
      selectedBranch = inferredBranch;
    } else {
      final stdBranch = AppUtils.mapUsnBranchToOfficial(student.branch);
      selectedBranch = _branches.contains(stdBranch) ? stdBranch : _branches.first;
    }
    // Use the DB-stored year, not the dynamically inferred one.
    int selectedYear = student.year;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1D1A18),
              title: Text(
                'Edit Details for ${student.name}',
                style: GoogleFonts.fredoka(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedBranch,
                    dropdownColor: const Color(0xFF1D1A18),
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      labelStyle: TextStyle(color: Color(0xFF8C857C)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF262220))),
                    ),
                    items: _branches
                        .map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(
                                b,
                                style: const TextStyle(color: Color(0xFFF3ECE2)),
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
                    initialValue: selectedYear,
                    dropdownColor: const Color(0xFF1D1A18),
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      labelStyle: TextStyle(color: Color(0xFF8C857C)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF262220))),
                    ),
                    items: [1, 2, 3, 4]
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text(
                                '$y Year',
                                style: const TextStyle(color: Color(0xFFF3ECE2)),
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
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C857C))),
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
                    backgroundColor: const Color(0xFF6FAE8F),
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

  Future<void> _saveManualStudent() async {
    final name = _manualNameController.text.trim();
    final usn = _manualUsnController.text.trim().toUpperCase();
    if (name.isEmpty || usn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill Name and USN'),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final existingStudent = await SupabaseConfig.client
          .from(SupabaseTables.studentMaster)
          .select()
          .ilike('usn', usn)
          .maybeSingle();

      Student student;
      if (existingStudent != null) {
        student = Student.fromJson(existingStudent);
      } else {
        final studentData = {
          'usn': usn,
          'name': name,
          'branch': _manualBranch,
          'year': _manualYear,
          'section': _manualSection,
          'phone': _manualPhoneController.text.trim().isEmpty
              ? null
              : _manualPhoneController.text.trim(),
          'email': _manualEmailController.text.trim().isEmpty
              ? null
              : _manualEmailController.text.trim(),
          'status': 'active',
        };
        final newStudentRows = await SupabaseConfig.client
            .from(SupabaseTables.studentMaster)
            .insert(studentData)
            .select();
        if (newStudentRows.isEmpty) throw Exception('Failed to create student');
        student = Student.fromJson(newStudentRows[0]);
      }

      if (_participants.any((p) => p?.id == student.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Student is already in the list'),
              backgroundColor: Colors.orange));
        }
      } else {
        // Check branch participation constraint
        final constraintsSummary = ref.read(eventConstraintsSummaryProvider(_selectedEvent!.id)).value ?? [];
        final constraint = constraintsSummary.firstWhere(
          (c) => c['branch'] == student.branch,
          orElse: () => {},
        );
        if (constraint.isNotEmpty) {
          final int maxParticipants = constraint['max'] as int;
          final int currentParticipants = constraint['current'] as int;
          final int pendingCount = _participants.where((p) => p != null && p.branch == student.branch && p.id != student.id).length;
          
          if (currentParticipants + pendingCount + 1 > maxParticipants) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Limit exceeded! Only $maxParticipants participants from ${student.branch} are allowed for this event.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }

        if (_selectedEvent!.isTeamEvent && _teamDepartment != null) {
          if (student.branch != _teamDepartment) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('This team belongs to ${_branchDisplayNames[_teamDepartment]}. Only ${_branchDisplayNames[_teamDepartment]} students can be added.'),
                  backgroundColor: Colors.orange));
            }
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }

        setState(() {
          _participants[_activeSlotIndex] = student;
          if (_selectedEvent!.isTeamEvent && _activeSlotIndex == 0) {
            _teamDepartment = student.branch;
          }
          _moveToNextEmptySlot();
        });
        _manualNameController.clear();
        _manualUsnController.clear();
        _manualPhoneController.clear();
        _manualEmailController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _submitRegistration() async {
    if (_selectedEvent == null) return;

    // Check branch participation constraint
    final constraintsSummary = ref.read(eventConstraintsSummaryProvider(_selectedEvent!.id)).value ?? [];
    for (final c in constraintsSummary) {
      final branch = c['branch'] as String;
      final maxVal = c['max'] as int;
      final current = c['current'] as int;
      
      final toRegisterCount = _participants.where((p) => p != null && p.branch == branch).length;
      if (current + toRegisterCount > maxVal) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Branch limit reached: $branch has reached the maximum of $maxVal participants for this event.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    // Validate
    if (_selectedEvent!.isTeamEvent) {
      if (_participants.any((p) => p == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill all team members')));
        return;
      }
    } else {
      if (_participants[0] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please add a student to register')));
        return;
      }
    }

    setState(() => _isRegistering = true);

    try {
      final profile = ref.read(currentProfileProvider);
      final userId = profile!.id;

      if (!_selectedEvent!.isTeamEvent) {
        // Solo Registration
        final student = _participants[0]!;

        // Check duplicate
        final existing = await SupabaseConfig.client
            .from(SupabaseTables.registrations)
            .select('id')
            .eq('event_id', _selectedEvent!.id)
            .eq('student_id', student.id)
            .eq('is_cancelled', false)
            .maybeSingle();

        if (existing != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Student already registered'),
                backgroundColor: Colors.orange));
          }
          setState(() {
            _isRegistering = false;
          });
          return;
        }

        // Insert registration
        final regData = await SupabaseConfig.client.from(SupabaseTables.registrations).insert({
          'event_id': _selectedEvent!.id,
          'student_id': student.id,
          'registration_method': 'barcode',
          'registered_by': userId,
        }).select().single();

        // Automatically mark attendance
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Successfully registered ${student.name}'),
              backgroundColor: Colors.green));
        }
      } else {
        // Team Registration
        final teamName = _branchDisplayNames[_teamDepartment] ?? _teamDepartment!;
        final captain = _participants[0]!;

        // Create Team
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

          // Add to team
          await SupabaseConfig.client.from(SupabaseTables.teamMembers).insert({
            'team_id': teamId,
            'student_id': student.id,
            'is_captain': isCaptain,
          });

          // Register student for event
          final existing = await SupabaseConfig.client
              .from(SupabaseTables.registrations)
              .select('id')
              .eq('event_id', _selectedEvent!.id)
              .eq('student_id', student.id)
              .eq('is_cancelled', false)
              .maybeSingle();

          String regId;
          if (existing == null) {
            final regData = await SupabaseConfig.client
                .from(SupabaseTables.registrations)
                .insert({
              'event_id': _selectedEvent!.id,
              'student_id': student.id,
              'registration_method': 'barcode',
              'registered_by': userId,
              'team_id': teamId,
            }).select().single();
            regId = regData['id'];
          } else {
            regId = existing['id'];
          }

          // Automatically mark attendance for team member
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Successfully registered team!'),
              backgroundColor: Colors.green));
        }
      }

      // Invalidate providers so UI updates everywhere
      ref.invalidate(eventRegistrationsCountProvider(_selectedEvent!.id));
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(activeEventsProvider);
      ref.invalidate(eventConstraintsSummaryProvider(_selectedEvent!.id));

      // Success, reset the form
      setState(() {
        _initializeSlots();
        _scanEnabled = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Registration error: $e'),
            backgroundColor: Colors.red));
      }
    }
    setState(() => _isRegistering = false);
  }

  @override
  void dispose() {
    _manualUsnController.removeListener(_onManualUsnChanged);
    _usnController.dispose();
    _manualNameController.dispose();
    _manualUsnController.dispose();
    _manualPhoneController.dispose();
    _manualEmailController.dispose();
    super.dispose();
  }

  Widget _buildSlotItem(int index) {
    final student = _participants[index];
    final isActive = index == _activeSlotIndex;
    return Card(
      color: student != null
          ? const Color(0xFF11261B)
          : (isActive ? const Color(0xFF2B1C15) : Theme.of(context).cardColor),
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFF262220),
            width: isActive ? 2 : 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: student != null
              ? const Color(0xFF6FAE8F)
              : (isActive ? Theme.of(context).colorScheme.primary : const Color(0xFF262220)),
          child: Text('${index + 1}',
              style: const TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
        ),
        title: Text(
          student != null
              ? student.name
              : (isActive ? 'Waiting for scan...' : 'Empty Slot'),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: student != null
                ? const Color(0xFF6FAE8F)
                : (isActive ? Theme.of(context).colorScheme.primary : const Color(0xFF8C857C)),
          ),
        ),
        subtitle: student != null
            ? Text('${student.usn} • ${student.branch} • ${student.year} Yr', style: const TextStyle(color: Color(0xFF8C857C)))
            : null,
        trailing: student != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF6FAE8F)),
                    onPressed: () => _editStudentBranchAndYear(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFFF5C5C)),
                    onPressed: () => _removeParticipant(index),
                  ),
                ],
              )
            : null,
        onTap: () {
          if (student == null) {
            setState(() {
              _activeSlotIndex = index;
              _showManualFormForActiveSlot = false;
              _scanEnabled = true;
            });
          } else {
            _editStudentBranchAndYear(index);
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    bool isAllFilled = _participants.isNotEmpty && !_participants.any((p) => p == null);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<Event>(
              initialValue: _selectedEvent,
              decoration: const InputDecoration(labelText: 'Select Event'),
              items: _events
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedEvent = v;
                  _initializeSlots();
                });
              },
            ),
          ),
          if (_selectedEvent != null) ...[
            if (_selectedEvent!.isTeamEvent) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: const Color(0xFF161413),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFF262220), width: 1.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Team Name (Department)',
                          style: TextStyle(color: Color(0xFF8C857C), fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _teamDepartment,
                          dropdownColor: const Color(0xFF1D1A18),
                          hint: const Text('Select Team Department', style: TextStyle(color: Color(0xFF8C857C), fontSize: 13)),
                          items: _branches.map((b) => DropdownMenuItem<String>(
                            value: b,
                            child: Text(
                              _branchDisplayNames[b] ?? b,
                              style: const TextStyle(color: Color(0xFFF3ECE2), fontSize: 13),
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
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_activeSlotIndex < _participants.length)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: const Color(0xFF161413),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFF262220), width: 1.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _showManualFormForActiveSlot ? _buildManualForm() : _buildScannerAndSearch(isTablet: false),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('All slots filled. Ready to register!',
                      style: TextStyle(fontSize: 16, color: Color(0xFF6FAE8F), fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Participant Slots',
                style: GoogleFonts.fredoka(color: const Color(0xFFF3ECE2), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _participants.length,
              itemBuilder: (context, index) => _buildSlotItem(index),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isRegistering || !isAllFilled) ? null : _submitRegistration,
                  icon: _isRegistering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Color(0xFF1A0D05), strokeWidth: 2))
                      : const Icon(Icons.check_circle),
                  label: Text(_selectedEvent!.isTeamEvent ? 'Register Team' : 'Register Participant',
                      style: const TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: isAllFilled ? const Color(0xFF6FAE8F) : const Color(0xFF262220),
                    foregroundColor: isAllFilled ? const Color(0xFF1A0D05) : const Color(0xFF8C857C),
                  ),
                ),
              ),
            )
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64, horizontal: 32),
              child: Center(
                child: Text('Please select an event to start registering.', style: TextStyle(color: Color(0xFF8C857C))),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    bool isAllFilled = _participants.isNotEmpty && !_participants.any((p) => p == null);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<Event>(
                  initialValue: _selectedEvent,
                  decoration: const InputDecoration(labelText: 'Select Event'),
                  items: _events
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedEvent = v;
                      _initializeSlots();
                    });
                  },
                ),
              ),
              if (_selectedEvent != null) ...[
                if (_selectedEvent!.isTeamEvent) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      color: const Color(0xFF161413),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFF262220), width: 1.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Team Name (Department)',
                              style: TextStyle(color: Color(0xFF8C857C), fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _teamDepartment,
                              dropdownColor: const Color(0xFF1D1A18),
                              hint: const Text('Select Team Department', style: TextStyle(color: Color(0xFF8C857C), fontSize: 13)),
                              items: _branches.map((b) => DropdownMenuItem<String>(
                                value: b,
                                child: Text(
                                  _branchDisplayNames[b] ?? b,
                                  style: const TextStyle(color: Color(0xFFF3ECE2), fontSize: 13),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _participants.length,
                    itemBuilder: (context, index) => _buildSlotItem(index),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isRegistering || !isAllFilled) ? null : _submitRegistration,
                      icon: _isRegistering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Color(0xFF1A0D05), strokeWidth: 2))
                          : const Icon(Icons.check_circle),
                      label: Text(_selectedEvent!.isTeamEvent ? 'Register Team' : 'Register Participant',
                          style: const TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isAllFilled ? const Color(0xFF6FAE8F) : const Color(0xFF262220),
                        foregroundColor: isAllFilled ? const Color(0xFF1A0D05) : const Color(0xFF8C857C),
                      ),
                    ),
                  ),
                )
              ] else ...[
                const Expanded(
                    child: Center(
                        child: Text('Please select an event to start registering.',
                            style: TextStyle(color: Color(0xFF8C857C))))),
              ]
            ],
          ),
        ),
        if (_selectedEvent != null && _activeSlotIndex < _participants.length)
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFF262220))),
              ),
              child: _showManualFormForActiveSlot ? _buildManualForm() : _buildScannerAndSearch(isTablet: true),
            ),
          ),
        if (_selectedEvent != null && _activeSlotIndex >= _participants.length)
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFF262220))),
              ),
              child: const Center(
                child: Text('All slots filled. Ready to register!',
                    style: TextStyle(fontSize: 18, color: Color(0xFF6FAE8F), fontWeight: FontWeight.bold)),
              ),
            ),
          )
      ],
    );
  }

  Widget _buildScannerAndSearch({required bool isTablet}) {
    final scannerWidget = SizedBox(
      height: isTablet ? null : 240,
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
                    if (!_scanEnabled) return;
                    final barcode = capture.barcodes.first;
                    if (barcode.rawValue != null) {
                      final extractedUsn = AppUtils.extractUsnFromScan(barcode.rawValue!);
                      if (extractedUsn.isNotEmpty) {
                        setState(() {
                          _scanEnabled = false;
                          _usnController.text = extractedUsn;
                        });
                        _searchStudent(extractedUsn);
                      }
                    }
                  },
                ),
              if (!_scanEnabled)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF1D1A18),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_scanner, color: Color(0xFF8C857C), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Scanner Stopped',
                          style: GoogleFonts.fredoka(color: const Color(0xFFF3ECE2), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap the button below to start scanning',
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _scanEnabled = true),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Open Scanner'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6FAE8F),
                            foregroundColor: const Color(0xFF1A0D05),
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
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
                      const SizedBox(height: 6),
                      Text(
                        'Align barcode in frame',
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF2B1C15),
          padding: const EdgeInsets.all(8),
          child: Text('Scanning for Slot ${_activeSlotIndex + 1}',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        ),
        isTablet ? Expanded(child: scannerWidget) : scannerWidget,
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usnController,
                  decoration: const InputDecoration(
                      labelText: 'Or enter USN manually',
                      prefixIcon: Icon(Icons.search)),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: _searchStudent,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _searchStudent(_usnController.text),
              ),
            ],
          ),
        ),
        if (_isLoading)
          const Padding(
              padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
        TextButton.icon(
          onPressed: () => setState(() {
            _showManualFormForActiveSlot = true;
            _manualUsnController.text = _usnController.text;
          }),
          icon: const Icon(Icons.edit),
          label: const Text('Enter Details Manually'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Manual Entry for Slot ${_activeSlotIndex + 1}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF3ECE2))),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showManualFormForActiveSlot = false),
                icon: Icon(Icons.qr_code_scanner, color: Theme.of(context).colorScheme.primary),
                label: Text('Back to Scanner', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _manualUsnController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'USN (Required)', prefixIcon: Icon(Icons.badge)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _manualNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Full Name (Required)',
                prefixIcon: Icon(Icons.person)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _manualBranch,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: _branches
                      .map((b) => DropdownMenuItem(
                            value: b,
                            child: Text(
                              b,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _manualBranch = v ?? 'CS'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _manualYear,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: [1, 2, 3, 4]
                      .map((y) => DropdownMenuItem(
                            value: y,
                            child: Text(
                              '$y Year',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _manualYear = v ?? 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _manualSection,
            decoration: const InputDecoration(labelText: 'Section'),
            items: ['A', 'B', 'C', 'D']
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        'Section $s',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _manualSection = v ?? 'A'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _manualPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Phone Number (Optional)',
                prefixIcon: Icon(Icons.phone)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _manualEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'Email Address (Optional)',
                prefixIcon: Icon(Icons.email)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveManualStudent,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF1A0D05)))
                  : const Icon(Icons.check),
              label: const Text('Save Participant'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.r.isTablet;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Unified Registration Panel', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
      ),
      body: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
    );
  }
}
