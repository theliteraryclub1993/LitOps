import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/admin_providers.dart';
import '../../auth/providers/auth_provider.dart';

class YearlyDatabaseScreen extends ConsumerStatefulWidget {
  const YearlyDatabaseScreen({super.key});

  @override
  ConsumerState<YearlyDatabaseScreen> createState() => _YearlyDatabaseScreenState();
}

class _YearlyDatabaseScreenState extends ConsumerState<YearlyDatabaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _yearCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _yearCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final archivesAsync = ref.watch(yearlyArchivesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yearly Fest Databases'),
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: const Color(0xFFF3ECE2),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Info Card
            _buildInfoCard(),
            const SizedBox(height: 20),

            // Archives List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Archived Fests',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddYearDialog(context),
                  icon: const Icon(Icons.archive_outlined, color: Color(0xFF10B981), size: 18),
                  label: const Text('Archive New Year', style: TextStyle(color: Color(0xFF10B981))),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // List of Year Archives
            Expanded(
              child: archivesAsync.when(
                data: (archives) {
                  if (archives.isEmpty) {
                    return const EmptyView(
                      icon: Icons.auto_delete_outlined,
                      title: 'No historical years archived',
                      subtitle: 'Add a new segment or perform a CSV import to start storing records.',
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: archives.length,
                    itemBuilder: (context, index) {
                      final archive = archives[index];
                      return _buildArchiveCard(archive, archives.length);
                    },
                  );
                },
                loading: () => const LoadingView(message: 'Retrieving yearly databases...'),
                error: (e, _) => ErrorView(
                  message: 'Failed to load archives: $e',
                  onRetry: () => ref.invalidate(yearlyArchivesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF60A5FA), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Storage Constraints Enforced',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'To control database costs, Lit Life retains a maximum of 4 years of historical archives. '
                  'Attempting to add a 5th year will trigger a system protection limit.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveCard(YearlyArchive archive, int totalArchives) {
    final formattedDate = DateFormat('MMMM d, yyyy').format(archive.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        archive.festYear.toString(),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF90CAF9),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          archive.festName,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Created on $formattedDate',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  onPressed: () => _confirmDeleteArchive(archive),
                  tooltip: 'Delete Year',
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),

            // Statistics Grid inside card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Registrations', archive.totalRegistrations.toString()),
                _buildStatItem('Participants', archive.totalParticipants.toString()),
                _buildStatItem('Attendance', archive.totalAttendance.toString()),
                _buildStatItem('Events', archive.totalEvents.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white38,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  void _showAddYearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131324),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Archive Year',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _yearCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Fest Year',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter year';
                    final y = int.tryParse(v);
                    if (y == null || y < 2020 || y > 2099) return 'Enter valid year (2020-2099)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Fest Name',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            StatefulBuilder(
              builder: (context, setBtnState) {
                return ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setBtnState(() => _isSaving = true);
                          try {
                            final user = ref.read(currentProfileProvider);
                            final createdBy = user?.id ?? '';

                            await ref.read(adminControllerProvider).createYearlyArchive(
                                  year: int.parse(_yearCtrl.text),
                                  festName: _nameCtrl.text.trim(),
                                  createdBy: createdBy,
                                );
                            
                            Navigator.pop(context);
                            _yearCtrl.clear();
                            _nameCtrl.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Year archived successfully')),
                            );
                          } catch (e) {
                            String errMessage = e.toString();
                            if (errMessage.contains('Maximum storage limit reached')) {
                              _showLimitWarningDialog();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to archive: $e')),
                              );
                            }
                          } finally {
                            setBtnState(() => _isSaving = false);
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Archive'),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showLimitWarningDialog() {
    // Dismiss previous dialog first if needed, but since exception occurred during submission, the dialog is already closed or we pop it.
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131324),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Text(
                'Storage Limit Reached',
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Maximum storage limit reached (4 years). Please delete the oldest fest database before archiving a new year.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13),
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

  void _confirmDeleteArchive(YearlyArchive archive) {
    ConfirmDialog.show(
      context,
      title: 'Delete Yearly Database',
      message: 'Are you sure you want to permanently delete the database for '
          '${archive.festName} (${archive.festYear})?\n\n'
          'This will also remove all associated student records from the '
          'student database that are not referenced by other years.\n\n'
          'This action CANNOT be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.redAccent,
      onConfirm: () async {
        try {
          await ref.read(adminControllerProvider).deleteYearlyArchive(
                archive.id,
                archive.festYear,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Yearly database and associated student records deleted successfully')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete yearly database: $e')),
            );
          }
        }
      },
    );
  }
}
