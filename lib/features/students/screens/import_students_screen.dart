import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../auth/providers/auth_provider.dart';

class ImportStudentsScreen extends ConsumerStatefulWidget {
  const ImportStudentsScreen({super.key});
  @override
  ConsumerState<ImportStudentsScreen> createState() => _ImportStudentsScreenState();
}

class _ImportStudentsScreenState extends ConsumerState<ImportStudentsScreen> {
  List<List<dynamic>>? _previewData;
  bool _importing = false;
  int _imported = 0;
  int _failed = 0;

  Future<void> _pickCSV() async {
    // In a real app, use file_picker package
    // For now, show a dialog to paste CSV or explain the flow
    _showImportDialog();
  }

  void _showImportDialog() {
    final csvCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste CSV Data'),
        content: SizedBox(
          width: 500, height: 300,
          child: TextField(
            controller: csvCtrl,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'USN,Name,Branch,Year,Section,Phone,Email\n1MS21CS001,John Doe,CSE,1,A,9876543210,john@email.com',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _parseCSV(csvCtrl.text);
            },
            child: const Text('Preview'),
          ),
        ],
      ),
    );
  }

  void _parseCSV(String csvString) {
    try {
      final rows = const CsvToListConverter().convert(csvString, eol: '\n');
      setState(() => _previewData = rows);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Parse error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _importData() async {
    if (_previewData == null || _previewData!.length < 2) return;
    setState(() { _importing = true; _imported = 0; _failed = 0; });

    final headers = _previewData!.first.map((e) => e.toString().toLowerCase().trim()).toList();
    final rows = _previewData!.skip(1);

    for (final row in rows) {
      try {
        final map = <String, dynamic>{};
        for (int i = 0; i < headers.length && i < row.length; i++) {
          map[headers[i]] = row[i].toString().trim();
        }
        if (map['year'] != null) map['year'] = int.tryParse(map['year'].toString()) ?? 1;
        map['status'] = 'active';

        await SupabaseConfig.client.from(SupabaseTables.studentMaster).insert(map);
        _imported++;
      } catch (e) {
        _failed++;
      }
    }

    // Log import history
    final profile = ref.read(currentProfileProvider);
    if (profile != null) {
      await SupabaseConfig.client.from(SupabaseTables.databaseImportHistory).insert({
        'file_name': 'csv_paste_import',
        'file_type': 'csv',
        'total_records': rows.length,
        'successful_imports': _imported,
        'failed_imports': _failed,
        'imported_by': profile.id,
      });
    }

    setState(() => _importing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported: $_imported, Failed: $_failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Import Students', style: TextStyle(color: Color(0xFFF3ECE2), fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.upload_file, size: 48, color: Colors.blue),
                    const SizedBox(height: 12),
                    const Text('Import student data from CSV', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Expected columns: USN, Name, Branch, Year, Section, Phone, Email', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(onPressed: _pickCSV, icon: const Icon(Icons.paste), label: const Text('Paste CSV Data')),
                  ],
                ),
              ),
            ),
            if (_previewData != null) ...[
              const SizedBox(height: 16),
              Text('Preview (${_previewData!.length - 1} records)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: _previewData!.first.map((h) => DataColumn(label: Text(h.toString(), style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                    rows: _previewData!.skip(1).take(10).map((row) => DataRow(cells: row.map((c) => DataCell(Text(c.toString()))).toList())).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _importing ? null : _importData,
                  child: _importing ? const CircularProgressIndicator() : Text('Import ${_previewData!.length - 1} Students'),
                ),
              ),
              if (_imported > 0 || _failed > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Imported: $_imported | Failed: $_failed', style: TextStyle(color: _failed > 0 ? Colors.red : Colors.green)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
