import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../admin/services/import_service.dart';
import '../../admin/providers/admin_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/student_providers.dart';

class ImportStudentsScreen extends ConsumerStatefulWidget {
  const ImportStudentsScreen({super.key});

  @override
  ConsumerState<ImportStudentsScreen> createState() => _ImportStudentsScreenState();
}

class _ImportStudentsScreenState extends ConsumerState<ImportStudentsScreen> {
  final _importService = ImportService();
  final _yearCtrl = TextEditingController(text: '2026');
  
  String? _pastedCsvString;
  List<List<dynamic>>? _previewData;

  bool _isImporting = false;
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

  void _showImportDialog() {
    final csvCtrl = TextEditingController();
    if (_pastedCsvString != null) {
      csvCtrl.text = _pastedCsvString!;
    }

    showDialog(
      context: context,
      barrierDismissible: !_isImporting,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131110),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF262220)),
        ),
        title: Text(
          'Paste CSV Data',
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 500,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Make sure to include headers in the first row.',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C857C), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: csvCtrl,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(color: Color(0xFFF3ECE2), fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'USN,Name,Branch,Year\n4MC23CS001,Abhishek Kumar,CS,3\n4MC23IS015,Darshan Gowda,IS,3',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C857C))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _parsePreview(csvCtrl.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: const Color(0xFF1A0D05),
            ),
            child: const Text('Preview Data'),
          ),
        ],
      ),
    );
  }

  void _parsePreview(String csvString) {
    if (csvString.trim().isEmpty) return;
    try {
      final rows = const CsvToListConverter().convert(csvString);
      setState(() {
        _pastedCsvString = csvString;
        _previewData = rows;
        _importSummary = null;
        _importError = null;
        _importProgress = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Parse error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _startImport() {
    if (_pastedCsvString == null || _pastedCsvString!.trim().isEmpty) return;

    final y = int.tryParse(_yearCtrl.text);
    if (y == null || y < 2020 || y > 2099) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Expected Fest Year first.')),
      );
      return;
    }

    final bytes = utf8.encode(_pastedCsvString!);
    final user = ref.read(currentProfileProvider);
    final importedBy = user?.id ?? '';

    setState(() {
      _isImporting = true;
      _importProgress = null;
      _importSummary = null;
      _importError = null;
    });

    ref.read(isImportingActiveProvider.notifier).state = true;

    _importController = _importService.importStudentsStreamed(
      bytes: bytes,
      batchSize: 500,
      isPreviousYear: false,
      expectedFestYear: y,
      importedBy: importedBy,
      fileName: 'pasted_csv_import',
      fileType: 'csv',
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
        text: 'LitOps - Paste Import Failed Rows CSV',
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
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Import Students', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
          foregroundColor: const Color(0xFFF3ECE2),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isImporting)
                _buildProgressCard()
              else if (_importSummary != null)
                _buildSummaryCard()
              else if (_importError != null)
                _buildErrorCard()
              else ...[
                _buildConfigCard(),
                if (_previewData != null && _previewData!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildPreviewCard(),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigCard() {
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
              const Icon(Icons.paste_rounded, color: Colors.blue, size: 22),
              const SizedBox(width: 8),
              Text(
                'Paste CSV Importer',
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showImportDialog,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Paste CSV Data', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final recordCount = _previewData!.length - 1;
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
            'Preview ($recordCount Rows)',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF3ECE2),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              columns: _previewData!.first
                  .map((h) => DataColumn(
                        label: Text(
                          h.toString(),
                          style: const TextStyle(color: Color(0xFF8C857C), fontWeight: FontWeight.bold),
                        ),
                      ))
                  .toList(),
              rows: _previewData!
                  .skip(1)
                  .take(10)
                  .map((row) => DataRow(
                        cells: row.map((c) => DataCell(Text(c.toString(), style: const TextStyle(color: Color(0xFFF3ECE2))))).toList(),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6FAE8F),
                foregroundColor: const Color(0xFF0F1A14),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Confirm Import ($recordCount Students)', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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
                          _pastedCsvString = null;
                          _previewData = null;
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
                  _pastedCsvString = null;
                  _previewData = null;
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
}
