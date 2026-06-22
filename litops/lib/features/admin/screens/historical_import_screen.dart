import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/import_service.dart';
import '../providers/admin_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class HistoricalImportScreen extends ConsumerStatefulWidget {
  const HistoricalImportScreen({super.key});

  @override
  ConsumerState<HistoricalImportScreen> createState() => _HistoricalImportScreenState();
}

class _HistoricalImportScreenState extends ConsumerState<HistoricalImportScreen> {
  final _yearCtrl = TextEditingController();
  final _importService = ImportService();

  bool _isProcessing = false;
  bool _isImporting = false;
  bool _isPreviousYearMode = false;
  
  ImportValidationResult? _validationResult;
  String? _loadedFileName;
  String? _loadedFileType;
  List<int>? _loadedBytes;

  @override
  void dispose() {
    _yearCtrl.dispose();
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
      _validationResult = null;
      _isPreviousYearMode = false;
    });

    _processFile();
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
      _validationResult = null;
      _isPreviousYearMode = true;
    });

    _processFile();
  }

  // Load a file using file picker
  Future<void> _pickFile({required bool previousYear}) async {
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

      if (bytes == null) {
        throw Exception('Could not read file bytes. The file might be empty or locked.');
      }

      setState(() {
        _isPreviousYearMode = previousYear;
        _loadedFileName = file.name;
        _loadedFileType = ext == 'csv' ? 'csv' : 'excel';
        _loadedBytes = bytes;
        _validationResult = null;
      });
      _processFile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e')),
        );
      }
    }
  }

  // Run validation checks
  Future<void> _processFile() async {
    if (_loadedBytes == null || _loadedFileType == null) return;
    
    int? year;
    if (!_isPreviousYearMode) {
      year = int.tryParse(_yearCtrl.text);
      if (year == null || year < 2020 || year > 2099) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid expected fest year first.')),
        );
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      ImportValidationResult result;
      if (_isPreviousYearMode) {
        if (_loadedFileType == 'csv') {
          result = await _importService.parseAndValidatePreviousYearCsv(_loadedBytes!);
        } else {
          result = await _importService.parseAndValidatePreviousYearExcel(_loadedBytes!);
        }
      } else {
        if (_loadedFileType == 'csv') {
          result = await _importService.parseAndValidateCsv(_loadedBytes!, year!);
        } else {
          result = await _importService.parseAndValidateExcel(_loadedBytes!, year!);
        }
      }

      setState(() {
        _validationResult = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Validation error: $e')),
      );
    }
  }

  // Run the final import
  Future<void> _executeImport() async {
    if (_validationResult == null || _validationResult!.validRecords.isEmpty) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final user = ref.read(currentProfileProvider);
      final importedBy = user?.id ?? '';

      if (_isPreviousYearMode) {
        await _importService.executePreviousYearImport(
          fileName: _loadedFileName!,
          fileType: _loadedFileType!,
          records: _validationResult!.validRecords,
          importedBy: importedBy,
        );
      } else {
        await _importService.executeImport(
          year: int.parse(_yearCtrl.text),
          fileName: _loadedFileName!,
          fileType: _loadedFileType!,
          records: _validationResult!.validRecords,
          importedBy: importedBy,
        );
      }

      // Invalidate providers
      ref.invalidate(yearlyArchivesProvider);
      ref.invalidate(departmentRankingsProvider);

      setState(() {
        _isImporting = false;
        _validationResult = null;
        _loadedBytes = null;
        _loadedFileName = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database imported and student records updated successfully!')),
      );
    } catch (e) {
      setState(() {
        _isImporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import execution failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Historical Fest Import'),
        foregroundColor: const Color(0xFFF3ECE2),
        elevation: 0,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildControlsCard(),
                  const SizedBox(height: 20),
                  
                  if (_isProcessing)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Parsing and validating data rows...', style: TextStyle(color: Color(0xFF8C857C))),
                          ],
                        ),
                      ),
                    )
                  else if (_validationResult != null) ...[
                    _buildValidationSummary(),
                    const SizedBox(height: 20),
                    _buildPreviewTable(),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
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

  Widget _buildValidationSummary() {
    final res = _validationResult!;
    final total = res.validRecords.length + res.errors.length;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Validation Metrics',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (_loadedFileName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF262220),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF312B27)),
                  ),
                  child: Text(
                    _loadedFileName!,
                    style: const TextStyle(color: Color(0xFF8C857C), fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricItem('Parsed Rows', total.toString(), const Color(0xFFFFB14D)),
              _buildMetricItem('Valid Rows', res.validRecords.length.toString(), const Color(0xFF6FAE8F)),
              _buildMetricItem('Error Rows', res.errors.length.toString(), const Color(0xFFFF5C5C)),
              _buildMetricItem('Duplicate USNs', res.duplicateCount.toString(), const Color(0xFFFFB14D)),
            ],
          ),

          // Detailed errors log if any
          if (res.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF262220)),
            const SizedBox(height: 8),
            const Text(
              'Parsing Errors Found:',
              style: TextStyle(color: Color(0xFFFF5C5C), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF262220)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(10),
                itemCount: res.errors.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      '• ${res.errors[index]}',
                      style: const TextStyle(color: Color(0xFF8C857C), fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: res.validRecords.isEmpty || _isImporting
                  ? null
                  : _executeImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6FAE8F),
                foregroundColor: const Color(0xFF1A0D05),
              ),
              child: _isImporting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A0D05)))
                  : Text('Confirm Import (${res.validRecords.length} Records)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(color: color, fontSize: 18, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8C857C), fontSize: 9),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    final records = _validationResult!.validRecords;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262220), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isPreviousYearMode ? 'Valid Records Preview (Up to 10 rows)' : 'Valid Records Preview (Up to 10 rows)',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _isPreviousYearMode
                ? DataTable(
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('Acad Year', style: TextStyle(color: Color(0xFF8C857C)))),
                      DataColumn(label: Text('USN', style: TextStyle(color: Color(0xFF8C857C)))),
                      DataColumn(label: Text('Name', style: TextStyle(color: Color(0xFF8C857C)))),
                      DataColumn(label: Text('Stream', style: TextStyle(color: Color(0xFF8C857C)))),
                      DataColumn(label: Text('Dept/Branch', style: TextStyle(color: Color(0xFF8C857C)))),
                      DataColumn(label: Text('Year', style: TextStyle(color: Color(0xFF8C857C)))),
                      DataColumn(label: Text('Email', style: TextStyle(color: Color(0xFF8C857C)))),
                      DataColumn(label: Text('Gender', style: TextStyle(color: Color(0xFF8C857C)))),
                    ],
                    rows: records.take(10).map((r) {
                      return DataRow(cells: [
                        DataCell(Text(r['academic_year'] ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                        DataCell(Text(r['usn'] ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                        DataCell(Text(r['name'] ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                        DataCell(Text(r['stream'] ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                        DataCell(Text(r['branch'] ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                        DataCell(Text(r['year']?.toString() ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                        DataCell(Text(r['email'] ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                        DataCell(Text(r['gender'] ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                      ]);
                    }).toList(),
                  )
                : DataTable(
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('USN', style: TextStyle(color: Color(0xFF8C857C)))),
                      DataColumn(label: Text('Name', style: TextStyle(color: Color(0xFF8C857C)))),
                      DataColumn(label: Text('Branch', style: TextStyle(color: Color(0xFF8C857C)))),
                      DataColumn(label: Text('Year', style: TextStyle(color: Color(0xFF8C857C)))),
                      DataColumn(label: Text('Points', style: TextStyle(color: Color(0xFF8C857C)))),
                    ],
                    rows: records.take(10).map((r) {
                      return DataRow(cells: [
                        DataCell(Text(r['usn'] ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                        DataCell(Text(r['name'] ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                        DataCell(Text(r['branch'] ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                        DataCell(Text(r['year']?.toString() ?? '', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                        DataCell(Text(r['points']?.toString() ?? '0', style: const TextStyle(color: Color(0xFFF3ECE2)))),
                      ]);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
