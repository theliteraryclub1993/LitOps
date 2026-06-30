import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
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

class StreamedImportController {
  final void Function() _onCancel;

  StreamedImportController(this._onCancel);

  void cancel() {
    _onCancel();
  }
}

class ImportProgress {
  final int totalProcessed;
  final int successCount;
  final int updatedCount;
  final int duplicateCount;
  final int failedCount;
  final double percent;
  final String statusMessage;
  final List<Map<String, dynamic>> failedRows;

  ImportProgress({
    required this.totalProcessed,
    required this.successCount,
    required this.updatedCount,
    required this.duplicateCount,
    required this.failedCount,
    required this.percent,
    required this.statusMessage,
    required this.failedRows,
  });
}

class ImportSummary {
  final int totalRecords;
  final int imported;
  final int updated;
  final int duplicatesSkipped;
  final int failed;
  final int timeTakenSeconds;
  final List<Map<String, dynamic>> failedRows;

  ImportSummary({
    required this.totalRecords,
    required this.imported,
    required this.updated,
    required this.duplicatesSkipped,
    required this.failed,
    required this.timeTakenSeconds,
    required this.failedRows,
  });
}

class ImportService {
  final List<String> _validBranches = [
    'CSE', 'ISE', 'CI', 'CB', 'RI', 'ECE', 'VL', 'EI', 'EE', 'CV', 'ME'
  ];

  /// VTU USN format: 1 digit + 2 letters + 2 digits + 2-3 letters + 2-3 digits
  /// e.g., 4MC22CS001, 4MC23IS045, 4MC24EC110
  static final _vtuUsnRegex = RegExp(r'^\d[A-Z]{2}\d{2}[A-Z]{2,3}\d{2,3}$');

  /// Validates USN format. Returns null if valid, error message if invalid.
  String? validateUsnFormat(String usn) {
    if (usn.isEmpty) return 'USN is empty';
    if (usn.length < 5) return 'USN too short ($usn)';
    // Allow non-VTU USNs (≥5 chars, alphanumeric) but warn about format
    if (!_vtuUsnRegex.hasMatch(usn)) {
      developer.log('USN "$usn" does not match standard VTU format but will be accepted', name: 'ImportService');
    }
    return null;
  }

  Future<Set<String>> _getExistingUsns(List<String> usns) async {
    if (usns.isEmpty) return {};
    
    final existing = <String>{};
    const chunkSize = 200;
    
    for (int i = 0; i < usns.length; i += chunkSize) {
      final end = i + chunkSize > usns.length ? usns.length : i + chunkSize;
      final chunk = usns.sublist(i, end);
      try {
        final data = await SupabaseConfig.client
            .from(SupabaseTables.studentMaster)
            .select('usn')
            .inFilter('usn', chunk);
        
        for (final row in (data as List)) {
          final u = row['usn']?.toString().toUpperCase();
          if (u != null) {
            existing.add(u);
          }
        }
      } catch (e) {
        developer.log('Error checking existing USNs for chunk: $e', name: 'ImportService');
      }
    }
    
    return existing;
  }

  // Parse CSV bytes and return a list of maps.
  // IMPORTANT: The USN from each row is preserved exactly as provided.
  // The 'year' column is the student's current study year (1–4), NOT the admission year.
  // No field in the USN is ever regenerated, normalized, or overwritten.
  Future<ImportValidationResult> parseAndValidateCsv(
    List<int> bytes,
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

    int headerRowIndex = 0;
    List<String> headers = [];
    bool foundHeaders = false;

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowStrings = row.map((e) => e.toString().trim().toLowerCase()).toList();
      final hasUsn = rowStrings.any((s) => s.contains('usn'));
      final hasName = rowStrings.any((s) => s.contains('name') || s.contains('student'));

      if (hasUsn && hasName) {
        headerRowIndex = i;
        headers = rowStrings;
        foundHeaders = true;
        break;
      }
    }

    if (!foundHeaders) {
      headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    }

    final usnIndex = headers.indexWhere((h) => h.contains('usn'));
    final nameIndex = headers.indexWhere((h) => h.contains('name') || h.contains('student'));
    final branchIndex = headers.indexWhere((h) => h.contains('branch') || h.contains('dept') || h.contains('department'));
    final yearIndex = headers.indexWhere((h) => h == 'year');
    final pointsIndex = headers.indexWhere((h) => h.contains('points'));

    if (usnIndex == -1 || nameIndex == -1 || branchIndex == -1 || yearIndex == -1) {
      return ImportValidationResult(
        validRecords: [],
        errors: [
          'Missing required headers. Columns "USN", "STUDENT NAME", "DEPARTMENT" (or "BRANCH"), and "YEAR" are required. '
          'Found: ${headers.join(", ")}'
        ],
        duplicateCount: 0,
      );
    }

    final validRecords = <Map<String, dynamic>>[];
    final errors = <String>[];
    int duplicateCount = 0;
    final seenUsnsInBatch = <String>{}; // Track duplicates within the CSV itself

    for (int i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((e) => e.toString().trim().isEmpty)) {
        continue;
      }

      if (row.length <= usnIndex || row.length <= nameIndex || row.length <= branchIndex || row.length <= yearIndex) {
        errors.add('Row ${i + 1}: Incomplete column counts.');
        continue;
      }

      final usn = row[usnIndex].toString().trim().toUpperCase();
      final name = row[nameIndex].toString().trim();
      final branchRaw = row[branchIndex].toString().trim();
      final rowYearStr = row[yearIndex].toString().trim();
      final pointsStr = pointsIndex != -1 && row.length > pointsIndex
          ? row[pointsIndex].toString().trim()
          : '0';

      if (usn.isEmpty && name.isEmpty && branchRaw.isEmpty) {
        continue;
      }

      if (usn.isEmpty || name.isEmpty || branchRaw.isEmpty) {
        errors.add('Row ${i + 1}: USN, Name, and Branch must not be empty.');
        continue;
      }

      // USN format validation
      final usnError = validateUsnFormat(usn);
      if (usnError != null) {
        errors.add('Row ${i + 1}: $usnError');
        continue;
      }

      // In-batch duplicate detection
      if (seenUsnsInBatch.contains(usn)) {
        errors.add('Row ${i + 1}: Duplicate USN "$usn" within this file (already seen in an earlier row).');
        continue;
      }
      seenUsnsInBatch.add(usn);

