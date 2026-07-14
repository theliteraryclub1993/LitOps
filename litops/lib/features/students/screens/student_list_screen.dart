import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/responsive.dart';
import '../providers/student_providers.dart';
import '../../admin/providers/admin_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/config/role_config.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  final _searchCtrl = TextEditingController();
  bool _isFilterExpanded = false;

  final List<String> _departments = [
    'All',
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

  final List<String> _years = ['All', '1', '2', '3', '4'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchCtrl.clear();
    ref.read(studentFilterProvider.notifier).reset();
  }

  int _getActiveFilterCount(StudentFilterState filters) {
    int count = 0;
    if (filters.academicYear != 'All') count++;
    if (filters.department != 'All') count++;
    if (filters.year != 'All') count++;
    if (filters.section != 'All') count++;
    if (filters.searchQuery.isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(studentFilterProvider);
    final paginatedAsync = ref.watch(paginatedStudentsProvider);
    final academicYearsAsync = ref.watch(distinctAcademicYearsProvider);
    final sectionsAsync = ref.watch(distinctSectionsProvider);
    final activeArchiveAsync = ref.watch(activeYearlyArchiveProvider);

    final r = Responsive(context);
    final activeArchive = activeArchiveAsync.value;
    final currentFestYear = activeArchive?.festYear ?? 2026;
    final currentAcadYear =
        '${currentFestYear - 1}-${currentFestYear.toString().substring(2)}';

    final roleConfig = ref.watch(roleConfigProvider);
    final bool isSuperAdmin = roleConfig.isSuperAdmin;

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
              ref.invalidate(distinctAcademicYearsProvider);
              ref.invalidate(distinctSectionsProvider);
            },
            tooltip: 'Refresh Database',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Filter Toggle Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) {
                      ref
                          .read(studentFilterProvider.notifier)
                          .setSearchQuery(val.trim());
                    },
                    style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF3ECE2), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by USN or Name...',
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF8C857C)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Color(0xFF8C857C)),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref
                                    .read(studentFilterProvider.notifier)
                                    .setSearchQuery('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF1D1A18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFF262220), width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFF262220), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Theme.of(context).primaryColor, width: 1.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterToggleButton(filters),
              ],
            ),
          ),

          // Expandable Filter Panel
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildFilterPanel(r, filters,
                academicYearsAsync.value ?? [], sectionsAsync.value ?? []),
            crossFadeState: _isFilterExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),

          // Filter Summary Header
          _buildResultsSummaryBanner(filters),

          // Main Student List Render (Server-Side Paginated)
          Expanded(
            child: paginatedAsync.when(
              data: (result) {
                if (result.students.isEmpty) {
                  return EmptyView(
                    icon: Icons.person_off_outlined,
                    title: 'No student records found.',
                    subtitle:
                        'Adjust your search query or clear filters to locate records.',
                  );
                }

                final studentIds = result.students.map((s) => s.id).toList();
                final registrationsAsync =
                    ref.watch(pageRegistrationsProvider(studentIds));

                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(studentMasterListProvider);
                        ref.invalidate(registrationsListProvider);
                      },
                      child: ListView.builder(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 1,
                          bottom: r.bottomSpacing(
                              extra:
                                  00), // Ensure scrollable content clears the floating pagination bar
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: result.students.length,
                        itemBuilder: (context, index) {
                          final student = result.students[index];
                          final isRegistered =
                              registrationsAsync.value?.contains(student.id) ??
                                  false;
                          final isHistorical = student.academicYear != null &&
                              student.academicYear != currentAcadYear;

                          return _buildStudentCard(student, isRegistered,
                              isHistorical, isSuperAdmin, r);
                        },
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: r.bottomSpacing(
                          extra:
                              -90), // Floating exactly above the bottom navbar
                      child: _buildPaginationFooter(filters, result.totalCount),
                    ),
                  ],
                );
              },
              loading: () =>
                  const LoadingView(message: 'Loading student records...'),
              error: (err, _) => ErrorView(
                message: 'Error loading students: $err',
                onRetry: () {
                  ref.invalidate(paginatedStudentsProvider);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggleButton(StudentFilterState filters) {
    final activeFilters = _getActiveFilterCount(filters);
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
          color: _isFilterExpanded
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : const Color(0xFF1D1A18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isFilterExpanded
                ? Theme.of(context).primaryColor
                : const Color(0xFF262220),
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
                  color: _isFilterExpanded
                      ? Theme.of(context).primaryColor
                      : const Color(0xFFF3ECE2),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Filters',
                  style: GoogleFonts.plusJakartaSans(
                    color: _isFilterExpanded
                        ? Theme.of(context).primaryColor
                        : const Color(0xFFF3ECE2),
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
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    activeFilters.toString(),
                    style: const TextStyle(
                        color: Color(0xFF1A0D05),
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
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
    StudentFilterState filters,
    List<String> academicYears,
    List<String> sections,
  ) {
    final List<String> dropdownAcademicYears = ['All'] + academicYears;
    final List<String> dropdownSections = ['All'] + sections;

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
                child: const Text('Reset All',
                    style: TextStyle(color: Color(0xFFFF5C5C), fontSize: 12)),
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
                  label: 'Academic Year',
                  value: filters.academicYear,
                  items: dropdownAcademicYears,
                  onChanged: (v) {
                    if (v != null) {
                      ref
                          .read(studentFilterProvider.notifier)
                          .setAcademicYear(v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Department
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Department/Branch',
                  value: filters.department,
                  items: _departments,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(studentFilterProvider.notifier).setDepartment(v);
                    }
                  },
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
                  value: filters.year,
                  items: _years,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(studentFilterProvider.notifier).setYear(v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Section
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Section',
                  value: filters.section,
                  items: dropdownSections,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(studentFilterProvider.notifier).setSection(v);
                    }
                  },
                ),
              ),
            ],
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
          initialValue: items.contains(value) ? value : items.first,
          onChanged: onChanged,
          isExpanded: true,
          style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF3ECE2), fontSize: 13),
          dropdownColor: const Color(0xFF1D1A18),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            return DropdownMenuItem(
              value: i,
              child: Text(i == 'All' ? 'All $label' : i),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResultsSummaryBanner(StudentFilterState filters) {
    final List<String> activeLabels = [];
    if (filters.academicYear != 'All') activeLabels.add(filters.academicYear);
    if (filters.department != 'All') activeLabels.add(filters.department);
    if (filters.year != 'All') activeLabels.add('Year ${filters.year}');
    if (filters.section != 'All')
      activeLabels.add('Section ${filters.section}');
    if (filters.searchQuery.isNotEmpty)
      activeLabels.add('Search: "${filters.searchQuery}"');

    final showingText = activeLabels.join('  •  ');

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
                'Student Database Cohort',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (_getActiveFilterCount(filters) > 0)
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Clear Filters',
                    style: TextStyle(
                        color: Color(0xFFFF5C5C),
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (showingText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              showingText,
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

  Widget _buildStudentCard(Student s, bool isRegistered, bool isHistorical,
      bool isSuperAdmin, Responsive r) {
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
                          _buildSourceBadge(isHistorical),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${s.usn} • ${s.branch} • Year ${s.year}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C857C),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Academic Year: ${s.academicYear ?? 'N/A'} • Sec ${s.section ?? 'N/A'}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C857C),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatusChip(isRegistered),
                          Row(
                            children: [
                              if (s.phone != null && s.phone!.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Icon(Icons.phone_outlined,
                                      size: 14, color: Color(0xFF8C857C)),
                                ),
                              if (s.email != null && s.email!.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Icon(Icons.mail_outline,
                                      size: 14, color: Color(0xFF8C857C)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF8C857C), size: 20),
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
        color: isReg
            ? const Color(0xFF6FAE8F).withValues(alpha: 0.15)
            : const Color(0xFFFF5C5C).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isReg
              ? const Color(0xFF6FAE8F).withValues(alpha: 0.3)
              : const Color(0xFFFF5C5C).withValues(alpha: 0.3),
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

  Widget _buildSourceBadge(bool isHistorical) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: !isHistorical
            ? const Color(0xFFFFB14D).withValues(alpha: 0.1)
            : const Color(0xFF8C857C).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: !isHistorical
              ? const Color(0xFFFFB14D).withValues(alpha: 0.3)
              : const Color(0xFF8C857C).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        !isHistorical ? 'Current' : 'Historical',
        style: GoogleFonts.plusJakartaSans(
          color:
              !isHistorical ? const Color(0xFFFFB14D) : const Color(0xFF8C857C),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(StudentFilterState filters, int totalCount) {
    final fromIndex = (filters.page - 1) * filters.pageSize + 1;
    final toIndex = (fromIndex + filters.pageSize - 1) > totalCount
        ? totalCount
        : (fromIndex + filters.pageSize - 1);

    final bool hasPrevious = filters.page > 1;
    final bool hasNext = toIndex < totalCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1A18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF262220),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            totalCount == 0
                ? 'Showing 0 students'
                : 'Showing $fromIndex-$toIndex of $totalCount',
            style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C857C),
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: hasPrevious
                    ? () => ref
                        .read(studentFilterProvider.notifier)
                        .setPage(filters.page - 1)
                    : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: hasPrevious
                          ? Theme.of(context).primaryColor
                          : const Color(0xFF262220)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text('Prev',
                    style: TextStyle(
                        color: hasPrevious
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        fontSize: 11)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: hasNext
                    ? () => ref
                        .read(studentFilterProvider.notifier)
                        .setPage(filters.page + 1)
                    : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: hasNext
                          ? Theme.of(context).primaryColor
                          : const Color(0xFF262220)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text('Next',
                    style: TextStyle(
                        color: hasNext
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
