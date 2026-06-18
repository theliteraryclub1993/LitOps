import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';

class ImportValidationResult {
  final List<Map<String, dynamic>> validRecords;
  final List<String> errors;
  final int duplicateCount;

  const ImportValidationResult({
    required this.validRecords,
    required this.errors,
    required this.duplicateCount,
  });
}

class ImportService {
  final List<String> _validBranches = [
    'CSE', 'ISE', 'ECE', 'EEE', 'ME', 'CIVIL', 'IPE', 'IEM', 'CH', 'MCA'
  ];

  // Parse CSV bytes and return a list of maps
  Future<ImportValidationResult> parseAndValidateCsv(
    List<int> bytes,
    int expectedYear,
  ) async {
    final csvString = utf8.decode(bytes);
    final rows = const CsvToListConverter().convert(csvString);

    if (rows.isEmpty) {
      return const ImportValidationResult(
        validRecords: [],
        errors: ['CSV file is empty.'],
        duplicateCount: 0,
      );
    }

    // Identify header row
    final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    
    // Required headers: usn, name, branch, year
    final usnIndex = headers.indexOf('usn');
    final nameIndex = headers.indexOf('name');
    final branchIndex = headers.indexOf('branch');
    final yearIndex = headers.indexOf('year');
    final pointsIndex = headers.indexOf('points'); // optional

    if (usnIndex == -1 || nameIndex == -1 || branchIndex == -1 || yearIndex == -1) {
      return ImportValidationResult(
        validRecords: [],
        errors: [
          'Missing required headers. Required columns: "usn", "name", "branch", "year". '
          'Found headers: ${rows.first.join(", ")}'
        ],
        duplicateCount: 0,
      );
    }

    final validRecords = <Map<String, dynamic>>[];
    final errors = <String>[];
    int duplicateCount = 0;

    // Fetch existing USNs from student_master for duplicate detection
    final studentMasterData = await SupabaseConfig.client
        .from(SupabaseTables.studentMaster)
        .select('usn');
    final existingUsns = (studentMasterData as List)
        .map((e) => e['usn']?.toString().toUpperCase())
        .toSet();

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= usnIndex || row.length <= nameIndex || row.length <= branchIndex) {
        errors.add('Row ${i + 1}: Incomplete column counts.');
        continue;
      }

      final usn = row[usnIndex].toString().trim().toUpperCase();
      final name = row[nameIndex].toString().trim();
      final branch = row[branchIndex].toString().trim().toUpperCase();
      final rowYearStr = row[yearIndex].toString().trim();
      final pointsStr = pointsIndex != -1 && row.length > pointsIndex
          ? row[pointsIndex].toString().trim()
          : '0';

      // Validation
      if (usn.isEmpty || name.isEmpty || branch.isEmpty) {
        errors.add('Row ${i + 1}: USN, Name, and Branch must not be empty.');
        continue;
      }

      if (usn.length < 5) {
        errors.add('Row ${i + 1}: Invalid USN format ($usn).');
        continue;
      }

      if (!_validBranches.contains(branch)) {
        errors.add('Row ${i + 1}: Invalid branch "$branch". Must be one of: ${_validBranches.join(", ")}');
        continue;
      }

      final year = int.tryParse(rowYearStr);
      if (year == null || year < 2020 || year > 2099) {
        errors.add('Row ${i + 1}: Invalid year ($rowYearStr). Must be between 2020 and 2099.');
        continue;
      }

      if (year != expectedYear) {
        errors.add('Row ${i + 1}: Year mismatch. Expected $expectedYear, found $year.');
        continue;
      }

      final points = int.tryParse(pointsStr) ?? 0;

      // Duplicate Check in batch
      if (existingUsns.contains(usn)) {
        duplicateCount++;
      }

