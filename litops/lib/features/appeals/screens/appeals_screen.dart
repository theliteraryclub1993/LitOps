import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/utils/app_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class AppealsScreen extends ConsumerStatefulWidget {
  const AppealsScreen({super.key});
  @override
  ConsumerState<AppealsScreen> createState() => _AppealsScreenState();
}

class _AppealsScreenState extends ConsumerState<AppealsScreen> {
  List<Appeal> _appeals = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadAppeals(); }

  Future<void> _loadAppeals() async {
    setState(() => _loading = true);
    final data = await SupabaseConfig.client.from(SupabaseTables.appeals).select().order('submitted_at', ascending: false);
    setState(() { _appeals = (data as List).map((a) => Appeal.fromJson(a)).toList(); _loading = false; });
  }

  Future<void> _updateStatus(Appeal appeal, AppealStatus status) async {
    final profile = ref.read(currentProfileProvider);
    await SupabaseConfig.client.from(SupabaseTables.appeals).update({
      'status': status.value, 'resolved_at': DateTime.now().toIso8601String(), 'resolved_by': profile!.id,
    }).eq('id', appeal.id);
    _loadAppeals();
  }

  Future<void> _showRaiseAppealSheet() async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;

    setState(() => _loading = true);
    List<Map<String, dynamic>> events = [];
    try {
      final eventsData = await SupabaseConfig.client
          .from(SupabaseTables.events)
          .select('id, title')
          .order('title');
      events = List<Map<String, dynamic>>.from(eventsData as List);
    } catch (e) {
      debugPrint('Error loading events for appeals: $e');
    } finally {
      setState(() => _loading = false);
    }

    if (!mounted) return;

    if (events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No events found to raise an appeal for.')),
      );
      return;
    }

    Map<String, dynamic>? selectedEvent = events.first;
    AppealType selectedType = AppealType.scoreDispute;
    final descCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1A18), // clay
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final r = Responsive(ctx);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + r.bottomSafeArea + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Raise an Appeal',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF3ECE2), // bone
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF8C857C)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Event',
                  style: TextStyle(color: Color(0xFF8C857C), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<Map<String, dynamic>>(
                  dropdownColor: const Color(0xFF262220), // clay-2
                  initialValue: selectedEvent,
                  style: const TextStyle(color: Color(0xFFF3ECE2)),
                  decoration: const InputDecoration(
                    fillColor: Color(0xFF262220),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: events
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e['title'] ?? ''),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => selectedEvent = v),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Appeal Type',
                  style: TextStyle(color: Color(0xFF8C857C), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<AppealType>(
                  dropdownColor: const Color(0xFF262220),
                  initialValue: selectedType,
                  style: const TextStyle(color: Color(0xFFF3ECE2)),
                  decoration: const InputDecoration(
                    fillColor: Color(0xFF262220),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: AppealType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => selectedType = v!),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Describe the Issue',
                  style: TextStyle(color: Color(0xFF8C857C), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Color(0xFFF3ECE2)),
                  decoration: const InputDecoration(
                    fillColor: Color(0xFF262220),
                    hintText: 'Enter details of the dispute or issue...',
                    hintStyle: TextStyle(color: Color(0xFF8C857C)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A2C), // ember
                      foregroundColor: const Color(0xFF1A0D05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: submitting
                        ? null
                        : () async {
                            if (selectedEvent == null || descCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Please select an event and describe the issue')),
                              );
                              return;
                            }
                            setS(() => submitting = true);
                            try {
                              String? studentId;
                              if (profile.usn != null) {
                                final stData = await SupabaseConfig.client
                                    .from(SupabaseTables.studentMaster)
                                    .select('id')
                                    .eq('usn', profile.usn!)
                                    .maybeSingle();
                                if (stData != null) studentId = stData['id'];
                              }
                              if (studentId == null) {
                                final stData = await SupabaseConfig.client
                                    .from(SupabaseTables.studentMaster)
                                    .select('id')
                                    .eq('email', profile.email)
                                    .maybeSingle();
                                if (stData != null) studentId = stData['id'];
                              }
                              if (studentId == null) {
                                final firstSt = await SupabaseConfig.client
                                    .from(SupabaseTables.studentMaster)
                                    .select('id')
                                    .limit(1)
                                    .maybeSingle();
                                studentId = firstSt?['id'];
                              }

                              if (studentId == null) {
                                throw Exception('No student record found in database to link appeal.');
                              }

                              await SupabaseConfig.client.from(SupabaseTables.appeals).insert({
                                'event_id': selectedEvent!['id'],
                                'student_id': studentId,
                                'appeal_type': selectedType.value,
                                'description': descCtrl.text.trim(),
                                'status': AppealStatus.submitted.value,
                              });

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Appeal raised successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pop(ctx);
                                _loadAppeals();
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Submission error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              setS(() => submitting = false);
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Color(0xFF1A0D05), strokeWidth: 2),
                          )
                        : const Text('Submit Appeal', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Appeals & Protests', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const LoadingView()
          : _appeals.isEmpty
              ? EmptyView(
                  icon: Icons.gavel_outlined,
                  title: 'No appeals found',
                  subtitle: 'Have a dispute? Raise an appeal below.',
                  action: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6A2C)),
                    onPressed: _showRaiseAppealSheet,
                    icon: const Icon(Icons.add_alert_rounded),
                    label: const Text('Raise an Appeal'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAppeals,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _appeals.length,
                          itemBuilder: (ctx, i) {
                            final a = _appeals[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        StatusChip(label: a.status.label),
                                        const SizedBox(width: 8),
                                        Text(a.appealType.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(a.description),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppUtils.formatTimeAgo(a.submittedAt),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    if (role.canViewAppeals && a.status != AppealStatus.resolved) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _updateStatus(a, AppealStatus.underReview),
                                            child: const Text('Review'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () => _updateStatus(a, AppealStatus.resolved),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                            child: const Text('Resolve'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: context.r.listBottomPadding),
                        child: InkWell(
                          onTap: _showRaiseAppealSheet,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFF6A2C).withValues(alpha: 0.4),
                                style: BorderStyle.solid,
                                width: 1.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.flag_rounded, color: Color(0xFFFFB14D), size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Raise an Appeal',
                                  style: TextStyle(
                                    color: Color(0xFFFFB14D),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

