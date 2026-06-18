import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/import_service.dart';
import '../providers/admin_providers.dart';
import '../../auth/providers/auth_provider.dart';

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
        '4MC23CS001,Abhishek Kumar,CSE,2026,10\n'
        '4MC23CS042,Bhoomika R,CSE,2026,7\n'
        '4MC23IS015,Darshan Gowda,ISE,2026,5\n'
        '4MC23EC008,Deepika Sen,ECE,2026,0\n'
        '4MC23ME099,Chethan M,ME,2026,10\n'
        '4MC23CS999,Invalid Branch Student,XYZ,2026,0\n' // invalid branch
        '4MC23CS001,Abhishek Kumar,CSE,2026,10'; // duplicate USN

    setState(() {
      _yearCtrl.text = '2026';
      _loadedFileName = 'sample_student_archives.csv';
      _loadedFileType = 'csv';
      _loadedBytes = utf8.encode(sampleCsv);
      _validationResult = null;
    });

    _processFile();
  }

  // Load a file using file picker
  Future<void> _pickFile() async {
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
      setState(() {
        _loadedFileName = file.name;
        _loadedFileType = ext == 'csv' ? 'csv' : 'excel';
        _loadedBytes = file.bytes;
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
    
    final year = int.tryParse(_yearCtrl.text);
    if (year == null || year < 2020 || year > 2099) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid expected fest year first.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      ImportValidationResult result;
      if (_loadedFileType == 'csv') {
        result = await _importService.parseAndValidateCsv(_loadedBytes!, year);
      } else {
        result = await _importService.parseAndValidateExcel(_loadedBytes!, year);
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

      await _importService.executeImport(
        year: int.parse(_yearCtrl.text),
        fileName: _loadedFileName!,
        fileType: _loadedFileType!,
        records: _validationResult!.validRecords,
        importedBy: importedBy,
      );

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

          // Year Selection
          Text(
            'Expected Fest Year',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _yearCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Color(0xFFF3ECE2)),
            decoration: const InputDecoration(
              hintText: 'e.g. 2026',
            ),
          ),
          const SizedBox(height: 16),

          // File Picker
          Text(
            'Select CSV/Excel File',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_loadedFileName != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF262220),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF312B27)),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file, color: const Color(0xFFFFB14D), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loadedFileName!,
                      style: const TextStyle(color: Color(0xFFF3ECE2), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pickFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: const Color(0xFF1A0D05),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Select File', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),

          // Quick sample generator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Want to test immediately?',
                style: TextStyle(color: const Color(0xFF8C857C), fontSize: 12),
              ),
              TextButton.icon(
                onPressed: _loadSampleData,
                icon: const Icon(Icons.flash_on, color: Color(0xFFFFB14D), size: 16),
                label: const Text('Load Sample Data', style: TextStyle(color: Color(0xFFFFB14D), fontSize: 12)),
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
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(color: color, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8C857C), fontSize: 10),
        ),
      ],
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
            'Valid Records Preview (Up to 10 rows)',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
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
