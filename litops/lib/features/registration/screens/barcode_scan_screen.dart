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

  String _manualBranch = 'CS';
  int _manualYear = 1;
  String _manualSection = 'A';
  final List<String> _branches = [
    'CS',
    'IS',
    'CI',
    'CB',
    'RI',
    'EC',
    'VL',
    'EI',
    'EE',
    'CV',
    'ME'
  ];

  Event? _selectedEvent;
  List<Event> _events = [];
  bool _isLoading = false;
  bool _isRegistering = false;
  bool _scanEnabled = true;

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
      final data = await SupabaseConfig.client
          .from(SupabaseTables.studentMaster)
          .select()
          .ilike('usn', searchUsn)
          .eq('status', 'active')
          .maybeSingle();

      if (data != null) {
        final student = Student.fromJson(data);
        // Check if already in slots
        if (_participants.any((p) => p?.id == student.id)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Student is already in the participant list'),
                backgroundColor: Colors.orange));
          }
        } else {
          setState(() {
            _participants[_activeSlotIndex] = student;
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
      _scanEnabled = true;
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
      if (_activeSlotIndex > index ||
          _activeSlotIndex == _participants.length) {
        _activeSlotIndex = index;
      }
      _showManualFormForActiveSlot = false;
    });
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
        setState(() {
          _participants[_activeSlotIndex] = student;
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
        final teamName = "${_participants[0]!.name}'s Team";

        // Create Team
        final teamData = await SupabaseConfig.client
            .from(SupabaseTables.teams)
            .insert({
              'event_id': _selectedEvent!.id,
              'name': teamName,
              'created_by': userId,
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
            'joined_at': DateTime.now().toIso8601String(),
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

      // Success, reset the form
      setState(() {
        _initializeSlots();
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
    _usnController.dispose();
    _manualNameController.dispose();
    _manualUsnController.dispose();
    _manualPhoneController.dispose();
    _manualEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isAllFilled =
        _participants.isNotEmpty && !_participants.any((p) => p == null);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Unified Registration Panel', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
      ),
      body: Row(
        children: [
          // Left side: Scanner and Slots
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<Event>(
                    initialValue: _selectedEvent,
                    decoration:
                        const InputDecoration(labelText: 'Select Event'),
                    items: _events
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e.name)))
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
                  // Slots
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _participants.length,
                      itemBuilder: (context, index) {
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
                                ? Text(student.usn, style: const TextStyle(color: Color(0xFF8C857C)))
                                : null,
                            trailing: student != null
                                ? IconButton(
                                    icon: const Icon(Icons.close, color: Color(0xFFFF5C5C)),
                                    onPressed: () => _removeParticipant(index))
                                : null,
                            onTap: () {
                              if (student == null) {
                                  setState(() {
                                    _activeSlotIndex = index;
                                    _showManualFormForActiveSlot = false;
                                  });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isRegistering || !isAllFilled)
                            ? null
                            : _submitRegistration,
                        icon: _isRegistering
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF1A0D05), strokeWidth: 2))
                            : const Icon(Icons.check_circle),
                        label: Text(
                            _selectedEvent!.isTeamEvent
                                ? 'Register Team'
                                : 'Register Participant',
                            style: const TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              isAllFilled ? const Color(0xFF6FAE8F) : const Color(0xFF262220),
                          foregroundColor: isAllFilled ? const Color(0xFF1A0D05) : const Color(0xFF8C857C),
                        ),
                      ),
                    ),
                  )
                ] else ...[
                  const Expanded(
                      child: Center(
                          child: Text(
                              'Please select an event to start registering.',
                              style: TextStyle(color: Color(0xFF8C857C))))),
                ]
              ],
            ),
          ),

          // Right side: Scanner / Manual Entry
          if (_selectedEvent != null && _activeSlotIndex < _participants.length)
            Expanded(
              flex: 3,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Color(0xFF262220))),
                ),
                child: _showManualFormForActiveSlot
                    ? _buildManualForm()
                    : _buildScannerAndSearch(),
              ),
            ),

          if (_selectedEvent != null &&
              _activeSlotIndex >= _participants.length)
            Expanded(
                flex: 3,
                child: Container(
                  decoration: const BoxDecoration(
                    border:
                        Border(left: BorderSide(color: Color(0xFF262220))),
                  ),
                  child: const Center(
                      child: Text('All slots filled. Ready to register!',
                          style: TextStyle(fontSize: 18, color: Color(0xFF6FAE8F), fontWeight: FontWeight.bold))),
                ))
        ],
      ),
    );
  }

  Widget _buildScannerAndSearch() {
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
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              if (!_scanEnabled) return;
              final barcode = capture.barcodes.first;
              if (barcode.rawValue != null) {
                setState(() {
                  _scanEnabled = false;
                  _usnController.text = barcode.rawValue!;
                });
                _searchStudent(barcode.rawValue!);
              }
            },
          ),
        ),
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
                  initialValue: _manualBranch,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: _branches
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() => _manualBranch = v ?? 'CS'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _manualYear,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: [1, 2, 3, 4]
                      .map((y) =>
                          DropdownMenuItem(value: y, child: Text('$y Year')))
                      .toList(),
                  onChanged: (v) => setState(() => _manualYear = v ?? 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _manualSection,
            decoration: const InputDecoration(labelText: 'Section'),
            items: ['A', 'B', 'C', 'D']
                .map((s) =>
                    DropdownMenuItem(value: s, child: Text('Section $s')))
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
}
