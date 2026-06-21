import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/enums/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/admin_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

// Local provider for loading events
final adminEventsProvider = FutureProvider<List<Event>>((ref) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.events)
      .select()
      .order('title');
  return (data as List).map((e) => Event.fromJson(e)).toList();
});

class PointsManagementScreen extends ConsumerStatefulWidget {
  const PointsManagementScreen({super.key});

  @override
  ConsumerState<PointsManagementScreen> createState() => _PointsManagementScreenState();
}

class _PointsManagementScreenState extends ConsumerState<PointsManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(eventPointsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Sarvottam Point Governance'),
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: const Color(0xFFF3ECE2),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_moderator_rounded, color: Color(0xFF10B981)),
            onPressed: () => _showAllocatePointsSheet(context),
            tooltip: 'Allocate Points',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: Column(
        children: [
          // Department Rankings Summary Card
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _DepartmentRankingsPreview(),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
            child: Row(
              children: [
                Text(
                  'Point Allocations History',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Points Allocations History List
          Expanded(
            child: pointsAsync.when(
              data: (points) {
                if (points.isEmpty) {
                  return const EmptyView(
                    icon: Icons.history_rounded,
                    title: 'No point allocations found',
                    subtitle: 'Use the top-right button to award points to departments.',
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: points.length,
                  itemBuilder: (context, index) {
                    final point = points[index];
                    return _buildPointRecordCard(point);
                  },
                );
              },
              loading: () => const LoadingView(message: 'Loading point records...'),
              error: (e, _) => ErrorView(
                message: 'Failed to load point records: $e',
                onRetry: () => ref.invalidate(eventPointsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointRecordCard(EventPoint record) {
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(record.createdAt);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '+${record.points}',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF59E0B),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'PTS',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.8),
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
                    'Branch: ${record.branch}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.reason,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  if (record.position != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record.position!.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    dateStr,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: () => _confirmDeletePoints(record),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePoints(EventPoint record) {
    ConfirmDialog.show(
      context,
      title: 'Revoke Point Allocation',
      message: 'Are you sure you want to revoke ${record.points} points awarded to ${record.branch}?',
      confirmText: 'Revoke',
      confirmColor: Colors.redAccent,
      onConfirm: () async {
        try {
          await ref.read(adminControllerProvider).deleteEventPoints(record.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Point allocation revoked successfully')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to revoke points: $e')),
          );
        }
      },
    );
  }

  void _showAllocatePointsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131324),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.6,
          expand: false,
          builder: (context, scrollController) {
            return _AllocatePointsSheet(scrollController: scrollController);
          },
        );
      },
    );
  }
}

// Sub-widget for Rankings Preview
class _DepartmentRankingsPreview extends ConsumerWidget {
  const _DepartmentRankingsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingsAsync = ref.watch(departmentRankingsProvider);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Department Rankings (Live)',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.leaderboard_rounded, color: Color(0xFFF59E0B), size: 20),
            ],
          ),
          const SizedBox(height: 12),
          rankingsAsync.when(
            data: (rankings) {
              if (rankings.isEmpty) {
                return const Text(
                  'No point data recorded for the current fest.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                );
              }

              // Take top 3
              final topRankings = rankings.take(3).toList();
              return Column(
                children: List.generate(topRankings.length, (index) {
                  final rank = topRankings[index];
                  final medalColors = [
                    const Color(0xFFF59E0B), // Gold
                    const Color(0xFF94A3B8), // Silver
                    const Color(0xFFB45309), // Bronze
                  ];
                  final color = index < medalColors.length ? medalColors[index] : Colors.white54;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              rank.branch,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Text(
                          '${rank.totalPoints} pts',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
            loading: () => const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => const SizedBox(),
          ),
        ],
      ),
    );
  }
}

// Points allocation form sheet
class _AllocatePointsSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  const _AllocatePointsSheet({required this.scrollController});

  @override
  ConsumerState<_AllocatePointsSheet> createState() => _AllocatePointsSheetState();
}

