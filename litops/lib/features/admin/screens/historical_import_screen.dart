import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import '../../admin/services/import_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../students/providers/student_providers.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/models/models.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';

class HistoricalImportScreen extends ConsumerStatefulWidget {
  const HistoricalImportScreen({super.key});

  @override
  ConsumerState<HistoricalImportScreen> createState() => _HistoricalImportScreenState();
}

class _HistoricalImportScreenState extends ConsumerState<HistoricalImportScreen> {
  final _importService = ImportService();
  final _yearCtrl = TextEditingController();
  
  bool _isValidating = false;
  bool _isImporting = false;
  
  String? _loadedFileName;
  String? _loadedFileType;
  List<int>? _loadedBytes;
  
  ImportValidationResult? _validationResult;
  String? _validationError;
  
  String? _activeBatchId;
  int _processedCount = 0;
  int _insertedCount = 0;
  int _updatedCount = 0;
  int _skippedCount = 0;
  double _importPercent = 0.0;
  
  String _duplicateMode = 'skip'; // Default duplicate mode: skip
  
  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  // Load a file using file picker
  Future<void> _pickFile() async {
    if (_isImporting || _isValidating) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result == null) return;

    PlatformFile file = result.files.first;
    final ext = file.extension?.toLowerCase();
    
    try {
      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        throw Exception('Could not read file contents.');
      }

      setState(() {
        _loadedFileName = file.name;
        _loadedFileType = (ext == 'xlsx' || ext == 'xls') ? 'excel' : 'csv';
        _loadedBytes = bytes;
        _validationResult = null;
        _validationError = null;
        _yearCtrl.clear();
      });

      // Try to auto-detect academic year from filename
      final nameMatch = RegExp(r'(\d{4})[-_](\d{2,4})').firstMatch(file.name);
      if (nameMatch != null) {
        final start = nameMatch.group(1)!;
        var end = nameMatch.group(2)!;
        if (end.length == 4) end = end.substring(2);
        setState(() {
          _yearCtrl.text = '$start-$end';
        });
      }

      // Auto-run validation
      _runValidation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Execute Pre-Import Validation
  Future<void> _runValidation() async {
    if (_loadedBytes == null) return;
    
    setState(() {
      _isValidating = true;
      _validationResult = null;
      _validationError = null;
    });

    try {
      final report = await _importService.validateStudentFile(
        bytes: _loadedBytes!,
        fileType: _loadedFileType!,
        fileName: _loadedFileName!,
      );

      setState(() {
        _isValidating = false;
        _validationResult = report;
        if (report.detectedAcademicYear != null && _yearCtrl.text.isEmpty) {
          _yearCtrl.text = report.detectedAcademicYear!;
        }
      });
    } catch (e) {
      setState(() {
        _isValidating = false;
        _validationError = e.toString();
      });
    }
  }

  // Create batch and run the import chunked task
  Future<void> _startImport() async {
    if (_validationResult == null || _validationResult!.validRecords.isEmpty) return;
    
    final acadYear = _yearCtrl.text.trim();
    if (acadYear.isEmpty || !RegExp(r'^\d{4}-\d{2}$').hasMatch(acadYear)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Academic Year format (e.g. 2026-27).'), backgroundColor: Colors.orange),
      );
      return;
    }

    final user = ref.read(currentProfileProvider);
    final userId = user?.id ?? '';

    setState(() {
      _isImporting = true;
      _processedCount = 0;
      _insertedCount = 0;
      _updatedCount = 0;
      _skippedCount = 0;
      _importPercent = 0.0;
    });

    ref.read(isImportingActiveProvider.notifier).state = true;

