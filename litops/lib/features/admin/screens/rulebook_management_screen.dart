import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/screens/dashboard_screen.dart';

final rulebookUploaderEmailProvider = FutureProvider.family<String?, String>((ref, userId) async {
  final data = await SupabaseConfig.client
      .from(SupabaseTables.profiles)
      .select('email')
      .eq('id', userId)
      .maybeSingle();
  return data?['email'] as String?;
});

class RulebookManagementScreen extends ConsumerStatefulWidget {
  const RulebookManagementScreen({super.key});

  @override
  ConsumerState<RulebookManagementScreen> createState() => _RulebookManagementScreenState();
}

class _RulebookManagementScreenState extends ConsumerState<RulebookManagementScreen> {
  bool _isUploading = false;

  Future<void> _uploadRulebook() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileSizeMB = file.size / (1024 * 1024);

      // 1. Hard limit check (200MB bucket limit)
      if (fileSizeMB > 200.0) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1D1A18),
              title: Text('File Too Large', style: GoogleFonts.fredoka(color: const Color(0xFFEF4444))),
              content: Text(
                'This PDF is ${fileSizeMB.toStringAsFixed(1)}MB. The maximum size limit configured for rulebooks is 200MB. Please compress the file and try again.',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE0533C))),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 2. Free Tier soft warning (50MB)
      if (fileSizeMB > 50.0) {
        final bool? proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1D1A18),
            title: Text('Large File Warning', style: GoogleFonts.fredoka(color: const Color(0xFFF59E0B))),
            content: Text(
              'This PDF is ${fileSizeMB.toStringAsFixed(1)}MB.\n\n'
              'Note: Supabase Free Tier projects have a strict upload limit of 50MB per file. '
              'If your project is on the Free Tier, this upload will fail with a "Payload Too Large" error.\n\n'
              'If you have upgraded to the Pro Plan, you can proceed. Otherwise, please compress the PDF to under 50MB.',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Upload Anyway', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1A0D05), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (proceed != true) return;
      }

      setState(() => _isUploading = true);

      final profile = ref.read(currentProfileProvider);
      if (profile == null) throw Exception('No active user session.');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'rulebook_$timestamp.pdf';

      // 3. Upload to Storage using the most memory-efficient method
      if (!kIsWeb && file.path != null) {
        // Stream the file directly from disk to prevent memory issues for large PDFs (e.g. 84MB)
        await SupabaseConfig.client.storage
            .from('rulebooks')
            .upload(
              fileName,
              File(file.path!),
              fileOptions: const supabase.FileOptions(
                contentType: 'application/pdf',
                upsert: true,
              ),
            );
      } else {
        // Fallback for Web or byte-only scenarios
        final fileBytes = file.bytes;
        if (fileBytes == null) {
          throw Exception('Could not read file bytes.');
        }
        await SupabaseConfig.client.storage
            .from('rulebooks')
            .uploadBinary(
              fileName,
              fileBytes,
              fileOptions: const supabase.FileOptions(
                contentType: 'application/pdf',
                upsert: true,
              ),
            );
      }

      // 2. Get Public URL
      final publicUrl = SupabaseConfig.client.storage
          .from('rulebooks')
          .getPublicUrl(fileName);

      // 3. Insert into Database Table
      await SupabaseConfig.client.from('rulebook').insert({
        'file_url': publicUrl,
        'uploaded_by': profile.id,
      });

      // 4. Delete Old Files in the Storage Bucket
      try {
        final List<supabase.FileObject> files = await SupabaseConfig.client.storage.from('rulebooks').list();
        final filesToDelete = files
            .map((f) => f.name)
            .where((name) => name != fileName)
            .toList();

        if (filesToDelete.isNotEmpty) {
          await SupabaseConfig.client.storage.from('rulebooks').remove(filesToDelete);
        }
      } catch (e) {
        debugPrint('Old files cleanup warning: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rulebook uploaded successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteRulebook(Rulebook rulebook) async {
    setState(() => _isUploading = true);
    try {
      // 1. Clear database metadata
      await SupabaseConfig.client.from('rulebook').delete().eq('id', rulebook.id);

      // 2. Delete all files in the bucket
      final List<supabase.FileObject> files = await SupabaseConfig.client.storage.from('rulebooks').list();
      if (files.isNotEmpty) {
        final fileNames = files.map((f) => f.name).toList();
        await SupabaseConfig.client.storage.from('rulebooks').remove(fileNames);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rulebook deleted successfully.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rulebookAsync = ref.watch(rulebookStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fest Rulebook Management'),
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: const Color(0xFFF3ECE2),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 130.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1A18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF262220), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Rulebook',
                    style: GoogleFonts.fredoka(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: LitColors.bone,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Admins can upload a single active PDF rulebook for the fest. Uploading a new PDF will overwrite and replace the previous one.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: LitColors.ash,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: rulebookAsync.when(
                data: (rulebook) {
                  if (rulebook == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined, size: 64, color: Color(0xFF262220)),
                          const SizedBox(height: 16),
                          Text(
                            'No active rulebook found',
                            style: GoogleFonts.fredoka(color: LitColors.ash, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload a PDF to get started',
                            style: GoogleFonts.plusJakartaSans(color: LitColors.ash.withValues(alpha: 0.6), fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  final uploaderEmailAsync = rulebook.uploadedBy != null
                      ? ref.watch(rulebookUploaderEmailProvider(rulebook.uploadedBy!))
                      : const AsyncValue<String?>.data(null);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF11261B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: LitColors.moss, width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.picture_as_pdf, color: LitColors.moss, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Active Rulebook PDF',
                                    style: GoogleFonts.fredoka(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: LitColors.bone,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: Color(0xFF262220)),
                            _buildInfoRow('Uploaded At', DateFormat('MMM dd, yyyy  h:mm a').format(rulebook.uploadedAt)),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              'Uploaded By',
                              uploaderEmailAsync.when(
                                data: (email) => email ?? 'Unknown',
                                loading: () => 'Loading...',
                                error: (_, __) => 'Error',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isUploading ? null : () => _deleteRulebook(rulebook),
                        icon: const Icon(Icons.delete_forever_rounded),
                        label: Text('Remove Active Rulebook', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: LitColors.ember)),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: GoogleFonts.plusJakartaSans(color: LitColors.coral),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LitColors.ember,
                foregroundColor: const Color(0xFF1A0D05),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isUploading ? null : _uploadRulebook,
              icon: _isUploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A0D05)))
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                _isUploading ? 'Uploading...' : 'Upload New Rulebook (PDF)',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: LitColors.ash)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: LitColors.bone, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
