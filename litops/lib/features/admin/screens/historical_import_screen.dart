import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import '../services/import_service.dart';
import '../providers/admin_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../students/providers/student_providers.dart';

class HistoricalImportScreen extends ConsumerStatefulWidget {
  const HistoricalImportScreen({super.key});

  @override
  ConsumerState<HistoricalImportScreen> createState() => _HistoricalImportScreenState();
}

class _HistoricalImportScreenState extends ConsumerState<HistoricalImportScreen> {
  final _yearCtrl = TextEditingController();
  final _importService = ImportService();

  bool _isImporting = false;
  bool _isPreviousYearMode = false;
  
  String? _loadedFileName;
  String? _loadedFileType;
  List<int>? _loadedBytes;
  String? _loadedFilePath;

  StreamedImportController? _importController;
  ImportProgress? _importProgress;
  ImportSummary? _importSummary;
  String? _importError;

  @override
  void dispose() {
    _yearCtrl.dispose();
    _importController?.cancel();
    super.dispose();
  }

  // Generate mock CSV data so the user can test the screen immediately
  void _loadSampleData() {
    const sampleCsv = 
        'usn,name,branch,year,points\n'
        '4MC23CS001,Abhishek Kumar,CS,3,10\n'
        '4MC23CS042,Bhoomika R,CS,2,7\n'
        '4MC23IS015,Darshan Gowda,IS,3,5\n'
        '4MC23EC008,Deepika Sen,EC,4,0\n'
        '4MC23ME099,Chethan M,ME,1,10\n'
        '4MC23CS999,Invalid Branch Student,XYZ,2,0\n' // invalid branch
        '4MC23CS001,Abhishek Kumar,CS,3,10'; // duplicate USN

    setState(() {
      _yearCtrl.text = '2026';
      _loadedFileName = 'sample_student_archives.csv';
      _loadedFileType = 'csv';
      _loadedBytes = utf8.encode(sampleCsv);
      _loadedFilePath = null;
      _isPreviousYearMode = false;
      _importSummary = null;
      _importError = null;
      _importProgress = null;
    });

    _startImport();
  }

  void _loadSamplePreviousYearData() {
    const sampleCsv = 
        'SL.NO,ACADEMIC YEAR,USN,STUDENT NAME,STREAM,DEPARTMENT,YEAR,EMAIL,GENDER\n'
        '1,2024-25,4MC23CS001,Abhishek Kumar,BE,CS,2,abhishek@email.com,Male\n'
        '2,2024-25,4MC23CS042,Bhoomika R,BE,CS,2,bhoomika@email.com,Female\n'
        '3,2024-25,4MC23IS015,Darshan Gowda,BE,IS,2,darshan@email.com,Male\n'
        '4,2024-25,4MC23EC008,Deepika Sen,BE,EC,2,deepika@email.com,Female\n'
        '5,2023-24,4MC22ME099,Chethan M,BE,ME,3,chethan@email.com,Male\n'
        '6,2024-25,4MC23CS999,Invalid Student,BE,XYZ,2,invalid@email.com,Male\n' // invalid branch
        '7,2024-25,4MC23CS001,Duplicate Entry,BE,CS,2,dup@email.com,Male'; // duplicate USN

    setState(() {
      _yearCtrl.clear();
      _loadedFileName = 'sample_previous_year_db.csv';
      _loadedFileType = 'csv';
      _loadedBytes = utf8.encode(sampleCsv);
      _isPreviousYearMode = true;
      _importSummary = null;
      _importError = null;
      _importProgress = null;
    });

    _startImport();
  }

  // Load a file using file picker
  Future<void> _pickFile({required bool previousYear}) async {
    if (_isImporting) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result == null) return;