    try {
      // 1. Create import batch row in Supabase
      final batchId = await _importService.createImportBatch(
        fileName: _loadedFileName!,
        academicYear: acadYear,
        duplicateMode: _duplicateMode,
        totalRows: _validationResult!.validRecords.length,
        uploadedBy: userId,
      );

      setState(() {
        _activeBatchId = batchId;
      });

      // 2. Execute chunked batch import
      await _importService.executeImportJob(
        batchId: batchId,
        academicYear: acadYear,
        duplicateMode: _duplicateMode,
        records: _validationResult!.validRecords,
        onBatchProgress: (processed, inserted, updated, skipped) {
          if (mounted) {
            setState(() {
              _processedCount = processed;
              _insertedCount = inserted;
              _updatedCount = updated;
              _skippedCount = skipped;
              _importPercent = processed / _validationResult!.validRecords.length;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import job completed successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import execution failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _activeBatchId = null;
        });
      }
      ref.read(isImportingActiveProvider.notifier).state = false;
      ref.invalidate(studentMasterListProvider);
      ref.invalidate(distinctAcademicYearsProvider);
      ref.invalidate(importBatchesListProvider);
    }
  }

  // Safely delete past import history (and its loaded student records if unused)
  Future<void> _deleteImportBatch(ImportBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1A18),
        title: Text('Delete Import Batch', style: GoogleFonts.fredoka(color: Colors.redAccent)),
        content: Text('Are you sure you want to delete the import "${batch.fileName}"?\n\nThis will remove all students associated with this batch from the database.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Check if any student from this batch is registered in any active events
      final studentIdsResponse = await SupabaseConfig.client
          .from(SupabaseTables.studentMaster)
          .select('id')
          .eq('import_batch_id', batch.id);

      final List<String> studentIds = (studentIdsResponse as List).map((s) => s['id'] as String).toList();
      
      if (studentIds.isNotEmpty) {
        final registeredCountResponse = await SupabaseConfig.client
            .from(SupabaseTables.registrations)
            .select('id')
            .inFilter('student_id', studentIds)
            .eq('is_cancelled', false)
            .count(CountOption.exact);
            
        final activeRegistrations = registeredCountResponse.count;
        if (activeRegistrations > 0) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1D1A18),
                title: const Text('Deletion Blocked', style: TextStyle(color: Colors.orange)),
                content: Text('Cannot safely delete this batch. $activeRegistrations students in this import are already registered for events. Deleting them would corrupt active registrations.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
              ),
            );
          }
          return;
        }
      }

      // Safe to delete: students will cascade-delete their empty/canceled rows
      if (studentIds.isNotEmpty) {
        await SupabaseConfig.client.from(SupabaseTables.studentMaster).delete().inFilter('id', studentIds);
      }
      await SupabaseConfig.client.from('import_batches').delete().eq('id', batch.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import batch and its student records deleted successfully.'), backgroundColor: Colors.green),
        );
      }
      ref.invalidate(importBatchesListProvider);
      ref.invalidate(studentMasterListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete batch: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Export errors as a CSV file
  Future<void> _exportErrorLog(ImportValidationResult result) async {
    if (result.errors.isEmpty) return;
    try {
      final List<List<dynamic>> csvData = [
        ['Row Number', 'Validation Failure Reason']
      ];
      for (int i = 0; i < result.errors.length; i++) {
        csvData.add([i + 2, result.errors[i]]);
      }
      final csvContent = ListToCsvConverter().convert(csvData);
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/validation_errors_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvContent);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Validation errors log',
        subject: 'CSV Import Validation Errors Report',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(importBatchesListProvider);
    final userProfile = ref.watch(currentProfileProvider);
    final r = Responsive(context);

    final bool isSuperAdmin = userProfile?.role.isSuperAdmin ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Student Database Import',
          style: GoogleFonts.fredoka(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: r.sp(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upload & Settings Config Panel
            if (!_isImporting) ...[
              _buildUploadPanel(r, isSuperAdmin),
              const SizedBox(height: 16),
            ],

            // Active Import Progress Panel
            if (_isImporting) ...[
              _buildProgressPanel(r),
              const SizedBox(height: 16),
            ],

            // Historical import batch logs
            _buildHistoryTable(r, historyAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadPanel(Responsive r, bool isSuperAdmin) {
    final recordCount = _validationResult?.validRecords.length ?? 0;
    final errorCount = _validationResult?.errors.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262220), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: File picker Area
          Text(
            'Select CSV Student Database',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: r.sp(14)),
          ),
          const SizedBox(height: 12),
          
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF131110),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF262220), style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Icon(
                    _loadedFileName != null ? Icons.insert_drive_file : Icons.cloud_upload_outlined, 
                    color: Theme.of(context).primaryColor, 
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _loadedFileName ?? 'Drag & Drop CSV / Excel or Browse Files',
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 13, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  if (_loadedFileName != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Type: ${_loadedFileType?.toUpperCase()}',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFFB14D), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Row 2: Target Academic Year & Duplicate Mode
          if (_loadedBytes != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Academic Year',
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _yearCtrl,
                        style: const TextStyle(color: Color(0xFFF3ECE2), fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'e.g. 2026-27',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Duplicate Policy Selector
            Text(
              'On Duplicate USN Detection',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Radio<String>(
                  value: 'skip',
                  groupValue: _duplicateMode,
                  activeColor: Theme.of(context).primaryColor,
                  onChanged: (val) {
                    if (val != null) setState(() => _duplicateMode = val);
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _duplicateMode = 'skip'),
                    child: Text(
                      'Skip (Keep original student record)',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontSize: 12),
                    ),
                  ),
                ),
                Radio<String>(
                  value: 'replace',
                  groupValue: _duplicateMode,
                  activeColor: Theme.of(context).primaryColor,
                  onChanged: (val) {
                    if (val != null) setState(() => _duplicateMode = val);
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _duplicateMode = 'replace'),
                    child: Text(
                      'Replace (Overwrite database entry)',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Validate Button / Panel
            if (_validationResult == null && !_isValidating && _validationError == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSuperAdmin ? _runValidation : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: const Color(0xFF1A0D05),
                  ),
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text('Validate CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

            if (_isValidating)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Reading and validating file rows...', style: TextStyle(color: Color(0xFF8C857C))),
                    ],
                  ),
                ),
              ),

            if (_validationError != null) ...[
              Text(
                'Validation Error: ${_validationError!}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => setState(() {
                  _validationError = null;
                  _validationResult = null;
                }),
                child: const Text('Retry Validation'),
              ),
            ],

            // Display Validation Summary Report
            if (_validationResult != null) ...[
              const Divider(color: Color(0xFF262220)),
              const SizedBox(height: 12),
              Text(
                'Validation Summary Report:',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatLabel('Detected Year', _validationResult!.detectedAcademicYear ?? 'Not Found'),
                  _buildStatLabel('Total Students', recordCount.toString()),
                  _buildStatLabel('Departments', _validationResult!.departmentCount.toString()),
                  _buildStatLabel('Duplicates in DB', _validationResult!.duplicateCount.toString()),
                ],
              ),
              const SizedBox(height: 16),
              
              if (errorCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Found $errorCount Validation Errors',
                            style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Do not partially import files with errors. Correct the issues in the CSV sheet first.',
                        style: TextStyle(color: Color(0xFF8C857C), fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _exportErrorLog(_validationResult!),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                        icon: const Icon(Icons.download, size: 14, color: Colors.redAccent),
                        label: const Text('Download Errors Report', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Card(
                  color: Color(0xFF131110),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All rows validated successfully. Ready for import.',
                            style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _validationResult = null;
                            _loadedBytes = null;
                            _loadedFileName = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF262220))),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C857C))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSuperAdmin ? _startImport : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Import Database', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildProgressPanel(Responsive r) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262220), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)),
              const SizedBox(width: 12),
              Text(
                'Import in Progress...',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _importPercent,
            backgroundColor: const Color(0xFF131110),
            color: Colors.green,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_processedCount of ${_validationResult?.validRecords.length ?? 0} students processed',
                style: const TextStyle(color: Color(0xFF8C857C), fontSize: 12),
              ),
              Text(
                '${(_importPercent * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF262220)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniMetric('Inserted', _insertedCount.toString(), Colors.green),
              _buildMiniMetric('Updated', _updatedCount.toString(), Colors.blue),
              _buildMiniMetric('Skipped', _skippedCount.toString(), Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTable(Responsive r, AsyncValue<List<ImportBatch>> historyAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262220), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import History',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: r.sp(14)),
          ),
          const SizedBox(height: 16),
          historyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error loading history: $err', style: const TextStyle(color: Colors.redAccent)),
            data: (batches) {
              if (batches.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text('No previous imports recorded.', style: TextStyle(color: Color(0xFF8C857C), fontSize: 12)),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: batches.length,
                separatorBuilder: (_, __) => const Divider(color: Color(0xFF262220)),
                itemBuilder: (ctx, i) {
                  final b = batches[i];
                  final isFailed = b.status == 'failed';
                  final isCompleted = b.status == 'completed';
                  
                  final dateStr = b.createdAt.toLocal().toString().substring(0, 16);

                  return Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        b.fileName,
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Date: $dateStr • Year: ${b.academicYear}',
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 11),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isFailed 
                              ? Colors.redAccent.withValues(alpha: 0.1) 
                              : isCompleted 
                                  ? Colors.green.withValues(alpha: 0.1) 
                                  : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          b.status.toUpperCase(),
                          style: TextStyle(
                            color: isFailed 
                                ? Colors.redAccent 
                                : isCompleted 
                                    ? Colors.green 
                                    : Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatLabel('Mode', b.duplicateMode.toUpperCase()),
                                  _buildStatLabel('Total Rows', b.totalRows.toString()),
                                  _buildStatLabel('Inserted', b.insertedCount.toString()),
                                  _buildStatLabel('Updated', b.updatedCount.toString()),
                                  _buildStatLabel('Skipped', b.skippedCount.toString()),
                                ],
                              ),
                              if (b.errorLog != null && b.errorLog!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF131110),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    b.errorLog!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Delete Import Job
                                  OutlinedButton.icon(
                                    onPressed: () => _deleteImportBatch(b),
                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                                    icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                    label: const Text('Delete Import', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatLabel(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8C857C), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Color(0xFFF3ECE2), fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8C857C), fontSize: 10),
        ),
      ],
    );
  }
}