      validRecords.add({
        'usn': usn,
        'name': name,
        'branch': branch,
        'year': year,
        'points': points,
      });
    }

    return ImportValidationResult(
      validRecords: validRecords,
      errors: errors,
      duplicateCount: duplicateCount,
    );
  }

  // Parse Excel file and validate records
  Future<ImportValidationResult> parseAndValidateExcel(
    List<int> bytes,
    int expectedYear,
  ) async {
    final excel = Excel.decodeBytes(bytes);
    final sheetName = excel.tables.keys.first;
    final table = excel.tables[sheetName];

    if (table == null || table.rows.isEmpty) {
      return const ImportValidationResult(
        validRecords: [],
        errors: ['Excel sheet is empty.'],
        duplicateCount: 0,
      );
    }

    final headers = table.rows.first.map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '').toList();

    final usnIndex = headers.indexOf('usn');
    final nameIndex = headers.indexOf('name');
    final branchIndex = headers.indexOf('branch');
    final yearIndex = headers.indexOf('year');
    final pointsIndex = headers.indexOf('points');

    if (usnIndex == -1 || nameIndex == -1 || branchIndex == -1 || yearIndex == -1) {
      return ImportValidationResult(
        validRecords: [],
        errors: [
          'Missing required headers in Excel sheet. Required: "usn", "name", "branch", "year". '
          'Found: ${headers.join(", ")}'
        ],
        duplicateCount: 0,
      );
    }

    final validRecords = <Map<String, dynamic>>[];
    final errors = <String>[];
    int duplicateCount = 0;

    final studentMasterData = await SupabaseConfig.client
        .from(SupabaseTables.studentMaster)
        .select('usn');
    final existingUsns = (studentMasterData as List)
        .map((e) => e['usn']?.toString().toUpperCase())
        .toSet();

    for (int i = 1; i < table.rows.length; i++) {
      final row = table.rows[i];
      if (row.length <= usnIndex || row.length <= nameIndex || row.length <= branchIndex) {
        errors.add('Row ${i + 1}: Incomplete column counts.');
        continue;
      }

      final usn = row[usnIndex]?.value?.toString().trim().toUpperCase() ?? '';
      final name = row[nameIndex]?.value?.toString().trim() ?? '';
      final branch = row[branchIndex]?.value?.toString().trim().toUpperCase() ?? '';
      final rowYearStr = row[yearIndex]?.value?.toString().trim() ?? '';
      final pointsStr = pointsIndex != -1 && row.length > pointsIndex
          ? row[pointsIndex]?.value?.toString().trim() ?? '0'
          : '0';

      if (usn.isEmpty || name.isEmpty || branch.isEmpty) {
        errors.add('Row ${i + 1}: USN, Name, and Branch must not be empty.');
        continue;
      }

      if (usn.length < 5) {
        errors.add('Row ${i + 1}: Invalid USN format ($usn).');
        continue;
      }

      if (!_validBranches.contains(branch)) {
        errors.add('Row ${i + 1}: Invalid branch "$branch".');
        continue;
      }

      final year = int.tryParse(rowYearStr);
      if (year == null || year < 2020 || year > 2099) {
        errors.add('Row ${i + 1}: Invalid year ($rowYearStr).');
        continue;
      }

      if (year != expectedYear) {
        errors.add('Row ${i + 1}: Year mismatch. Expected $expectedYear, found $year.');
        continue;
      }

      final points = int.tryParse(pointsStr) ?? 0;

      if (existingUsns.contains(usn)) {
        duplicateCount++;
      }

      validRecords.add({
        'usn': usn,
        'name': name,
        'branch': branch,
        'year': year,
        'points': points,
      });
    }

    return ImportValidationResult(
      validRecords: validRecords,
      errors: errors,
      duplicateCount: duplicateCount,
    );
  }

  // Confirm and save validated imports into database
  Future<void> executeImport({
    required int year,
    required String fileName,
    required String fileType,
    required List<Map<String, dynamic>> records,
    required String importedBy,
  }) async {
    // 1. Log import in yearly_imports
    final importResult = await SupabaseConfig.client.from(SupabaseTables.yearlyImports).insert({
      'fest_year': year,
      'file_name': fileName,
      'file_type': fileType,
      'total_records': records.length,
      'successful_imports': records.length,
      'failed_imports': 0,
      'imported_by': importedBy,
      'import_data': jsonEncode(records),
    }).select().single();

    // 2. Perform bulk upsert in student_master
    final bulkStudents = records.map((r) => {
      'usn': r['usn'],
      'name': r['name'],
      'branch': r['branch'],
      'year': r['year'],
      'status': 'active',
    }).toList();

    await SupabaseConfig.client.from(SupabaseTables.studentMaster).upsert(
      bulkStudents,
      onConflict: 'usn',
    );

    // 3. Increment stats or create yearly archive log if not exists
    final archiveData = await SupabaseConfig.client
        .from(SupabaseTables.yearlyArchives)
        .select()
        .eq('fest_year', year);

    if ((archiveData as List).isEmpty) {
      await SupabaseConfig.client.from(SupabaseTables.yearlyArchives).insert({
        'fest_year': year,
        'fest_name': 'Malnad Fest $year',
        'total_events': 0,
        'total_registrations': records.length,
        'total_participants': records.length,
        'total_attendance': records.length,
        'is_active': true,
        'created_by': importedBy,
      });
    } else {
      // update existing
      await SupabaseConfig.client
          .from(SupabaseTables.yearlyArchives)
          .update({
            'total_registrations': records.length,
            'total_participants': records.length,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('fest_year', year);
    }
  }
}