    PlatformFile file = result.files.first;
    final ext = file.extension?.toLowerCase();
    if (ext != 'csv' && ext != 'xlsx' && ext != 'xls') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsupported file format. Please load a CSV or Excel file.')),
        );
      }
      return;
    }

    try {
      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null && file.path == null) {
        throw Exception('Could not read file bytes. The file might be empty or locked.');
      }

      setState(() {
        _isPreviousYearMode = previousYear;
        _loadedFileName = file.name;
        _loadedFileType = ext == 'csv' ? 'csv' : 'excel';
        _loadedBytes = bytes;
        _loadedFilePath = file.path;
        _importSummary = null;
        _importError = null;
        _importProgress = null;
      });
      
      _startImport();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e')),
        );
      }
    }
  }

  // Start the background streamed import
  void _startImport() {
    if (_loadedBytes == null && _loadedFilePath == null) return;
    
    int expectedFestYear = 2026;
    if (!_isPreviousYearMode) {
      final y = int.tryParse(_yearCtrl.text);
      if (y == null || y < 2020 || y > 2099) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid expected fest year first.')),
        );
        return;
      }
      expectedFestYear = y;
    }

    final user = ref.read(currentProfileProvider);
    final importedBy = user?.id ?? '';

    setState(() {
      _isImporting = true;
      _importProgress = null;
      _importSummary = null;
      _importError = null;
    });

    // Mark bulk import as active to silence real-time DB listeners refetch
    ref.read(isImportingActiveProvider.notifier).state = true;

    _importController = _importService.importStudentsStreamed(
      filePath: _loadedFilePath,
      bytes: _loadedBytes,
      batchSize: 500,
      isPreviousYear: _isPreviousYearMode,
      expectedFestYear: expectedFestYear,
      importedBy: importedBy,
      fileName: _loadedFileName ?? 'unknown_file',
      fileType: _loadedFileType ?? 'csv',
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _importProgress = progress;
          });
        }
      },
      onComplete: (summary) {
        if (mounted) {
          setState(() {
            _isImporting = false;
            _importSummary = summary;
          });
          
          // Disable importing state and invalidate providers
          ref.read(isImportingActiveProvider.notifier).state = false;
          ref.invalidate(studentMasterListProvider);
          ref.invalidate(yearlyImportsListProvider);
          ref.invalidate(yearlyArchivesProvider);
          ref.invalidate(departmentRankingsProvider);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import completed successfully!')),
          );
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isImporting = false;
            _importError = err.toString();
          });
          
          ref.read(isImportingActiveProvider.notifier).state = false;
          ref.invalidate(studentMasterListProvider);
          ref.invalidate(yearlyImportsListProvider);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import failed: $err')),
          );
        }
      },
    );
  }

  // Cancel the active import
  void _cancelImport() {
    if (_importController != null) {
      _importController!.cancel();
      setState(() {
        _isImporting = false;
        _importError = 'Import was cancelled by the user.';
      });
      ref.read(isImportingActiveProvider.notifier).state = false;
      ref.invalidate(studentMasterListProvider);
      ref.invalidate(yearlyImportsListProvider);
    }
  }

  // Export failed rows as CSV
  Future<void> _exportFailedRows() async {
    if (_importSummary == null || _importSummary!.failedRows.isEmpty) return;

    try {
      final List<List<dynamic>> csvData = [
        ['Row Number', 'Failure Reason']
      ];
      for (final err in _importSummary!.failedRows) {
        csvData.add([err['row'], err['reason']]);
      }

      final csvContent = const ListToCsvConverter().convert(csvData);
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/failed_rows.csv');
      await file.writeAsString(csvContent);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'LitOps - Failed Import Rows CSV',
        subject: 'Failed CSV Import Rows',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isImporting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isImporting) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot navigate back while import is in progress.')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Historical Fest Import'),
          foregroundColor: const Color(0xFFF3ECE2),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isImporting)
                _buildProgressCard()
              else if (_importSummary != null)
                _buildSummaryCard()
              else if (_importError != null)
                _buildErrorCard()
              else ...[
                _buildControlsCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final double percent = _importProgress?.percent ?? 0.0;
    final String statusMsg = _importProgress?.statusMessage ?? 'Preparing file...';
    final int processed = _importProgress?.totalProcessed ?? 0;
    final int success = _importProgress?.successCount ?? 0;
    final int updated = _importProgress?.updatedCount ?? 0;
    final int failed = _importProgress?.failedCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262220), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFB14D)),
              ),
              const SizedBox(width: 10),
              Text(
                'Importing Student Database...',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF3ECE2),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            statusMsg,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C857C),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent,
            backgroundColor: const Color(0xFF1A1715),
            color: const Color(0xFFFFB14D),
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress:',
                style: TextStyle(color: const Color(0xFF8C857C), fontSize: 12),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFFFFB14D),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF262220)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniMetric('Processed', processed.toString(), const Color(0xFFFFB14D)),
              _buildMiniMetric('New (Success)', success.toString(), const Color(0xFF6FAE8F)),
              _buildMiniMetric('Updated', updated.toString(), Colors.blue),
              _buildMiniMetric('Failed', failed.toString(), const Color(0xFFFF5C5C)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cancelImport,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF5C5C)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFF5C5C), size: 18),
              label: const Text(
                'Cancel Import',
                style: TextStyle(color: Color(0xFFFF5C5C), fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final sum = _importSummary!;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF262220), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF6FAE8F), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Import Completed',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF3ECE2),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniMetric('Total Records', sum.totalRecords.toString(), const Color(0xFFFFB14D)),
                  _buildMiniMetric('Imported (New)', sum.imported.toString(), const Color(0xFF6FAE8F)),
                  _buildMiniMetric('Updated', sum.updated.toString(), Colors.blue),
                  _buildMiniMetric('Duplicates', sum.duplicatesSkipped.toString(), Colors.orange),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniMetric('Failed Rows', sum.failed.toString(), const Color(0xFFFF5C5C)),
                  _buildMiniMetric('Time Taken', '${sum.timeTakenSeconds}s', const Color(0xFF8C857C)),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF262220)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _importSummary = null;
                          _loadedBytes = null;
                          _loadedFilePath = null;
                          _loadedFileName = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF262220),
                        foregroundColor: const Color(0xFFF3ECE2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  if (sum.failedRows.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _exportFailedRows,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6FAE8F),
                          foregroundColor: const Color(0xFF0F1A14),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Export Failed'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (sum.failedRows.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF262220), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Failed Rows Details:',
                  style: TextStyle(
                    color: Color(0xFFFF5C5C),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF262220)),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: sum.failedRows.length,
                    itemBuilder: (context, index) {
                      final item = sum.failedRows[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Row ${item['row']}: ',
                              style: const TextStyle(
                                color: Color(0xFFFFB14D),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item['reason'] ?? 'Unknown error',
                                style: const TextStyle(
                                  color: Color(0xFF8C857C),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262220), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFFF5C5C), size: 24),
              const SizedBox(width: 8),
              Text(
                'Import Interrupted',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF3ECE2),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _importError ?? 'An unexpected error occurred.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C857C),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _importError = null;
                  _loadedBytes = null;
                  _loadedFilePath = null;
                  _loadedFileName = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF262220),
                foregroundColor: const Color(0xFFF3ECE2),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Back to Configurations'),
            ),
          ),
        ],
      ),
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

  Widget _buildControlsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262220), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import Configurations',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),

          // --- SECTION 1: ACTIVE FEST YEAR IMPORT ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131110),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F1B1A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Option A: Active Year Import (Assigns Points)',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Expected Fest Year',
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _yearCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFFF3ECE2), fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 2026',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickFile(previousYear: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: const Color(0xFF1A0D05),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Select Active Year File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // --- SECTION 2: PREVIOUS YEAR STUDENT DATABASE IMPORT ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131110),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F1B1A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_toggle_off_outlined, color: Color(0xFF6FAE8F), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Option B: Previous Year Student DB Import',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Supports academic year, USN, stream, department, study year, email, and gender. Fest year is resolved automatically from the sheet columns.',
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 11),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickFile(previousYear: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6FAE8F),
                      foregroundColor: const Color(0xFF0F1A14),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.drive_folder_upload, size: 16),
                    label: const Text('Upload Previous Year DB (Excel/CSV)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          if (_loadedFileName != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF262220),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF312B27)),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, color: _isPreviousYearMode ? const Color(0xFF6FAE8F) : const Color(0xFFFFB14D), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_loadedFileName (${_isPreviousYearMode ? "Previous Year DB" : "Active Year"})',
                      style: const TextStyle(color: Color(0xFFF3ECE2), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Quick sample generators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick sample tests:',
                style: TextStyle(color: const Color(0xFF8C857C), fontSize: 11),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _loadSampleData,
                    icon: const Icon(Icons.flash_on, color: Color(0xFFFFB14D), size: 14),
                    label: const Text('Active Year', style: TextStyle(color: Color(0xFFFFB14D), fontSize: 11)),
                  ),
                  TextButton.icon(
                    onPressed: _loadSamplePreviousYearData,
                    icon: const Icon(Icons.history, color: Color(0xFF6FAE8F), size: 14),
                    label: const Text('Prev Year DB', style: TextStyle(color: Color(0xFF6FAE8F), fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