      final branch = normalizeBranch(branchRaw);

      if (!_validBranches.contains(branch)) {
        errors.add('Row ${i + 1}: Invalid branch "$branch". Must be one of: ${_validBranches.join(", ")}');
        continue;
      }

      final year = int.tryParse(rowYearStr);
      if (year == null || year < 1 || year > 4) {
        errors.add('Row ${i + 1}: Invalid year ($rowYearStr). Must be between 1 and 4 (study year).');
        continue;
      }

      final points = int.tryParse(pointsStr) ?? 0;

      validRecords.add({
        'usn': usn,
        'name': name,
        'branch': branch,
        'year': year,
        'points': points,
      });
    }

    // Safely check duplicates against DB in chunks of 200
    final candidateUsns = validRecords.map((r) => r['usn'] as String).toList();
    final existingUsns = await _getExistingUsns(candidateUsns);
    for (final r in validRecords) {
      if (existingUsns.contains(r['usn'])) {
        duplicateCount++;
      }
    }

    return ImportValidationResult(
      validRecords: validRecords,
      errors: errors,
      duplicateCount: duplicateCount,
    );
  }

  // Parse Excel file and validate records.
  // IMPORTANT: The USN from each row is preserved exactly as provided.
  // No field in the USN is ever regenerated, normalized, or overwritten.
  Future<ImportValidationResult> parseAndValidateExcel(
    List<int> bytes,
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

    int headerRowIndex = 0;
    List<String> headers = [];
    bool foundHeaders = false;

    for (int i = 0; i < table.rows.length; i++) {
      final row = table.rows[i];
      final rowStrings = row.map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '').toList();
      final hasUsn = rowStrings.any((s) => s.contains('usn'));
      final hasName = rowStrings.any((s) => s.contains('name') || s.contains('student'));

      if (hasUsn && hasName) {
        headerRowIndex = i;
        headers = rowStrings;
        foundHeaders = true;
        break;
      }
    }

    if (!foundHeaders) {
      headers = table.rows.first.map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '').toList();
    }

    final usnIndex = headers.indexWhere((h) => h.contains('usn'));
    final nameIndex = headers.indexWhere((h) => h.contains('name') || h.contains('student'));
    final branchIndex = headers.indexWhere((h) => h.contains('branch') || h.contains('dept') || h.contains('department'));
    final yearIndex = headers.indexWhere((h) => h == 'year');
    final pointsIndex = headers.indexWhere((h) => h.contains('points'));

    if (usnIndex == -1 || nameIndex == -1 || branchIndex == -1 || yearIndex == -1) {
      return ImportValidationResult(
        validRecords: [],
        errors: [
          'Missing required headers in Excel sheet. Columns "USN", "STUDENT NAME", "DEPARTMENT" (or "BRANCH"), and "YEAR" are required. '
          'Found: ${headers.join(", ")}'
        ],
        duplicateCount: 0,
      );
    }

    final validRecords = <Map<String, dynamic>>[];
    final errors = <String>[];
    int duplicateCount = 0;
    final seenUsnsInBatch = <String>{};

    for (int i = headerRowIndex + 1; i < table.rows.length; i++) {
      final row = table.rows[i];
      if (row.isEmpty || row.every((cell) => cell?.value == null || cell!.value.toString().trim().isEmpty)) {
        continue;
      }

      if (row.length <= usnIndex || row.length <= nameIndex || row.length <= branchIndex || row.length <= yearIndex) {
        errors.add('Row ${i + 1}: Incomplete column counts.');
        continue;
      }

      final usn = row[usnIndex]?.value?.toString().trim().toUpperCase() ?? '';
      final name = row[nameIndex]?.value?.toString().trim() ?? '';
      final branchRaw = row[branchIndex]?.value?.toString().trim() ?? '';
      final rowYearStr = row[yearIndex]?.value?.toString().trim() ?? '';
      final pointsStr = pointsIndex != -1 && row.length > pointsIndex
          ? row[pointsIndex]?.value?.toString().trim() ?? '0'
          : '0';

      if (usn.isEmpty && name.isEmpty && branchRaw.isEmpty) {
        continue;
      }

      if (usn.isEmpty || name.isEmpty || branchRaw.isEmpty) {
        errors.add('Row ${i + 1}: USN, Name, and Branch must not be empty.');
        continue;
      }

      // USN format validation
      final usnError = validateUsnFormat(usn);
      if (usnError != null) {
        errors.add('Row ${i + 1}: $usnError');
        continue;
      }

      // In-batch duplicate detection
      if (seenUsnsInBatch.contains(usn)) {
        errors.add('Row ${i + 1}: Duplicate USN "$usn" within this file.');
        continue;
      }
      seenUsnsInBatch.add(usn);

      final branch = normalizeBranch(branchRaw);

      if (!_validBranches.contains(branch)) {
        errors.add('Row ${i + 1}: Invalid branch "$branch".');
        continue;
      }

      final year = int.tryParse(rowYearStr);
      if (year == null || year < 1 || year > 4) {
        errors.add('Row ${i + 1}: Invalid year ($rowYearStr). Must be between 1 and 4 (study year).');
        continue;
      }

      final points = int.tryParse(pointsStr) ?? 0;

      validRecords.add({
        'usn': usn,
        'name': name,
        'branch': branch,
        'year': year,
        'points': points,
      });
    }

    // Safely check duplicates against DB in chunks of 200
    final candidateUsns = validRecords.map((r) => r['usn'] as String).toList();
    final existingUsns = await _getExistingUsns(candidateUsns);
    for (final r in validRecords) {
      if (existingUsns.contains(r['usn'])) {
        duplicateCount++;
      }
    }

    return ImportValidationResult(
      validRecords: validRecords,
      errors: errors,
      duplicateCount: duplicateCount,
    );
  }

  // Helper to extract fest year from academic year string
  int? extractFestYear(String academicYear) {
    final regexRange = RegExp(r'(\d{4})[-/](\d{2,4})');
    final matchRange = regexRange.firstMatch(academicYear);
    if (matchRange != null) {
      final startYearStr = matchRange.group(1)!;
      final endYearStr = matchRange.group(2)!;
      if (endYearStr.length == 2) {
        final prefix = startYearStr.substring(0, 2);
        return int.tryParse('$prefix$endYearStr');
      } else {
        return int.tryParse(endYearStr);
      }
    }
    
    final regexSingle = RegExp(r'(\d{4})');
    final matchSingle = regexSingle.firstMatch(academicYear);
    if (matchSingle != null) {
      return int.tryParse(matchSingle.group(1)!);
    }
    return null;
  }

  // Normalizes branch name to standard uppercase abbreviations
  String normalizeBranch(String dept) {
    final d = dept.toUpperCase().trim();
    if (d.contains('COMPUTER SCIENCE') || d == 'CS' || d == 'CSE') {
      if (d.contains('AI') || d.contains('ML')) return 'CI';
      if (d.contains('BUSINESS') || d.contains('BS') || d.contains('CSBS')) return 'CB';
      return 'CSE';
    }
    if (d.contains('INFORMATION SCIENCE') || d == 'IS' || d == 'ISE') return 'ISE';
    if (d.contains('ELECTRONICS & COMM') || d.contains('ELECTRONICS AND COMM') || d == 'EC' || d == 'ECE') return 'ECE';
    if (d.contains('ELECTRICAL') || d == 'EE' || d == 'EEE') return 'EE';
    if (d.contains('MECHANICAL') || d == 'ME') return 'ME';
    if (d.contains('CIVIL') || d == 'CV' || d == 'CE' || d == 'CIVIL') return 'CV';
    if (d.contains('VLSI') || d == 'VL') return 'VL';
    if (d.contains('ROBOTICS') || d == 'RI' || d == 'RAI') return 'RI';
    if (d.contains('ELECTRONICS & COMPUTER') || d.contains('ELECTRONICS AND COMPUTER') || d == 'EI') return 'EI';
    if (d == 'CI' || d == 'AIML') return 'CI';
    if (d == 'CB' || d == 'CSBS') return 'CB';
    return d;
  }

  Future<ImportValidationResult> parseAndValidatePreviousYearCsv(
    List<int> bytes,
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

    int headerRowIndex = 0;
    List<String> headers = [];
    bool foundHeaders = false;

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowStrings = row.map((e) => e.toString().trim().toLowerCase()).toList();
      final hasUsn = rowStrings.any((s) => s.contains('usn'));
      final hasName = rowStrings.any((s) => s.contains('name') || s.contains('student'));

      if (hasUsn && hasName) {
        headerRowIndex = i;
        headers = rowStrings;
        foundHeaders = true;
        break;
      }
    }

    if (!foundHeaders) {
      headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    }

    final usnIndex = headers.indexWhere((h) => h.contains('usn'));
    final nameIndex = headers.indexWhere((h) => h.contains('student name') || h.contains('name'));
    final branchIndex = headers.indexWhere((h) => h.contains('department') || h.contains('dept') || h.contains('branch') || h.contains('stream'));
    final yearIndex = headers.indexWhere((h) => h == 'year');
    final academicYearIndex = headers.indexWhere((h) => h.contains('academic year') || h.contains('academic'));
    final streamIndex = headers.indexWhere((h) => h == 'stream');
    final emailIndex = headers.indexWhere((h) => h.contains('email'));
    final genderIndex = headers.indexWhere((h) => h.contains('gender'));

    if (usnIndex == -1 || nameIndex == -1 || branchIndex == -1 || yearIndex == -1 || academicYearIndex == -1) {
      return ImportValidationResult(
        validRecords: [],
        errors: [
          'Missing required headers. Columns "USN", "STUDENT NAME", "DEPARTMENT" (or "BRANCH"), "YEAR", and "ACADEMIC YEAR" are required. '
          'Found: ${headers.join(", ")}'
        ],
        duplicateCount: 0,
      );
    }

    final validRecords = <Map<String, dynamic>>[];
    final errors = <String>[];
    int duplicateCount = 0;

    for (int i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((e) => e.toString().trim().isEmpty)) {
        continue;
      }

      if (row.length <= usnIndex || row.length <= nameIndex || row.length <= branchIndex || row.length <= yearIndex || row.length <= academicYearIndex) {
        errors.add('Row ${i + 1}: Incomplete column counts.');
        continue;
      }

      final usn = row[usnIndex].toString().trim().toUpperCase();
      final name = row[nameIndex].toString().trim();
      final deptRaw = row[branchIndex].toString().trim();
      final rowYearStr = row[yearIndex].toString().trim();
      final acadYearStr = row[academicYearIndex].toString().trim();
      
      final stream = streamIndex != -1 && row.length > streamIndex ? row[streamIndex].toString().trim() : null;
      final email = emailIndex != -1 && row.length > emailIndex ? row[emailIndex].toString().trim() : null;
      final gender = genderIndex != -1 && row.length > genderIndex ? row[genderIndex].toString().trim() : null;

      if (usn.isEmpty && name.isEmpty && deptRaw.isEmpty) {
        continue;
      }

      if (usn.isEmpty || name.isEmpty || deptRaw.isEmpty || rowYearStr.isEmpty || acadYearStr.isEmpty) {
        errors.add('Row ${i + 1}: Required fields (USN, Name, Department/Branch, Year, Academic Year) must not be empty.');
        continue;
      }

      if (usn.length < 5) {
        errors.add('Row ${i + 1}: Invalid USN format ($usn).');
        continue;
      }

      final branch = normalizeBranch(deptRaw);

      final year = int.tryParse(rowYearStr);
      if (year == null || year < 1 || year > 4) {
        errors.add('Row ${i + 1}: Invalid year ($rowYearStr). Study year must be between 1 and 4.');
        continue;
      }

      final festYear = extractFestYear(acadYearStr);
      if (festYear == null || festYear < 2020 || festYear > 2099) {
        errors.add('Row ${i + 1}: Invalid Academic Year ($acadYearStr). Could not resolve a valid year.');
        continue;
      }

      validRecords.add({
        'usn': usn,
        'name': name,
        'branch': branch,
        'year': year,
        'fest_year': festYear,
        'academic_year': acadYearStr,
        'stream': stream,
        'email': email,
        'gender': gender,
        'points': 0,
      });
    }

    // Safely check duplicates against DB in chunks of 200
    final candidateUsns = validRecords.map((r) => r['usn'] as String).toList();
    final existingUsns = await _getExistingUsns(candidateUsns);
    for (final r in validRecords) {
      if (existingUsns.contains(r['usn'])) {
        duplicateCount++;
      }
    }

    return ImportValidationResult(
      validRecords: validRecords,
      errors: errors,
      duplicateCount: duplicateCount,
    );
  }

  Future<ImportValidationResult> parseAndValidatePreviousYearExcel(
    List<int> bytes,
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

    int headerRowIndex = 0;
    List<String> headers = [];
    bool foundHeaders = false;

    for (int i = 0; i < table.rows.length; i++) {
      final row = table.rows[i];
      final rowStrings = row.map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '').toList();
      final hasUsn = rowStrings.any((s) => s.contains('usn'));
      final hasName = rowStrings.any((s) => s.contains('name') || s.contains('student'));

      if (hasUsn && hasName) {
        headerRowIndex = i;
        headers = rowStrings;
        foundHeaders = true;
        break;
      }
    }

    if (!foundHeaders) {
      headers = table.rows.first.map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '').toList();
    }

    final usnIndex = headers.indexWhere((h) => h.contains('usn'));
    final nameIndex = headers.indexWhere((h) => h.contains('student name') || h.contains('name'));
    final branchIndex = headers.indexWhere((h) => h.contains('department') || h.contains('dept') || h.contains('branch') || h.contains('stream'));
    final yearIndex = headers.indexWhere((h) => h == 'year');
    final academicYearIndex = headers.indexWhere((h) => h.contains('academic year') || h.contains('academic'));
    final streamIndex = headers.indexWhere((h) => h == 'stream');
    final emailIndex = headers.indexWhere((h) => h.contains('email'));
    final genderIndex = headers.indexWhere((h) => h.contains('gender'));

    if (usnIndex == -1 || nameIndex == -1 || branchIndex == -1 || yearIndex == -1 || academicYearIndex == -1) {
      return ImportValidationResult(
        validRecords: [],
        errors: [
          'Missing required headers in Excel sheet. Columns "USN", "STUDENT NAME", "DEPARTMENT" (or "BRANCH"), "YEAR", and "ACADEMIC YEAR" are required. '
          'Found: ${headers.join(", ")}'
        ],
        duplicateCount: 0,
      );
    }

    final validRecords = <Map<String, dynamic>>[];
    final errors = <String>[];
    int duplicateCount = 0;

    for (int i = headerRowIndex + 1; i < table.rows.length; i++) {
      final row = table.rows[i];
      if (row.isEmpty || row.every((cell) => cell?.value == null || cell!.value.toString().trim().isEmpty)) {
        continue;
      }

      if (row.length <= usnIndex || row.length <= nameIndex || row.length <= branchIndex || row.length <= yearIndex || row.length <= academicYearIndex) {
        errors.add('Row ${i + 1}: Incomplete column counts.');
        continue;
      }

      final usn = row[usnIndex]?.value?.toString().trim().toUpperCase() ?? '';
      final name = row[nameIndex]?.value?.toString().trim() ?? '';
      final deptRaw = row[branchIndex]?.value?.toString().trim() ?? '';
      final rowYearStr = row[yearIndex]?.value?.toString().trim() ?? '';
      final acadYearStr = row[academicYearIndex]?.value?.toString().trim() ?? '';
      
      final stream = streamIndex != -1 && row.length > streamIndex ? row[streamIndex]?.value?.toString().trim() : null;
      final email = emailIndex != -1 && row.length > emailIndex ? row[emailIndex]?.value?.toString().trim() : null;
      final gender = genderIndex != -1 && row.length > genderIndex ? row[genderIndex]?.value?.toString().trim() : null;

      if (usn.isEmpty && name.isEmpty && deptRaw.isEmpty) {
        continue;
      }

      if (usn.isEmpty || name.isEmpty || deptRaw.isEmpty || rowYearStr.isEmpty || acadYearStr.isEmpty) {
        errors.add('Row ${i + 1}: Required fields (USN, Name, Department/Branch, Year, Academic Year) must not be empty.');
        continue;
      }

      if (usn.length < 5) {
        errors.add('Row ${i + 1}: Invalid USN format ($usn).');
        continue;
      }

      final branch = normalizeBranch(deptRaw);

      final year = int.tryParse(rowYearStr);
      if (year == null || year < 1 || year > 4) {
        errors.add('Row ${i + 1}: Invalid year ($rowYearStr). Study year must be between 1 and 4.');
        continue;
      }

      final festYear = extractFestYear(acadYearStr);
      if (festYear == null || festYear < 2020 || festYear > 2099) {
        errors.add('Row ${i + 1}: Invalid Academic Year ($acadYearStr). Could not resolve a valid year.');
        continue;
      }

      validRecords.add({
        'usn': usn,
        'name': name,
        'branch': branch,
        'year': year,
        'fest_year': festYear,
        'academic_year': acadYearStr,
        'stream': stream,
        'email': email,
        'gender': gender,
        'points': 0,
      });
    }

    // Safely check duplicates against DB in chunks of 200
    final candidateUsns = validRecords.map((r) => r['usn'] as String).toList();
    final existingUsns = await _getExistingUsns(candidateUsns);
    for (final r in validRecords) {
      if (existingUsns.contains(r['usn'])) {
        duplicateCount++;
      }
    }

    return ImportValidationResult(
      validRecords: validRecords,
      errors: errors,
      duplicateCount: duplicateCount,
    );
  }

  /// Asserts that the USN in [record] has not been mutated since parsing.
  /// Throws a [StateError] and logs an error if any modification is detected.
  void _assertUsnIntegrity(Map<String, dynamic> record, int rowIndex) {
    final usn = record['usn'] as String?;
    if (usn == null || usn.isEmpty) {
      developer.log(
        'USN INTEGRITY ERROR at row $rowIndex: USN is null or empty',
        name: 'ImportService',
      );
      throw StateError('Import aborted: USN is null/empty at row $rowIndex');
    }
  }

  // Confirm and save validated imports into database.
  // IMPORTANT: USNs are stored EXACTLY as they were parsed from the CSV/Excel.
  // The admission year, branch code, and serial number are never modified.
  Future<void> executeImport({
    required int year,
    required String fileName,
    required String fileType,
    required List<Map<String, dynamic>> records,
    required String importedBy,
  }) async {
    // 0. Pre-flight integrity check: abort if any USN is malformed
    for (int i = 0; i < records.length; i++) {
      _assertUsnIntegrity(records[i], i);
    }

    // 1. Log import in yearly_imports
    await SupabaseConfig.client.from(SupabaseTables.yearlyImports).insert({
      'fest_year': year,
      'file_name': fileName,
      'file_type': fileType,
      'total_records': records.length,
      'successful_imports': records.length,
      'failed_imports': 0,
      'imported_by': importedBy,
      'import_data': jsonEncode(records),
    });

    // 2. Perform bulk upsert in student_master.
    // CRITICAL: USNs are passed through exactly as provided in the CSV.
    // The 'year' field comes from the CSV's explicit year column (study year 1-4),
    // NOT from dynamic inference or admission year extraction.
    // The admission year embedded in the USN (e.g., '22' in 4MC22CS001) is NEVER modified.
    final bulkStudents = records.map((r) {
      final usn = r['usn'] as String;
      return <String, dynamic>{
        'usn': usn,
        'name': r['name'],
        'branch': r['branch'],
        'year': r['year'],
        'email': r['email'],
        'gender': r['gender'],
        'status': 'active',
      };
    }).toList();

    // Perform upserts in chunks of 500 to prevent payload limits and database timeouts
    const chunkSize = 500;
    for (int i = 0; i < bulkStudents.length; i += chunkSize) {
      final end = i + chunkSize > bulkStudents.length ? bulkStudents.length : i + chunkSize;
      final chunk = bulkStudents.sublist(i, end);
      await SupabaseConfig.client.from(SupabaseTables.studentMaster).upsert(
        chunk,
        onConflict: 'usn',
      );
    }

    developer.log('Import complete: ${records.length} records upserted for fest year $year', name: 'ImportService');

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

  Future<void> executePreviousYearImport({
    required String fileName,
    required String fileType,
    required List<Map<String, dynamic>> records,
    required String importedBy,
  }) async {
    // 0. Pre-flight integrity check: abort if any USN is malformed
    for (int i = 0; i < records.length; i++) {
      _assertUsnIntegrity(records[i], i);
    }

    // 1. Group records by resolved fest_year
    final Map<int, List<Map<String, dynamic>>> recordsByYear = {};
    for (final r in records) {
      final fy = r['fest_year'] as int;
      recordsByYear.putIfAbsent(fy, () => []).add(r);
    }

    // 2. Perform import for each year group
    for (final entry in recordsByYear.entries) {
      final year = entry.key;
      final yearRecords = entry.value;

      // Log import in yearly_imports
      await SupabaseConfig.client.from(SupabaseTables.yearlyImports).insert({
        'fest_year': year,
        'file_name': fileName,
        'file_type': fileType,
        'total_records': yearRecords.length,
        'successful_imports': yearRecords.length,
        'failed_imports': 0,
        'imported_by': importedBy,
        'import_data': jsonEncode(yearRecords),
      });

      // Perform bulk upsert in student_master.
      // CRITICAL: USNs and years are preserved exactly as provided in the CSV.
      // The admission year embedded in the USN is NEVER modified.
      final bulkStudents = yearRecords.map((r) {
        final usn = r['usn'] as String;
        return <String, dynamic>{
          'usn': usn,
          'name': r['name'],
          'branch': r['branch'],
          'year': r['year'],
          'email': r['email'],
          'gender': r['gender'],
          'status': 'active',
        };
      }).toList();

      // Perform upserts in chunks of 500 to prevent payload limits and database timeouts
      const chunkSize = 500;
      for (int i = 0; i < bulkStudents.length; i += chunkSize) {
        final end = i + chunkSize > bulkStudents.length ? bulkStudents.length : i + chunkSize;
        final chunk = bulkStudents.sublist(i, end);
        await SupabaseConfig.client.from(SupabaseTables.studentMaster).upsert(
          chunk,
          onConflict: 'usn',
        );
      }

      developer.log('Previous year import complete: ${yearRecords.length} records upserted for fest year $year', name: 'ImportService');

      // Archive checks
      final archiveData = await SupabaseConfig.client
          .from(SupabaseTables.yearlyArchives)
          .select()
          .eq('fest_year', year);

      if ((archiveData as List).isEmpty) {
        await SupabaseConfig.client.from(SupabaseTables.yearlyArchives).insert({
          'fest_year': year,
          'fest_name': 'Malnad Fest $year',
          'total_events': 0,
          'total_registrations': yearRecords.length,
          'total_participants': yearRecords.length,
          'total_attendance': yearRecords.length,
          'is_active': true,
          'created_by': importedBy,
        });
      } else {
        await SupabaseConfig.client
            .from(SupabaseTables.yearlyArchives)
            .update({
              'total_registrations': yearRecords.length,
              'total_participants': yearRecords.length,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('fest_year', year);
      }
    }
  }

  /// Starts a streamed, isolate-backed import process.
  /// Reports progress via [onProgress] callback.
  /// Reports completion via [onComplete] callback.
  /// Reports errors via [onError] callback.
  StreamedImportController importStudentsStreamed({
    String? filePath,
    List<int>? bytes,
    required int batchSize,
    required bool isPreviousYear,
    required int expectedFestYear,
    required String importedBy,
    required String fileName,
    required String fileType,
    required Function(ImportProgress progress) onProgress,
    required Function(ImportSummary summary) onComplete,
    required Function(Object error) onError,
  }) {
    final ReceivePort receivePort = ReceivePort();
    SendPort? isolateSendPort;
    
    int totalProcessed = 0;
    int successCount = 0;
    int updatedCount = 0;
    int duplicateCount = 0;
    int failedCount = 0;
    final List<Map<String, dynamic>> failedRows = [];
    final List<Map<String, dynamic>> allSuccessfulRecords = [];
    
    final stopwatch = Stopwatch()..start();
    bool isCancelled = false;
    
    final StreamedImportController controller = StreamedImportController(() {
      isCancelled = true;
      if (isolateSendPort != null) {
        isolateSendPort!.send('cancel');
      }
      receivePort.close();
    });

    Future<void> processBatch(List<Map<String, dynamic>> records, List<Map<String, dynamic>> errors, int totalLines, int processedLines) async {
      if (isCancelled) return;
      
      // Track failed rows
      for (final err in errors) {
        failedCount++;
        failedRows.add({
          'row': err['row'],
          'reason': err['reason'],
        });
      }
      
      if (records.isEmpty) {
        final percent = totalLines > 1 ? (processedLines / (totalLines - 1)) : 1.0;
        onProgress(ImportProgress(
          totalProcessed: totalProcessed + failedCount,
          successCount: successCount,
          updatedCount: updatedCount,
          duplicateCount: duplicateCount,
          failedCount: failedCount,
          percent: percent.clamp(0.0, 1.0),
          statusMessage: 'Processed batch (no new records)...',
          failedRows: failedRows,
        ));
        isolateSendPort?.send('ack');
        return;
      }
      
      try {
        // Group records by resolved fest_year
        final Map<int, List<Map<String, dynamic>>> recordsByYear = {};
        for (final r in records) {
          final y = r['fest_year'] as int;
          recordsByYear.putIfAbsent(y, () => []).add(r);
        }

        for (final entry in recordsByYear.entries) {
          final yearRecords = entry.value;

          final batchUsns = yearRecords.map((r) => r['usn'] as String).toList();
          final existingUsns = await _getExistingUsns(batchUsns);
          
          int batchInserts = 0;
          int batchUpdates = 0;
          
          for (final r in yearRecords) {
            if (existingUsns.contains(r['usn'])) {
              batchUpdates++;
            } else {
              batchInserts++;
            }
          }

          final bulkStudents = yearRecords.map((r) {
            return <String, dynamic>{
              'usn': r['usn'],
              'name': r['name'],
              'branch': r['branch'],
              'year': r['year'],
              'email': r['email'],
              'gender': r['gender'],
              'status': 'active',
            };
          }).toList();

          await SupabaseConfig.client.from(SupabaseTables.studentMaster).upsert(
            bulkStudents,
            onConflict: 'usn',
          );

          successCount += batchInserts;
          updatedCount += batchUpdates;
          allSuccessfulRecords.addAll(yearRecords);
        }

        totalProcessed += records.length;
        final percent = totalLines > 1 ? (processedLines / (totalLines - 1)) : 1.0;

        onProgress(ImportProgress(
          totalProcessed: totalProcessed + failedCount,
          successCount: successCount,
          updatedCount: updatedCount,
          duplicateCount: duplicateCount,
          failedCount: failedCount,
          percent: percent.clamp(0.0, 1.0),
          statusMessage: 'Uploading Batch (${totalProcessed + failedCount}/${totalLines > 1 ? totalLines - 1 : 0})...',
          failedRows: failedRows,
        ));
        
        isolateSendPort?.send('ack');
      } catch (e) {
        onError(e);
        controller.cancel();
      }
    }

    receivePort.listen((message) async {
      if (isCancelled) return;

      if (message is SendPort) {
        isolateSendPort = message;
        return;
      }

      if (message is Map<String, dynamic>) {
        final type = message['type'] as String;
        if (type == 'error_row') {
          failedCount++;
          failedRows.add({
            'row': message['row'],
            'reason': message['reason'],
          });
          return;
        }

        if (type == 'batch') {
          final records = List<Map<String, dynamic>>.from(message['records']);
          final errors = List<Map<String, dynamic>>.from(message['errors']);
          final totalLines = message['totalLines'] as int;
          final processedLines = message['totalProcessed'] as int;
          
          await processBatch(records, errors, totalLines, processedLines);
        } else if (type == 'done') {
          final records = List<Map<String, dynamic>>.from(message['records']);
          final errors = List<Map<String, dynamic>>.from(message['errors']);
          final totalLines = message['totalLines'] as int;
          final processedLines = message['totalProcessed'] as int;
          
          await processBatch(records, errors, totalLines, processedLines);
          
          // Complete and insert logs grouped by fest_year
          try {
            final Map<int, List<Map<String, dynamic>>> successfulByYear = {};
            for (final r in allSuccessfulRecords) {
              final y = r['fest_year'] as int;
              successfulByYear.putIfAbsent(y, () => []).add(r);
            }

            for (final entry in successfulByYear.entries) {
              final year = entry.key;
              final yearRecords = entry.value;

              await SupabaseConfig.client.from(SupabaseTables.yearlyImports).insert({
                'fest_year': year,
                'file_name': fileName,
                'file_type': fileType,
                'total_records': yearRecords.length,
                'successful_imports': yearRecords.length,
                'failed_imports': 0,
                'imported_by': importedBy,
                'import_data': jsonEncode(yearRecords),
              });

              final archiveData = await SupabaseConfig.client
                  .from(SupabaseTables.yearlyArchives)
                  .select()
                  .eq('fest_year', year);

              if ((archiveData as List).isEmpty) {
                await SupabaseConfig.client.from(SupabaseTables.yearlyArchives).insert({
                  'fest_year': year,
                  'fest_name': 'Malnad Fest $year',
                  'total_events': 0,
                  'total_registrations': yearRecords.length,
                  'total_participants': yearRecords.length,
                  'total_attendance': yearRecords.length,
                  'is_active': true,
                  'created_by': importedBy,
                });
              } else {
                await SupabaseConfig.client
                    .from(SupabaseTables.yearlyArchives)
                    .update({
                      'total_registrations': yearRecords.length,
                      'total_participants': yearRecords.length,
                      'updated_at': DateTime.now().toIso8601String(),
                    })
                    .eq('fest_year', year);
              }
            }

            stopwatch.stop();
            onComplete(ImportSummary(
              totalRecords: totalLines > 1 ? totalLines - 1 : 0,
              imported: successCount,
              updated: updatedCount,
              duplicatesSkipped: duplicateCount,
              failed: failedCount,
              timeTakenSeconds: stopwatch.elapsed.inSeconds,
              failedRows: failedRows,
            ));
          } catch (e) {
            onError(e);
          } finally {
            receivePort.close();
          }
        } else if (type == 'error') {
          onError(Exception(message['message']));
          receivePort.close();
        }
      }
    });

    Isolate.spawn(_backgroundParsingIsolate, {
      'filePath': filePath,
      'bytes': bytes,
      'batchSize': batchSize,
      'isPreviousYear': isPreviousYear,
      'expectedFestYear': expectedFestYear,
      'fileType': fileType,
      'sendPort': receivePort.sendPort,
    });

    return controller;
  }

  /// Isolate entrypoint for streaming file/Excel parsing
  static void _backgroundParsingIsolate(Map<String, dynamic> params) async {
    final SendPort sendPort = params['sendPort'] as SendPort;
    final String? filePath = params['filePath'] as String?;
    final List<int>? bytes = params['bytes'] as List<int>?;
    final int batchSize = params['batchSize'] as int;
    final bool isPreviousYear = params['isPreviousYear'] as bool;
    final int expectedFestYear = params['expectedFestYear'] as int;
    final String fileType = params['fileType'] as String;

    final commandPort = ReceivePort();
    sendPort.send(commandPort.sendPort);

    bool isCancelled = false;
    Completer<String>? ackCompleter;

    commandPort.listen((message) {
      if (message == 'cancel') {
        isCancelled = true;
        ackCompleter?.complete('cancel');
      } else if (message == 'ack') {
        ackCompleter?.complete('ack');
      }
    });

    int totalLines = 0;
    List<List<dynamic>> rowsToParse = [];

    if (fileType == 'excel') {
      try {
        final List<int> excelBytes;
        if (bytes != null) {
          excelBytes = bytes;
        } else if (filePath != null) {
          excelBytes = await File(filePath).readAsBytes();
        } else {
          sendPort.send({'type': 'error', 'message': 'No file path or bytes provided.'});
          commandPort.close();
          return;
        }
        final excel = Excel.decodeBytes(excelBytes);
        final sheetName = excel.tables.keys.first;
        final table = excel.tables[sheetName];
        if (table != null) {
          rowsToParse = table.rows.map((row) => row.map((cell) => cell?.value).toList()).toList();
          totalLines = rowsToParse.length;
        }
      } catch (e) {
        sendPort.send({'type': 'error', 'message': 'Failed to decode Excel file: $e'});
        commandPort.close();
        return;
      }
    } else {
      // CSV: Count total lines first (streamed)
      try {
        Stream<String> lineStream;
        if (filePath != null) {
          lineStream = File(filePath).openRead().transform(utf8.decoder).transform(const LineSplitter());
        } else if (bytes != null) {
          lineStream = Stream.value(bytes).transform(utf8.decoder).transform(const LineSplitter());
        } else {
          sendPort.send({'type': 'error', 'message': 'No file path or bytes provided.'});
          commandPort.close();
          return;
        }

        await for (final _ in lineStream) {
          totalLines++;
        }
      } catch (e) {
        sendPort.send({'type': 'error', 'message': 'Failed to read CSV file: $e'});
        commandPort.close();
        return;
      }
    }

    // Now, parse and stream
    Stream<List<dynamic>> rowStream;
    if (fileType == 'excel') {
      rowStream = Stream.fromIterable(rowsToParse);
    } else {
      Stream<String> lineStream;
      if (filePath != null) {
        lineStream = File(filePath).openRead().transform(utf8.decoder).transform(const LineSplitter());
      } else {
        lineStream = Stream.value(bytes!).transform(utf8.decoder).transform(const LineSplitter());
      }
      
      final csvConverter = const CsvToListConverter();
      int lineIndex = 0;
      
      rowStream = lineStream.map((line) {
        lineIndex++;
        String cleanLine = line;
        if (lineIndex == 1 && cleanLine.startsWith('\uFEFF')) {
          cleanLine = cleanLine.substring(1);
        }
        if (cleanLine.trim().isEmpty) return [];
        try {
          final parsed = csvConverter.convert(cleanLine);
          if (parsed.isEmpty) return [];
          return parsed.first;
        } catch (e) {
          sendPort.send({
            'type': 'error_row',
            'row': lineIndex,
            'reason': 'Malformed CSV line format.',
          });
          return [];
        }
      });
    }

    int rowIndex = 0;
    bool foundHeaders = false;
    List<String> headers = [];

    int usnIndex = -1;
    int nameIndex = -1;
    int branchIndex = -1;
    int yearIndex = -1;
    int pointsIndex = -1;
    int academicYearIndex = -1;
    int streamIndex = -1;
    int emailIndex = -1;
    int genderIndex = -1;

    final validBranches = [
      'CSE', 'ISE', 'CI', 'CB', 'RI', 'ECE', 'VL', 'EI', 'EE', 'CV', 'ME'
    ];

    List<Map<String, dynamic>> currentBatch = [];
    List<Map<String, dynamic>> batchErrors = [];
    final seenUsnsInFile = <String>{};

    await for (final row in rowStream) {
      if (isCancelled) break;
      rowIndex++;

      if (row.isEmpty || row.every((e) => e == null || e.toString().trim().isEmpty)) {
        continue;
      }

      if (!foundHeaders) {
        final rowStrings = row.map((e) => e?.toString().trim().toLowerCase() ?? '').toList();
        final hasUsn = rowStrings.any((s) => s.contains('usn'));
        final hasName = rowStrings.any((s) => s.contains('name') || s.contains('student'));

        if (hasUsn && hasName) {
          headers = rowStrings;
          foundHeaders = true;

          usnIndex = headers.indexWhere((h) => h.contains('usn'));
          nameIndex = headers.indexWhere((h) => h.contains('name') || h.contains('student'));
          branchIndex = headers.indexWhere((h) => h.contains('branch') || h.contains('dept') || h.contains('department'));
          yearIndex = headers.indexWhere((h) => h == 'year');
          pointsIndex = headers.indexWhere((h) => h.contains('points'));
          academicYearIndex = headers.indexWhere((h) => h.contains('academic year') || h.contains('academic'));
          streamIndex = headers.indexWhere((h) => h == 'stream');
          emailIndex = headers.indexWhere((h) => h.contains('email'));
          genderIndex = headers.indexWhere((h) => h.contains('gender'));

          if (usnIndex == -1 || nameIndex == -1 || branchIndex == -1 || yearIndex == -1 || (isPreviousYear && academicYearIndex == -1)) {
            sendPort.send({
              'type': 'error',
              'message': 'Missing required columns in file. Columns USN, Name, Department/Branch, and Year are required.',
            });
            commandPort.close();
            return;
          }
          continue;
        }

        if (rowIndex >= 10) {
          sendPort.send({
            'type': 'error',
            'message': 'Could not detect header columns in the first 10 rows.',
          });
          commandPort.close();
          return;
        }
        continue;
      }

      if (row.length <= usnIndex || row.length <= nameIndex || row.length <= branchIndex || row.length <= yearIndex) {
        batchErrors.add({
          'row': rowIndex,
          'reason': 'Incomplete columns.',
        });
        continue;
      }

      final usn = row[usnIndex]?.toString().trim().toUpperCase() ?? '';
      final name = row[nameIndex]?.toString().trim() ?? '';
      final deptRaw = row[branchIndex]?.toString().trim() ?? '';
      final rowYearStr = row[yearIndex]?.toString().trim() ?? '';

      if (usn.isEmpty && name.isEmpty && deptRaw.isEmpty) {
        continue;
      }

      if (usn.isEmpty || name.isEmpty || deptRaw.isEmpty) {
        batchErrors.add({
          'row': rowIndex,
          'reason': 'USN, Name, and Department/Branch must not be empty.',
        });
        continue;
      }

      if (usn.length < 5) {
        batchErrors.add({
          'row': rowIndex,
          'reason': 'USN is too short.',
        });
        continue;
      }

      if (seenUsnsInFile.contains(usn)) {
        batchErrors.add({
          'row': rowIndex,
          'reason': 'Duplicate USN "$usn" within the file.',
        });
        continue;
      }
      seenUsnsInFile.add(usn);

      final branch = normalizeBranchStatic(deptRaw);
      if (!validBranches.contains(branch)) {
        batchErrors.add({
          'row': rowIndex,
          'reason': 'Invalid department/branch "$branch".',
        });
        continue;
      }

      final year = int.tryParse(rowYearStr);
      if (year == null || year < 1 || year > 4) {
        batchErrors.add({
          'row': rowIndex,
          'reason': 'Invalid study year "$rowYearStr". Must be between 1 and 4.',
        });
        continue;
      }

      String? acadYearStr;
      int? resolvedFestYear;
      if (isPreviousYear) {
        if (row.length <= academicYearIndex || row[academicYearIndex] == null || row[academicYearIndex].toString().trim().isEmpty) {
          batchErrors.add({
            'row': rowIndex,
            'reason': 'Academic Year must not be empty.',
          });
          continue;
        }
        acadYearStr = row[academicYearIndex].toString().trim();
        resolvedFestYear = extractFestYearStatic(acadYearStr);
        if (resolvedFestYear == null || resolvedFestYear < 2020 || resolvedFestYear > 2099) {
          batchErrors.add({
            'row': rowIndex,
            'reason': 'Invalid Academic Year format "$acadYearStr".',
          });
          continue;
        }
      }

      final points = pointsIndex != -1 && row.length > pointsIndex && row[pointsIndex] != null
          ? int.tryParse(row[pointsIndex].toString().trim()) ?? 0
          : 0;

      final stream = streamIndex != -1 && row.length > streamIndex ? row[streamIndex]?.toString().trim() : null;
      final email = emailIndex != -1 && row.length > emailIndex ? row[emailIndex]?.toString().trim() : null;
      final gender = genderIndex != -1 && row.length > genderIndex ? row[genderIndex]?.toString().trim() : null;

      currentBatch.add({
        'usn': usn,
        'name': name,
        'branch': branch,
        'year': year,
        'points': points,
        'fest_year': resolvedFestYear ?? expectedFestYear,
        'academic_year': acadYearStr,
        'stream': stream,
        'email': email,
        'gender': gender,
        'rowNumber': rowIndex,
      });

      if (currentBatch.length >= batchSize) {
        sendPort.send({
          'type': 'batch',
          'records': List<Map<String, dynamic>>.from(currentBatch),
          'errors': List<Map<String, dynamic>>.from(batchErrors),
          'totalProcessed': rowIndex - 1,
          'totalLines': totalLines,
        });

        currentBatch.clear();
        batchErrors.clear();

        ackCompleter = Completer<String>();
        final reply = await ackCompleter.future;
        if (reply == 'cancel' || isCancelled) {
          commandPort.close();
          return;
        }
        ackCompleter = null;
      }
    }

    if (!isCancelled) {
      sendPort.send({
        'type': 'done',
        'records': currentBatch,
        'errors': batchErrors,
        'totalProcessed': rowIndex - 1,
        'totalLines': totalLines,
      });
    }

    commandPort.close();
  }

  static String normalizeBranchStatic(String dept) {
    final d = dept.toUpperCase().trim();
    if (d.contains('COMPUTER SCIENCE') || d == 'CS' || d == 'CSE') {
      if (d.contains('AI') || d.contains('ML')) return 'CI';
      if (d.contains('BUSINESS') || d.contains('BS') || d.contains('CSBS')) return 'CB';
      return 'CSE';
    }
    if (d.contains('INFORMATION SCIENCE') || d == 'IS' || d == 'ISE') return 'ISE';
    if (d.contains('ELECTRONICS & COMM') || d.contains('ELECTRONICS AND COMM') || d == 'EC' || d == 'ECE') return 'ECE';
    if (d.contains('ELECTRICAL') || d == 'EE' || d == 'EEE') return 'EE';
    if (d.contains('MECHANICAL') || d == 'ME') return 'ME';
    if (d.contains('CIVIL') || d == 'CV' || d == 'CE' || d == 'CIVIL') return 'CV';
    if (d.contains('VLSI') || d == 'VL') return 'VL';
    if (d.contains('ROBOTICS') || d == 'RI' || d == 'RAI') return 'RI';
    if (d.contains('ELECTRONICS & COMPUTER') || d.contains('ELECTRONICS AND COMPUTER') || d == 'EI') return 'EI';
    if (d == 'CI' || d == 'AIML') return 'CI';
    if (d == 'CB' || d == 'CSBS') return 'CB';
    return d;
  }

  static int? extractFestYearStatic(String academicYear) {
    final regexRange = RegExp(r'(\d{4})[-/](\d{2,4})');
    final matchRange = regexRange.firstMatch(academicYear);
    if (matchRange != null) {
      final startYearStr = matchRange.group(1)!;
      final endYearStr = matchRange.group(2)!;
      if (endYearStr.length == 2) {
        final prefix = startYearStr.substring(0, 2);
        return int.tryParse('$prefix$endYearStr');
      } else {
        return int.tryParse(endYearStr);
      }
    }
    
    final regexSingle = RegExp(r'(\d{4})');
    final matchSingle = regexSingle.firstMatch(academicYear);
    if (matchSingle != null) {
      return int.tryParse(matchSingle.group(1)!);
    }
    return null;
  }
}