class _AllocatePointsSheetState extends ConsumerState<_AllocatePointsSheet> {
  final _formKey = GlobalKey<FormState>();
  
  // Input fields
  Event? _selectedEvent;
  String? _selectedBranch;
  ResultPosition? _selectedPosition;
  final _pointsCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  
  bool _isSaving = false;

  final List<String> _branches = [
    'CS', 'IS', 'CI', 'CB', 'RI', 'EC', 'VL', 'EI', 'EE', 'CV', 'ME'
  ];

  @override
  void dispose() {
    _pointsCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  // Set default points based on result position selection
  void _onPositionChanged(ResultPosition? pos) {
    setState(() {
      _selectedPosition = pos;
      if (pos != null) {
        _pointsCtrl.text = pos.points.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(adminEventsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: ListView(
          controller: widget.scrollController,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Allocate Event Points',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Select Event
            Text(
              'Select Event',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            eventsAsync.when(
              data: (events) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<Event>(
                    initialValue: _selectedEvent,
                    dropdownColor: const Color(0xFF131324),
                    decoration: const InputDecoration(border: InputBorder.none, filled: false),
                    style: const TextStyle(color: Colors.white),
                    hint: const Text('Choose Event', style: TextStyle(color: Colors.white30)),
                    onChanged: (val) {
                      setState(() {
                        _selectedEvent = val;
                      });
                    },
                    validator: (v) => v == null ? 'Please select an event' : null,
                    items: events.map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(e.name),
                      );
                    }).toList(),
                  ),
                ),
              ),
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (e, _) => Text('Error loading events: $e', style: const TextStyle(color: Colors.redAccent)),
            ),
            const SizedBox(height: 16),

            // Select Branch
            Text(
              'Select Branch/Department',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBranch,
                  dropdownColor: const Color(0xFF131324),
                  decoration: const InputDecoration(border: InputBorder.none, filled: false),
                  style: const TextStyle(color: Colors.white),
                  hint: const Text('Choose Department', style: TextStyle(color: Colors.white30)),
                  onChanged: (val) {
                    setState(() {
                      _selectedBranch = val;
                    });
                  },
                  validator: (v) => v == null ? 'Please select a branch' : null,
                  items: _branches.map((b) {
                    return DropdownMenuItem(
                      value: b,
                      child: Text(b),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Select Position
            Text(
              'Result Position (Optional)',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButtonFormField<ResultPosition?>(
                  initialValue: _selectedPosition,
                  dropdownColor: const Color(0xFF131324),
                  decoration: const InputDecoration(border: InputBorder.none, filled: false),
                  style: const TextStyle(color: Colors.white),
                  hint: const Text('None / Custom Points', style: TextStyle(color: Colors.white30)),
                  onChanged: _onPositionChanged,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Custom Points'),
                    ),
                    ...ResultPosition.values.map((pos) {
                      return DropdownMenuItem(
                        value: pos,
                        child: Text('${pos.label} (+${pos.points} pts)'),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Enter Points
            Text(
              'Points To Award',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pointsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter points quantity...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter points value';
                final pts = int.tryParse(v);
                if (pts == null || pts <= 0) return 'Points must be a positive integer';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Enter Reason
            Text(
              'Reason / Description',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Awarded for winning Quiz, etc.',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a reason' : null,
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _isSaving = true);
                        try {
                          final user = ref.read(currentProfileProvider);
                          final allocatedBy = user?.id ?? '';

                          await ref.read(adminControllerProvider).allocateEventPoints(
                                eventId: _selectedEvent!.id,
                                branch: _selectedBranch!,
                                studentId: null, // No individual student
                                teamId: null, // No team, only branch
                                points: int.parse(_pointsCtrl.text),
                                reason: _reasonCtrl.text.trim(),
                                position: _selectedPosition,
                                allocatedBy: allocatedBy,
                              );
                          
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Points allocated successfully')),
                          );
                        } catch (e) {
                          setState(() => _isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to allocate points: $e')),
                          );
                        }
                      },
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Award Points'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
