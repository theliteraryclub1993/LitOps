import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/app_utils.dart';
import '../models/student_models.dart';
import '../providers/student_providers.dart';
import '../../admin/providers/admin_providers.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  
  // Filter States
  bool _isFilterExpanded = false;
  String _selectedAcademicYear = 'All';
  String _selectedDepartment = 'All';
  String _selectedYear = 'All';
  String _selectedStatus = 'All';
  String _selectedSource = 'All Students';

  final List<String> _departments = [
    'All', 'CSE', 'ISE', 'CI', 'CB', 'RI', 'ECE', 'VL', 'EI', 'EE', 'CV', 'ME'
  ];
  
  final List<String> _years = ['All', '1', '2', '3', '4'];
  final List<String> _statuses = ['All', 'Registered', 'Not Registered'];
  final List<String> _sources = ['All Students', 'Current Year', 'Previous Years'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedAcademicYear = 'All';
      _selectedDepartment = 'All';
      _selectedYear = 'All';
      _selectedStatus = 'All';
      _selectedSource = 'All Students';
      _searchQuery = '';
      _searchCtrl.clear();
    });
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedAcademicYear != 'All') count++;
    if (_selectedDepartment != 'All') count++;
    if (_selectedYear != 'All') count++;
    if (_selectedStatus != 'All') count++;
    if (_selectedSource != 'All Students' && _selectedSource != 'All') count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  void _showYearwiseParticipationDialog(BuildContext context, List<UnifiedStudent> allStudents) {
    // Apply academic year, department, and source filters to get the cohort
    final cohort = allStudents.where((student) {
      // Academic Year Filter
      if (_selectedAcademicYear != 'All') {
        final studentAcadYear = student.academicYear.replaceAll('–', '-').replaceAll('—', '-').trim();
        final selectedAcadYear = _selectedAcademicYear.replaceAll('–', '-').replaceAll('—', '-').trim();
        if (studentAcadYear != selectedAcadYear) {
          return false;
        }
      }

      // Department Filter
      if (_selectedDepartment != 'All') {
        final studentBranchOfficial = AppUtils.mapUsnBranchToOfficial(student.branch);
        final selectedDeptOfficial = AppUtils.mapUsnBranchToOfficial(_selectedDepartment);
        if (studentBranchOfficial.toUpperCase() != selectedDeptOfficial.toUpperCase()) {
          return false;
        }
      }

      // Source Filter
      if (_selectedSource != 'All Students' && _selectedSource != 'All') {
        final isCurrent = _selectedSource == 'Current Year';
        final studentIsCurrent = student.dataSource == 'Current Year';
        if (studentIsCurrent != isCurrent) return false;
      }

      return true;
    }).toList();

    final totalCohort = cohort.length;
    final registeredCohort = cohort.where((s) => s.isRegistered).length;
    final overallPercentage = totalCohort > 0 ? (registeredCohort / totalCohort * 100).toStringAsFixed(1) : '0.0';

    final Map<int, int> regByYear = {1: 0, 2: 0, 3: 0, 4: 0};
    final Map<int, int> totalByYear = {1: 0, 2: 0, 3: 0, 4: 0};

    for (final s in cohort) {
      if (s.year >= 1 && s.year <= 4) {
        totalByYear[s.year] = (totalByYear[s.year] ?? 0) + 1;
        if (s.isRegistered) {
          regByYear[s.year] = (regByYear[s.year] ?? 0) + 1;
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final r = Responsive(ctx);
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1A18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF262220), width: 1.2),
          ),
          title: Text(
            'Participation Stats',
            style: GoogleFonts.fredoka(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFF3ECE2),
              fontSize: r.sp(18),
            ),
          ),
          content: SizedBox(
            width: r.screenWidth > 500 ? 420 : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Filters Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131110),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF262220)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Filters Context',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF8C857C),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dept: $_selectedDepartment  •  Year: $_selectedAcademicYear  •  Source: $_selectedSource',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF3ECE2),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Overall Stats Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6FAE8F).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF6FAE8F).withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$overallPercentage%',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF6FAE8F),
                                fontWeight: FontWeight.w800,
                                fontSize: r.sp(20),
                              ),
                            ),
                            Text(
                              'Overall Participation',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF8C857C),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$registeredCohort Registered',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFF3ECE2),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Out of $totalCohort total students matching selection',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF8C857C),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Year-wise Breakdown',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF3ECE2),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Years 1-4 List
                  ...[1, 2, 3, 4].map((yearNum) {
                    final yrReg = regByYear[yearNum] ?? 0;
                    final yrTot = totalByYear[yearNum] ?? 0;
                    final double yrPct = yrTot > 0 ? (yrReg / yrTot) : 0.0;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Year $yearNum Students',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFF3ECE2),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$yrReg / $yrTot participated (${(yrPct * 100).toStringAsFixed(1)}%)',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF8C857C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: yrPct,
                              minHeight: 8,
                              backgroundColor: const Color(0xFF131110),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                yrPct > 0.7 
                                    ? const Color(0xFF6FAE8F) 
                                    : yrPct > 0.4 
                                        ? const Color(0xFFFFB14D) 
                                        : const Color(0xFFFF6A2C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).primaryColor,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(unifiedStudentsProvider);
    final activeArchiveAsync = ref.watch(activeYearlyArchiveProvider);
    final r = Responsive(context);

    final activeArchive = activeArchiveAsync.value;
    final currentFestYear = activeArchive?.festYear ?? 2026;
    final currentAcadYear = '${currentFestYear - 1}-${currentFestYear.toString().substring(2)}';
    final prevAcadYear = '${currentFestYear - 2}-${(currentFestYear - 1).toString().substring(2)}';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Student Database',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.bold,
            color: const Color(0xFFF3ECE2),
            fontSize: r.sp(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF8C857C)),
            onPressed: () {
              ref.invalidate(studentMasterListProvider);
              ref.invalidate(registrationsListProvider);
              ref.invalidate(yearlyImportsListProvider);
            },
            tooltip: 'Refresh Database',
          ),
        ],
      ),
      body: studentsAsync.when(
        data: (students) {
          // Dynamic Academic Years list based on loaded data
          final academicYears = ['All'] + 
              (students.map((s) => s.academicYear).toSet().toList()
                ..sort((a, b) => b.compareTo(a)));

          // Calculate metrics
          final totalStudents = students.length;
          final previousYearCount = students.where((s) => s.dataSource == 'Previous Years').length;
          
          final registeredCount = students.where((s) => s.isRegistered).length;

          // Apply search and filters
          final filteredStudents = students.where((student) {
            // Search Query
            final query = _searchQuery.toLowerCase();
            final matchesQuery = query.isEmpty ||
                student.name.toLowerCase().contains(query) ||
                student.usn.toLowerCase().contains(query) ||
                student.branch.toLowerCase().contains(query) ||
                student.academicYear.toLowerCase().contains(query);

            if (!matchesQuery) return false;

            // Academic Year Filter
            if (_selectedAcademicYear != 'All') {
              final studentAcadYear = student.academicYear.replaceAll('–', '-').replaceAll('—', '-').trim();
              final selectedAcadYear = _selectedAcademicYear.replaceAll('–', '-').replaceAll('—', '-').trim();
              if (studentAcadYear != selectedAcadYear) {
                return false;
              }
            }

            // Department Filter
            if (_selectedDepartment != 'All') {
              final studentBranchOfficial = AppUtils.mapUsnBranchToOfficial(student.branch);
              final selectedDeptOfficial = AppUtils.mapUsnBranchToOfficial(_selectedDepartment);
              if (studentBranchOfficial.toUpperCase() != selectedDeptOfficial.toUpperCase()) {
                return false;
              }
            }

            // Study Year Filter
            if (_selectedYear != 'All' && student.year.toString() != _selectedYear) {
              return false;
            }

            // Status Filter
            if (_selectedStatus != 'All') {
              final isReg = _selectedStatus == 'Registered';
              if (student.isRegistered != isReg) return false;
            }

            // Source Filter
            if (_selectedSource != 'All Students' && _selectedSource != 'All') {
              final isCurrent = _selectedSource == 'Current Year';
              final studentIsCurrent = student.dataSource == 'Current Year';
              if (studentIsCurrent != isCurrent) return false;
            }

            return true;
          }).toList();

          return Column(
            children: [
              // Metrics Header Card Panel
              _buildMetricsHeader(
                r: r,
                total: totalStudents,
                registered: registeredCount,
                historical: previousYearCount,
                allStudents: students,
              ),

              // Search Bar & Filter Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search by USN, Name, Dept, Year...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF8C857C)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Color(0xFF8C857C)),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF1D1A18),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF262220), width: 1.2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF262220), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterToggleButton(r),
                  ],
                ),
              ),

              // Expandable Filter Panel
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildFilterPanel(r, academicYears, currentAcadYear, prevAcadYear),
                crossFadeState: _isFilterExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),

              // Filtered Results Summary Banner
              _buildResultsSummaryBanner(r, filteredStudents.length),

              // Students list or empty view
              Expanded(
                child: filteredStudents.isEmpty
                    ? EmptyView(
                        icon: Icons.person_off_outlined,
                        title: 'No student records found.',
                        subtitle: 'Adjust your search query or clear filters to locate records.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(studentMasterListProvider);
                          ref.invalidate(registrationsListProvider);
                          ref.invalidate(yearlyImportsListProvider);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 130),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            return _buildStudentCard(student, r);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const LoadingView(message: 'Loading student database...'),
        error: (err, _) => ErrorView(
          message: 'Error loading students: $err',
          onRetry: () {
            ref.invalidate(studentMasterListProvider);
            ref.invalidate(registrationsListProvider);
            ref.invalidate(yearlyImportsListProvider);
          },
        ),
      ),
    );
  }

  Widget _buildMetricsHeader({
    required Responsive r,
    required int total,
    required int registered,
    required int historical,
    required List<UnifiedStudent> allStudents,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Row(
        children: [
          _buildMetricCard(
            title: 'Total Students',
            value: total.toString(),
            icon: Icons.people_alt,
            color: const Color(0xFFFFB14D),
            r: r,
          ),
          const SizedBox(width: 8),
          _buildMetricCard(
            title: 'Registered',
            value: registered.toString(),
            icon: Icons.check_circle,
            color: const Color(0xFF6FAE8F),
            r: r,
            trailing: const Icon(
              Icons.analytics_outlined,
              size: 14,
              color: Color(0xFF8C857C),
            ),
            onTap: () => _showYearwiseParticipationDialog(context, allStudents),
          ),
          const SizedBox(width: 8),
          _buildMetricCard(
            title: 'Hist. Database',
            value: historical.toString(),
            icon: Icons.history_toggle_off,
            color: const Color(0xFFFF6A2C),
            r: r,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Responsive r,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1D1A18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF262220), width: 1.2),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(icon, color: color.withValues(alpha: 0.8), size: 18),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            value,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: r.sp(16),
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: 4),
                            trailing,
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C857C),
                      fontWeight: FontWeight.bold,
                      fontSize: r.sp(10),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterToggleButton(Responsive r) {
    final activeFilters = _getActiveFilterCount();
    return InkWell(
      onTap: () {
        setState(() {
          _isFilterExpanded = !_isFilterExpanded;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _isFilterExpanded ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : const Color(0xFF1D1A18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isFilterExpanded ? Theme.of(context).primaryColor : const Color(0xFF262220),
            width: 1.2,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                  color: _isFilterExpanded ? Theme.of(context).primaryColor : const Color(0xFFF3ECE2),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Filters',
                  style: GoogleFonts.plusJakartaSans(
                    color: _isFilterExpanded ? Theme.of(context).primaryColor : const Color(0xFFF3ECE2),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (activeFilters > 0)
              Positioned(
                top: -8,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    activeFilters.toString(),
                    style: const TextStyle(color: Color(0xFF1A0D05), fontSize: 9, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel(
    Responsive r, 
    List<String> academicYears,
    String currentAcadYear,
    String prevAcadYear,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              Text(
                'Filter Database',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF3ECE2),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: _resetFilters,
                child: const Text('Reset All', style: TextStyle(color: Color(0xFFFF5C5C), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dropdowns Grid
          Row(
            children: [
              // Academic Year
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Acad/Fest Year',
                  value: _selectedAcademicYear,
                  items: academicYears,
                  onChanged: (v) => setState(() => _selectedAcademicYear = v!),
                  currentAcadYear: currentAcadYear,
                  prevAcadYear: prevAcadYear,
                ),
              ),
              const SizedBox(width: 12),
              // Department
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Department',
                  value: _selectedDepartment,
                  items: _departments,
                  onChanged: (v) => setState(() => _selectedDepartment = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // Student Year
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Student Year',
                  value: _selectedYear,
                  items: _years,
                  onChanged: (v) => setState(() => _selectedYear = v!),
                ),
              ),
              const SizedBox(width: 12),
              // Registration Status
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Status',
                  value: _selectedStatus,
                  items: _statuses,
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Data Source selector
          Text(
            'Data Source',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C857C),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: _sources.map((source) {
              final isSel = _selectedSource == source;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(source, style: TextStyle(fontSize: 11, color: isSel ? const Color(0xFF1A0D05) : const Color(0xFFF3ECE2))),
                  selected: isSel,
                  onSelected: (val) {
                    setState(() {
                      _selectedSource = source;
                    });
                  },
                  selectedColor: Theme.of(context).primaryColor,
                  backgroundColor: const Color(0xFF131110),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSel ? Theme.of(context).primaryColor : const Color(0xFF262220)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? currentAcadYear,
    String? prevAcadYear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C857C),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          isExpanded: true,
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontSize: 13),
          dropdownColor: const Color(0xFF1D1A18),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: const Color(0xFF131110),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF262220)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF262220)),
            ),
          ),
          items: items.map((i) {
            String display = i;
            if (i == 'All') {
              display = label == 'Acad/Fest Year' ? 'All Years' : 'All';
            } else if (label == 'Acad/Fest Year') {
              if (i == currentAcadYear) {
                display = 'Current Year ($i)';
              } else if (i == prevAcadYear) {
                display = 'Previous Year ($i)';
              }
            }
            return DropdownMenuItem(value: i, child: Text(display));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResultsSummaryBanner(Responsive r, int count) {
    // Collect active filter labels
    final List<String> activeFilters = [];
    if (_selectedDepartment != 'All') activeFilters.add(_selectedDepartment);
    
    // Format academic year display name
    final activeArchive = ref.read(activeYearlyArchiveProvider).value;
    final currentFestYear = activeArchive?.festYear ?? 2026;
    final currentAcadYear = '${currentFestYear - 1}-${currentFestYear.toString().substring(2)}';
    final prevAcadYear = '${currentFestYear - 2}-${(currentFestYear - 1).toString().substring(2)}';
    
    String acadYearDisplay = _selectedAcademicYear;
    if (_selectedAcademicYear == 'All') {
      acadYearDisplay = 'All Years';
    } else if (_selectedAcademicYear == currentAcadYear) {
      acadYearDisplay = 'Current Year ($currentAcadYear)';
    } else if (_selectedAcademicYear == prevAcadYear) {
      acadYearDisplay = 'Previous Year ($prevAcadYear)';
    }
    activeFilters.add(acadYearDisplay);

    if (_selectedStatus != 'All') activeFilters.add(_selectedStatus);
    if (_selectedYear != 'All') activeFilters.add('Year $_selectedYear');
    if (_selectedSource != 'All Students' && _selectedSource != 'All') activeFilters.add(_selectedSource);
    if (_searchQuery.isNotEmpty) activeFilters.add('Search: "$_searchQuery"');

    final showingText = activeFilters.join('  •  ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131110),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262220)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Students: $count',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (_getActiveFilterCount() > 0)
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Clear Filters',
                    style: TextStyle(color: Color(0xFFFF5C5C), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (showingText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Showing: $showingText',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C857C),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentCard(UnifiedStudent s, Responsive r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262220), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => context.push('/students/${s.id}'),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Leading avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    style: GoogleFonts.plusJakartaSans(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Student Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFF3ECE2),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Source badge
                          _buildSourceBadge(s.dataSource),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${s.usn} • ${AppUtils.branches.contains(AppUtils.extractBranchFromUsn(s.usn)) ? AppUtils.extractBranchFromUsn(s.usn) : AppUtils.mapUsnBranchToOfficial(s.branch)} • Year ${s.year}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C857C),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Academic Year: ${s.academicYear}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C857C),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      // Status & Contact icons Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Status chip
                          _buildStatusChip(s.isRegistered),
                          
                          // Quick Contact Icons
                          Row(
                            children: [
                              if (s.phone != null && s.phone!.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Icon(Icons.phone_outlined, size: 14, color: Color(0xFF8C857C)),
                                ),
                              if (s.email != null && s.email!.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Icon(Icons.mail_outline, size: 14, color: Color(0xFF8C857C)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Color(0xFF8C857C), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isReg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isReg ? const Color(0xFF6FAE8F).withValues(alpha: 0.15) : const Color(0xFFFF5C5C).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isReg ? const Color(0xFF6FAE8F).withValues(alpha: 0.3) : const Color(0xFFFF5C5C).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isReg ? const Color(0xFF6FAE8F) : const Color(0xFFFF5C5C),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isReg ? 'Registered' : 'Not Registered',
            style: GoogleFonts.plusJakartaSans(
              color: isReg ? const Color(0xFF6FAE8F) : const Color(0xFFFF5C5C),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(String source) {
    final isCurrent = source == 'Current Year';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFFFB14D).withValues(alpha: 0.1) : const Color(0xFF8C857C).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCurrent ? const Color(0xFFFFB14D).withValues(alpha: 0.3) : const Color(0xFF8C857C).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        isCurrent ? 'Current' : 'Historical',
        style: GoogleFonts.plusJakartaSans(
          color: isCurrent ? const Color(0xFFFFB14D) : const Color(0xFF8C857C),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
