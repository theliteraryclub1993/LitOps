import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/enums/enums.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/student_models.dart';
import '../providers/student_providers.dart';

class StudentDetailScreen extends ConsumerStatefulWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen> {
  bool _isSaving = false;
  bool _isDeleting = false;

  // Edit form controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _usnCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late String _branch;
  late int _year;
  late String? _section;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _usnCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _branch = 'CSE';
    _year = 1;
    _section = '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usnCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _initializeControllers(UnifiedStudent s) {
    _nameCtrl.text = s.name;
    _usnCtrl.text = s.usn;
    _phoneCtrl.text = s.phone ?? '';
    _emailCtrl.text = s.email ?? '';
    
    final inferredBranch = AppUtils.extractBranchFromUsn(s.usn);

    if (AppUtils.branches.contains(inferredBranch)) {
      _branch = inferredBranch;
    } else {
      _branch = AppUtils.mapUsnBranchToOfficial(s.branch);
    }
    // Use the DB-stored year, not the dynamically inferred one.
    _year = s.year;
    _section = s.section ?? '';
  }

  Future<void> _updateStudent(UnifiedStudent original) async {
    setState(() => _isSaving = true);
    try {
      await SupabaseConfig.client.from(SupabaseTables.studentMaster).update({
        'name': _nameCtrl.text.trim(),
        'usn': _usnCtrl.text.trim().toUpperCase(),
        'branch': _branch,
        'year': _year,
        'section': _section?.trim().isEmpty == true ? null : _section?.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', original.id);

      // Invalidate providers
      ref.invalidate(studentMasterListProvider);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student details updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update student: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteStudent(UnifiedStudent s) async {
    setState(() => _isDeleting = true);
    try {
      // Delete registration and student record (DB cascade should handle registrations)
      await SupabaseConfig.client
          .from(SupabaseTables.studentMaster)
          .delete()
          .eq('id', s.id);

      // Invalidate stream providers
      ref.invalidate(studentMasterListProvider);
      ref.invalidate(registrationsListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student record deleted successfully.')),
        );
        context.pop(); // Go back to list screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete student: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showEditDialog(UnifiedStudent s, Responsive r) {
    _initializeControllers(s);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF131324),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Edit Student Details',
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white60)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usnCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'USN', labelStyle: TextStyle(color: Colors.white60)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _branch,
                      dropdownColor: const Color(0xFF131324),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(labelText: 'Branch', labelStyle: TextStyle(color: Colors.white60)),
                      items: AppUtils.branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) => setDialogState(() => _branch = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _year,
                      dropdownColor: const Color(0xFF131324),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(labelText: 'Year', labelStyle: TextStyle(color: Colors.white60)),
                      items: AppUtils.years.map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                      onChanged: (v) => setDialogState(() => _year = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Colors.white60)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.white60)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : () => _updateStudent(s),
                  child: _isSaving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(UnifiedStudent s) {
    ConfirmDialog.show(
      context,
      title: 'Delete Student Record',
      message: 'Are you sure you want to permanently delete this student record (${s.name})? This will also remove any event registrations for this student.',
      confirmText: 'Delete',
      confirmColor: Colors.redAccent,
      onConfirm: () => _deleteStudent(s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(unifiedStudentsProvider);
    final userProfile = ref.watch(currentProfileProvider);
    final r = Responsive(context);

    // Check if the current user is an authorized admin (Super Admin, DB Manager, or President)
    final bool isAuthorizedAdmin = userProfile != null &&
        (userProfile.role.isSuperAdmin ||
            userProfile.role == UserRole.databaseManager ||
            userProfile.role == UserRole.studentPresident);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Student Details', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
        foregroundColor: const Color(0xFFF3ECE2),
      ),
      body: studentsAsync.when(
        data: (students) {
          // Find the student by ID
          final sList = students.where((student) => student.id == widget.studentId).toList();
          if (sList.isEmpty) {
            return const Center(child: Text('Student record not found.', style: TextStyle(color: Color(0xFFFF5C5C))));
          }
          final student = sList.first;

          // Fetch event registrations
          final regsAsync = ref.watch(studentRegistrationsProvider(student.id));

          // Determine edit/delete permission
          // Historical data is read-only unless user is an authorized administrator
          final bool isHistorical = student.dataSource == 'Previous Years';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning Banner for Historical Data
                if (isHistorical) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB14D).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFB14D).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFFFB14D), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isAuthorizedAdmin
                                ? 'Historical imported record from Malnad Fest ${student.festYear}. (Editable by Admin)'
                                : 'Read-only historical student record from Malnad Fest ${student.festYear}.',
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFFB14D), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Student Profile Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1A18),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF262220), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        child: Text(
                          student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                          style: GoogleFonts.plusJakartaSans(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFF3ECE2),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              student.usn,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF8C857C),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildStatusChip(student.isRegistered),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // General Information
                Text(
                  'Student Information',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C857C),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1A18),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF262220), width: 1.2),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'Department/Branch',
                        AppUtils.branches.contains(AppUtils.extractBranchFromUsn(student.usn))
                            ? AppUtils.extractBranchFromUsn(student.usn)
                            : AppUtils.mapUsnBranchToOfficial(student.branch),
                      ),
                      _buildDivider(),
                      _buildDetailRow('Study Year', 'Year ${student.year}'),
                      _buildDivider(),
                      _buildDetailRow('Academic Year', student.academicYear),
                      _buildDivider(),
                      _buildDetailRow('Data Source', student.dataSource),
                      if (student.stream != null) ...[
                        _buildDivider(),
                        _buildDetailRow('Stream', student.stream!),
                      ],
                      if (student.gender != null) ...[
                        _buildDivider(),
                        _buildDetailRow('Gender', student.gender!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Contact Details
                Text(
                  'Contact Details',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C857C),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1A18),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF262220), width: 1.2),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Mobile Number', student.phone ?? 'Not Available'),
                      _buildDivider(),
                      _buildDetailRow('Email Address', student.email ?? 'Not Available'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Event Registrations Section
                Text(
                  'Event Registrations',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C857C),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                regsAsync.when(
                  data: (regs) {
                    if (regs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1A18),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF262220), width: 1.2),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.event_busy_outlined, color: Color(0xFF8C857C), size: 36),
                            const SizedBox(height: 12),
                            Text(
                              'Not registered for any events this year.',
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: regs.length,
                      itemBuilder: (context, idx) {
                        final reg = regs[idx];
                        final eventMap = reg['events'] as Map<String, dynamic>? ?? {};
                        final teamMap = reg['teams'] as Map<String, dynamic>?;

                        final eventName = eventMap['title'] ?? 'Unknown Event';
                        final eventCategory = eventMap['category'] ?? 'General';
                        final registeredAt = reg['registered_at'] != null 
                            ? DateTime.parse(reg['registered_at'] as String) 
                            : DateTime.now();
                        final method = reg['registration_method'] ?? 'manual';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1A18),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF262220), width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      eventName,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFF3ECE2),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  _buildCategoryChip(eventCategory),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildEventDetailItem('Registration Method', RegistrationMethod.fromString(method).label),
                              _buildEventDetailItem('Registration Timestamp', AppUtils.formatDateTime(registeredAt)),
                              if (teamMap != null)
                                _buildEventDetailItem('Team Name', teamMap['team_name'] ?? 'Registered Team')
                              else
                                _buildEventDetailItem('Participation Type', 'Individual (Solo)'),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Center(child: Text('Error loading registrations: $e', style: const TextStyle(color: Color(0xFFFF5C5C)))),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingView(message: 'Loading student...'),
        error: (err, _) => ErrorView(
          message: 'Error loading student: $err',
          onRetry: () => ref.invalidate(unifiedStudentsProvider),
        ),
      ),
      bottomNavigationBar: studentsAsync.when(
        data: (students) {
          final sList = students.where((student) => student.id == widget.studentId).toList();
          if (sList.isEmpty) return const SizedBox.shrink();
          final student = sList.first;
          final bool isHistorical = student.dataSource == 'Previous Years';
          final bool canEdit = !isHistorical || isAuthorizedAdmin;

          if (!canEdit && !isAuthorizedAdmin) return const SizedBox.shrink();

          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0A0A0A),
              border: Border(top: BorderSide(color: Color(0xFF262220), width: 1.2)),
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: context.r.bottomSpacing(extra: 12, forceNavbar: true),
            ),
            child: Row(
              children: [
                if (canEdit)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showEditDialog(student, r),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: const Color(0xFF1A0D05),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Student', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (canEdit && isAuthorizedAdmin) const SizedBox(width: 12),
                if (isAuthorizedAdmin)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isDeleting ? null : () => _showDeleteConfirmation(student),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _isDeleting 
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                          : const Icon(Icons.delete_outline),
                      label: const Text('Delete Student', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 13, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEventDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 11)),
          Text(value, style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Color(0xFF262220), height: 1, thickness: 1);
  }

  Widget _buildStatusChip(bool isReg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isReg ? const Color(0xFF6FAE8F).withValues(alpha: 0.15) : const Color(0xFFFF5C5C).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReg ? const Color(0xFF6FAE8F).withValues(alpha: 0.3) : const Color(0xFFFF5C5C).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isReg ? const Color(0xFF6FAE8F) : const Color(0xFFFF5C5C),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isReg ? 'Registered' : 'Not Registered',
            style: GoogleFonts.plusJakartaSans(
              color: isReg ? const Color(0xFF6FAE8F) : const Color(0xFFFF5C5C),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String catValue) {
    final catColor = AppTheme.getCategoryColor(catValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: catColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        catValue.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: catColor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
