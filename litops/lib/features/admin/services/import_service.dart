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
    'CS', 'IS', 'CI', 'CB', 'RI', 'EC', 'VL', 'EI', 'EE', 'CV', 'ME'
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

    final studentMasterData = await SupabaseConfig.client
        .from(SupabaseTables.studentMaster)
        .select('usn');
    final existingUsns = (studentMasterData as List)
        .map((e) => e['usn']?.toString().toUpperCase())
        .toSet();

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

      if (usn.length < 5) {
        errors.add('Row ${i + 1}: Invalid USN format ($usn).');
        continue;
      }

      final branch = normalizeBranch(branchRaw);

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

    final studentMasterData = await SupabaseConfig.client
        .from(SupabaseTables.studentMaster)
        .select('usn');
    final existingUsns = (studentMasterData as List)
        .map((e) => e['usn']?.toString().toUpperCase())
        .toSet();

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

      if (usn.length < 5) {
        errors.add('Row ${i + 1}: Invalid USN format ($usn).');
        continue;
      }

      final branch = normalizeBranch(branchRaw);

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
      return 'CS';
    }
    if (d.contains('INFORMATION SCIENCE') || d == 'IS' || d == 'ISE') return 'IS';
    if (d.contains('ELECTRONICS & COMM') || d.contains('ELECTRONICS AND COMM') || d == 'EC' || d == 'ECE') return 'EC';
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

    final studentMasterData = await SupabaseConfig.client
        .from(SupabaseTables.studentMaster)
        .select('usn');
    final existingUsns = (studentMasterData as List)
        .map((e) => e['usn']?.toString().toUpperCase())
        .toSet();

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

      if (existingUsns.contains(usn)) {
        duplicateCount++;
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

    final studentMasterData = await SupabaseConfig.client
        .from(SupabaseTables.studentMaster)
        .select('usn');
    final existingUsns = (studentMasterData as List)
        .map((e) => e['usn']?.toString().toUpperCase())
        .toSet();

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

      if (existingUsns.contains(usn)) {
        duplicateCount++;
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

    // 2. Perform bulk upsert in student_master
    final bulkStudents = records.map((r) => {
      'usn': r['usn'],
      'name': r['name'],
      'branch': r['branch'],
      'year': r['year'],
      'email': r['email'],
      'gender': r['gender'],
      'stream': r['stream'],
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

  Future<void> executePreviousYearImport({
    required String fileName,
    required String fileType,
    required List<Map<String, dynamic>> records,
    required String importedBy,
  }) async {
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

      // Perform bulk upsert in student_master
      final bulkStudents = yearRecords.map((r) => {
        'usn': r['usn'],
        'name': r['name'],
        'branch': r['branch'],
        'year': r['year'],
        'email': r['email'],
        'gender': r['gender'],
        'stream': r['stream'],
        'status': 'active',
      }).toList();

      await SupabaseConfig.client.from(SupabaseTables.studentMaster).upsert(
        bulkStudents,
        onConflict: 'usn',
      );

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
}
