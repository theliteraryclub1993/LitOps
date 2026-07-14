import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';

class ImportValidationResult {
  final List<Map<String, dynamic>> validRecords;
  final List<String> errors;
  final int duplicateCount;
  final String? detectedAcademicYear;
  final int departmentCount;

  const ImportValidationResult({
    required this.validRecords,
    required this.errors,
    required this.duplicateCount,
    required this.detectedAcademicYear,
    required this.departmentCount,
  });
}

class IsolateParseResult {
  final List<Map<String, dynamic>> validRecords;
  final List<String> errors;
  final String? detectedAcademicYear;
  final Set<String> departments;

  const IsolateParseResult({
    required this.validRecords,
    required this.errors,
    this.detectedAcademicYear,
    required this.departments,
  });
}

class ImportService {
  final List<String> _validBranches = [
    'CSE',
    'ISE',
    'CI',
    'CB',
    'RI',
    'ECE',
    'VL',
    'EI',
    'EE',
    'CV',
    'ME'
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
      developer.log(
          'USN "$usn" does not match standard VTU format but will be accepted',
          name: 'ImportService');
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
        developer.log('Error checking existing USNs for chunk: $e',
            name: 'ImportService');
      }
    }

    return existing;
  }

  /// Parses and validates the entire file. Returns validation details before import begins.
  Future<ImportValidationResult> validateStudentFile({
    required List<int> bytes,
    required String fileType,
    required String fileName,
  }) async {
    // 1. Detect academic year from filename
    String? detectedAcadYear;
    final nameMatch = RegExp(r'(\d{4})[-_](\d{2,4})').firstMatch(fileName);
    if (nameMatch != null) {
      final start = nameMatch.group(1)!;
      var end = nameMatch.group(2)!;
      if (end.length == 4) end = end.substring(2);
      detectedAcadYear = '$start-$end';
    }

    // 2. Parse and validate rows in isolate
    final parseResult =
        await _runIsolateParsing(bytes, fileType, detectedAcadYear);

    // 3. Check duplicate count in database for the valid records
    final validUsns =
        parseResult.validRecords.map((r) => r['usn'] as String).toList();
    final existingUsns = await _getExistingUsns(validUsns);

    return ImportValidationResult(
      validRecords: parseResult.validRecords,
      errors: parseResult.errors,
      duplicateCount: existingUsns.length,
      detectedAcademicYear:
          parseResult.detectedAcademicYear ?? detectedAcadYear,
      departmentCount: parseResult.departments.length,
    );
  }

  static Future<IsolateParseResult> _runIsolateParsing(
    List<int> bytes,
    String fileType,
    String? defaultAcadYear,
  ) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_backgroundValidateIsolate, {
      'bytes': bytes,
      'fileType': fileType,
      'defaultAcadYear': defaultAcadYear,
      'sendPort': receivePort.sendPort,
    });

    final msg = await receivePort.first;
    if (msg is Map<String, dynamic>) {
      if (msg['success'] == true) {
        return IsolateParseResult(
          validRecords: List<Map<String, dynamic>>.from(msg['validRecords']),
          errors: List<String>.from(msg['errors']),
          detectedAcademicYear: msg['detectedAcademicYear'] as String?,
          departments: Set<String>.from(msg['departments']),
        );
      } else {
        throw Exception(msg['error']);
      }
    }
    throw Exception('Unknown isolate response');
  }

  /// Auto-detect CSV delimiter by checking comma, semicolon, and tab counts
  /// in the first few lines of the CSV string.
  static String _detectDelimiter(String csvString) {
    final lines = csvString.split(RegExp(r'\r?\n'));
    // Check first 5 non-empty lines
    final sampleLines =
        lines.where((l) => l.trim().isNotEmpty).take(5).toList();
    if (sampleLines.isEmpty) return ',';

    int commaCount = 0;
    int semicolonCount = 0;
    int tabCount = 0;

    for (final line in sampleLines) {
      commaCount += ','.allMatches(line).length;
      semicolonCount += ';'.allMatches(line).length;
      tabCount += '\t'.allMatches(line).length;
    }

    if (tabCount > commaCount && tabCount > semicolonCount) return '\t';
    if (semicolonCount > commaCount) return ';';
    return ',';
  }

  /// Isolate entrypoint for parsing CSV/Excel and collecting validation issues.
  static void _backgroundValidateIsolate(Map<String, dynamic> params) {
    final SendPort sendPort = params['sendPort'] as SendPort;
    final List<int> bytes = params['bytes'] as List<int>;
    final String fileType = params['fileType'] as String;
    final String? defaultAcadYear = params['defaultAcadYear'] as String?;

    try {
      List<List<dynamic>> rows = [];
      if (fileType == 'excel') {
        final excel = Excel.decodeBytes(bytes);
        final sheetName = excel.tables.keys.first;
        final table = excel.tables[sheetName];
        if (table != null) {
          rows = table.rows
              .map((row) => row.map((cell) => cell?.value).toList())
              .toList();
        }
      } else {
        var csvString = utf8.decode(bytes);
        // Strip BOM (Byte Order Mark) if present
        if (csvString.startsWith('\uFEFF')) {
          csvString = csvString.substring(1);
        }
        // Normalize spacing around quotes and delimiters to prevent parser failure
        csvString = csvString.replaceAllMapped(
            RegExp(r'([,;\t])\s*"'), (m) => '${m.group(1)}"');
        csvString = csvString.replaceAllMapped(
            RegExp(r'"\s*([,;\t])'), (m) => '"${m.group(1)}');

        // Auto-detect delimiter
        final delimiter = _detectDelimiter(csvString);
        rows = CsvToListConverter(
          fieldDelimiter: delimiter,
          shouldParseNumbers: false,
        ).convert(csvString);
      }

      if (rows.isEmpty) {
        sendPort.send({
          'success': true,
          'validRecords': [],
          'errors': ['File is empty.'],
          'detectedAcademicYear': null,
          'departments': [],
        });
        return;
      }

      // Filter out completely empty rows first
      rows = rows
          .where((row) =>
              row.isNotEmpty &&
              !row.every((e) => e == null || e.toString().trim().isEmpty))
          .toList();

      if (rows.isEmpty) {
        sendPort.send({
          'success': true,
          'validRecords': [],
          'errors': ['File contains no data rows.'],
          'detectedAcademicYear': null,
          'departments': [],
        });
        return;
      }

      int headerRowIndex = 0;
      List<String> headers = [];
      bool foundHeaders = false;

      for (int i = 0; i < rows.length && i < 20; i++) {
        final row = rows[i];
        final rowStrings =
            row.map((e) => e?.toString().trim().toLowerCase() ?? '').toList();
        final hasUsn = rowStrings.any((s) => s.contains('usn'));
        final hasName = rowStrings.any(
            (s) => s.contains('name') || s == 'student name' || s == 'student');
        final hasBranch = rowStrings.any((s) =>
            s.contains('branch') ||
            s.contains('dept') ||
            s.contains('department'));

        if (hasUsn && (hasName || hasBranch)) {
          headerRowIndex = i;
          headers = rowStrings;
          foundHeaders = true;
          break;
        }
      }

      if (!foundHeaders) {
        // Try first row as fallback
        headers = rows.first
            .map((e) => e?.toString().trim().toLowerCase() ?? '')
            .toList();

        // Check if maybe the file was parsed into single-column rows
        // (delimiter mismatch). If the first row has only 1 column but
        // contains multiple commas/semicolons/tabs, re-parse with a
        // different delimiter.
        if (headers.length == 1 && headers[0].length > 20) {
          final singleCell = headers[0];
          // Likely delimiter mismatch - try to split manually
          String? altDelimiter;
          if (singleCell.contains('\t')) {
            altDelimiter = '\t';
          } else if (singleCell.contains(';')) {
            altDelimiter = ';';
          } else if (singleCell.contains(',')) {
            altDelimiter = ',';
          }

          if (altDelimiter != null) {
            var csvString = utf8.decode(bytes);
            if (csvString.startsWith('\uFEFF')) {
              csvString = csvString.substring(1);
            }
            rows = CsvToListConverter(
              fieldDelimiter: altDelimiter,
              shouldParseNumbers: false,
            ).convert(csvString);
            rows = rows
                .where((row) =>
                    row.isNotEmpty &&
                    !row.every((e) => e == null || e.toString().trim().isEmpty))
                .toList();

            // Re-detect headers
            for (int i = 0; i < rows.length && i < 20; i++) {
              final row = rows[i];
              final rowStrings = row
                  .map((e) => e?.toString().trim().toLowerCase() ?? '')
                  .toList();
              final hasUsn = rowStrings.any((s) => s.contains('usn'));
              final hasName = rowStrings.any((s) =>
                  s.contains('name') || s == 'student name' || s == 'student');

              if (hasUsn && hasName) {
                headerRowIndex = i;
                headers = rowStrings;
                foundHeaders = true;
                break;
              }
            }

            if (!foundHeaders) {
              headers = rows.first
                  .map((e) => e?.toString().trim().toLowerCase() ?? '')
                  .toList();
            }
          }
        }
      }

      final usnIndex = headers.indexWhere((h) => h.contains('usn'));
      final nameIndex = headers.indexWhere((h) {
        // Avoid matching "usn" column for name — be specific
        if (h.contains('usn')) return false;
        return h.contains('name') || h == 'student';
      });
      final branchIndex = headers.indexWhere((h) =>
          h.contains('branch') ||
          h.contains('dept') ||
          h.contains('department'));
      final yearIndex = headers.indexWhere((h) => h == 'year' || h == 'yr');
      final semesterIndex = headers
          .indexWhere((h) => h.contains('semester') || h.contains('sem'));
      final academicYearIndex = headers.indexWhere(
          (h) => h.contains('academic year') || h.contains('academic'));
      final emailIndex = headers.indexWhere((h) => h.contains('email'));
      final phoneIndex = headers
          .indexWhere((h) => h.contains('phone') || h.contains('mobile'));
      final genderIndex = headers.indexWhere((h) => h.contains('gender'));
      final streamIndex = headers.indexWhere((h) => h.contains('stream'));
      final sectionIndex =
          headers.indexWhere((h) => h == 'section' || h == 'sec');

      if (usnIndex == -1 || (nameIndex == -1 && branchIndex == -1)) {
        sendPort.send({
          'success': true,
          'validRecords': [],
          'errors': [
            'Missing required headers. Need at least "USN" and "Name" (or "Student Name") columns. '
                'Found ${headers.length} columns: ${headers.join(", ")}. '
                'Total rows parsed: ${rows.length}.'
          ],
          'detectedAcademicYear': null,
          'departments': [],
        });
        return;
      }

      final validRecords = <Map<String, dynamic>>[];
      final errors = <String>[];
      final seenUsnsInFile = <String>{};
      final departments = <String>{};
      String? detectedAcademicYear;

      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty ||
            row.every((e) => e == null || e.toString().trim().isEmpty)) {
          continue;
        }

        if (row.length <= usnIndex) {
          errors.add(
              'Row ${i + 1}: Incomplete column counts (${row.length} columns, need at least ${usnIndex + 1}).');
          continue;
        }

        final usn = row[usnIndex]?.toString().trim().toUpperCase() ?? '';
        final name = nameIndex != -1 && row.length > nameIndex
            ? row[nameIndex]?.toString().trim().toUpperCase() ?? ''
            : '';
        final branchRaw = branchIndex != -1 && row.length > branchIndex
            ? row[branchIndex]?.toString().trim().toUpperCase() ?? ''
            : '';

        final email = emailIndex != -1 && row.length > emailIndex
            ? row[emailIndex]?.toString().trim()
            : null;
        final phone = phoneIndex != -1 && row.length > phoneIndex
            ? row[phoneIndex]?.toString().trim()
            : null;
        final gender = genderIndex != -1 && row.length > genderIndex
            ? row[genderIndex]?.toString().trim().toUpperCase()
            : null;
        final stream = streamIndex != -1 && row.length > streamIndex
            ? row[streamIndex]?.toString().trim().toUpperCase()
            : null;
        final section = sectionIndex != -1 && row.length > sectionIndex
            ? row[sectionIndex]?.toString().trim().toUpperCase()
            : null;

        int studyYear = 1;
        if (yearIndex != -1 && row.length > yearIndex) {
          final yearStr = row[yearIndex]?.toString().trim() ?? '';
          studyYear = int.tryParse(yearStr) ?? _inferYearFromUsn(usn);
        } else {
          studyYear = _inferYearFromUsn(usn);
        }

        int? semester;
        if (semesterIndex != -1 && row.length > semesterIndex) {
          semester = int.tryParse(row[semesterIndex]?.toString().trim() ?? '');
        }

        if (usn.isEmpty) {
          // Skip rows with empty USN silently (might be junk data)
          continue;
        }

        if (name.isEmpty && nameIndex != -1) {
          errors.add('Row ${i + 1}: Name is empty for USN "$usn".');
          continue;
        }

        if (usn.length < 5) {
          errors.add('Row ${i + 1}: USN "$usn" is too short.');
          continue;
        }

        if (seenUsnsInFile.contains(usn)) {
          errors.add('Row ${i + 1}: Duplicate USN "$usn" within the file.');
          continue;
        }
        seenUsnsInFile.add(usn);

        // Infer branch from USN if branch column is missing or empty
        String normalizedBranch;
        if (branchRaw.isNotEmpty) {
          normalizedBranch = normalizeBranchStatic(branchRaw);
        } else {
          normalizedBranch = _inferBranchFromUsn(usn);
        }
        departments.add(normalizedBranch);

        String? acadYearCol;
        if (academicYearIndex != -1 && row.length > academicYearIndex) {
          final rawAcad = row[academicYearIndex]?.toString().trim();
          if (rawAcad != null && rawAcad.isNotEmpty) {
            final match = RegExp(r'(\d{4})[-_](\d{2,4})').firstMatch(rawAcad);
            if (match != null) {
              final start = match.group(1)!;
              var end = match.group(2)!;
              if (end.length == 4) end = end.substring(2);
              acadYearCol = '$start-$end';
              detectedAcademicYear ??= acadYearCol;
            }
          }
        }

        validRecords.add({
          'usn': usn,
          'name': name,
          'branch': normalizedBranch,
          'year': studyYear,
          'semester': semester ?? (studyYear * 2 - 1),
          'email': email,
          'phone': phone,
          'gender': gender,
          'stream': stream,
          'section': section,
          'academic_year': acadYearCol,
        });
      }

      sendPort.send({
        'success': true,
        'validRecords': validRecords,
        'errors': errors,
        'detectedAcademicYear': detectedAcademicYear,
        'departments': departments.toList(),
      });
    } catch (e, stack) {
      sendPort.send({
        'success': false,
        'error': 'Parsing error: $e\n$stack',
      });
    }
  }

  /// Infer study year from VTU USN format (e.g., 4MC22CS001 → year depends on batch)
  static int _inferYearFromUsn(String usn) {
    if (usn.length >= 5) {
      final batchDigits = usn.substring(3, 5);
      final batchYear = int.tryParse(batchDigits);
      if (batchYear != null) {
        final currentYear = DateTime.now().year % 100;
        final diff = currentYear - batchYear;
        if (diff >= 0 && diff <= 4) return diff + 1;
      }
    }
    return 1;
  }

  /// Infer branch from VTU USN format (e.g., 4MC22CS001 → CS → CSE)
  static String _inferBranchFromUsn(String usn) {
    if (usn.length >= 7) {
      // VTU format: digit + 2 letters (college) + 2 digits (year) + 2-3 letters (branch)
      final afterYear = usn.substring(5);
      final branchMatch = RegExp(r'^([A-Z]{2,3})').firstMatch(afterYear);
      if (branchMatch != null) {
        return normalizeBranchStatic(branchMatch.group(1)!);
      }
    }
    return 'UNKNOWN';
  }

  /// Registers an import job in the import_batches database table.
  Future<String> createImportBatch({
    required String fileName,
    required String academicYear,
    required String duplicateMode,
    required int totalRows,
    required String uploadedBy,
  }) async {
    final response = await SupabaseConfig.client
        .from('import_batches')
        .insert({
          'file_name': fileName,
          'academic_year': academicYear,
          'uploaded_by': uploadedBy.isNotEmpty ? uploadedBy : null,
          'duplicate_mode': duplicateMode,
          'status': 'pending',
          'total_rows': totalRows,
          'processed_rows': 0,
          'inserted_count': 0,
          'updated_count': 0,
          'skipped_count': 0,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// Executes the import job in chunks of 500 records.
  /// Reports live statistics and updates progress in `import_batches` table.
  Future<void> executeImportJob({
    required String batchId,
    required String academicYear,
    required String duplicateMode,
    required List<Map<String, dynamic>> records,
    required Function(int processed, int inserted, int updated, int skipped)
        onBatchProgress,
  }) async {
    try {
      await SupabaseConfig.client.from('import_batches').update({
        'status': 'processing',
      }).eq('id', batchId);

      int processedRows = 0;
      int insertedCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;

      const chunkSize = 500;
      for (int i = 0; i < records.length; i += chunkSize) {
        final end =
            i + chunkSize > records.length ? records.length : i + chunkSize;
        final chunk = records.sublist(i, end);
        final chunkUsns = chunk.map((r) => r['usn'] as String).toList();

        // 1. Fetch which USNs exist in DB
        final existingUsns = await _getExistingUsns(chunkUsns);

        final List<Map<String, dynamic>> studentsToInsert = [];
        final List<Map<String, dynamic>> studentsToUpdate = [];

        for (final r in chunk) {
          final usn = r['usn'] as String;
          final studentMap = {
            'usn': usn,
            'name': r['name'],
            'branch': r['branch'],
            'year': r['year'],
            'semester': r['semester'],
            'email': r['email'],
            'phone': r['phone'],
            'gender': r['gender'],
            'stream': r['stream'],
            'academic_year': r['academic_year'] ?? academicYear,
            'source': 'historical_import',
            'import_batch_id': batchId,
            'status': 'active',
          };

          if (existingUsns.contains(usn)) {
            if (duplicateMode == 'replace') {
              studentsToUpdate.add(studentMap);
              updatedCount++;
            } else {
              skippedCount++;
            }
          } else {
            studentsToInsert.add(studentMap);
            insertedCount++;
          }
        }

        // 2. Bulk upsert matching records
        final List<Map<String, dynamic>> upsertPayload = [
          ...studentsToInsert,
          ...studentsToUpdate
        ];
        if (upsertPayload.isNotEmpty) {
          await SupabaseConfig.client.from(SupabaseTables.studentMaster).upsert(
                upsertPayload,
                onConflict: 'usn',
              );
        }

        processedRows += chunk.length;

        // 3. Update database job details
        await SupabaseConfig.client.from('import_batches').update({
          'processed_rows': processedRows,
          'inserted_count': insertedCount,
          'updated_count': updatedCount,
          'skipped_count': skippedCount,
        }).eq('id', batchId);

        onBatchProgress(
            processedRows, insertedCount, updatedCount, skippedCount);
      }

      // Update academic year config in app_settings table
      await SupabaseConfig.client.from(SupabaseTables.appSettings).upsert({
        'key': 'current_academic_year',
        'value': academicYear,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'key');

      // Update status to completed
      await SupabaseConfig.client.from('import_batches').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', batchId);
    } catch (e) {
      developer.log('Import execution failed: $e', name: 'ImportService');
      await SupabaseConfig.client.from('import_batches').update({
        'status': 'failed',
        'error_log': e.toString(),
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', batchId);
      rethrow;
    }
  }

  static String normalizeBranchStatic(String dept) {
    final d = dept.toUpperCase().trim();
    if (d.contains('COMPUTER SCIENCE') || d == 'CS' || d == 'CSE') {
      if (d.contains('AI') || d.contains('ML')) return 'CI';
      if (d.contains('BUSINESS') || d.contains('BS') || d.contains('CSBS')) {
        return 'CB';
      }
      return 'CSE';
    }
    if (d.contains('INFORMATION SCIENCE') || d == 'IS' || d == 'ISE') {
      return 'ISE';
    }
    if (d.contains('ELECTRONICS & COMM') ||
        d.contains('ELECTRONICS AND COMM') ||
        d == 'EC' ||
        d == 'ECE') {
      return 'ECE';
    }
    if (d.contains('ELECTRICAL') || d == 'EE' || d == 'EEE') return 'EE';
    if (d.contains('MECHANICAL') || d == 'ME') return 'ME';
    if (d.contains('CIVIL') || d == 'CV' || d == 'CE' || d == 'CIVIL') {
      return 'CV';
    }
    if (d.contains('VLSI') || d == 'VL') return 'VL';
    if (d.contains('ROBOTICS') || d == 'RI' || d == 'RAI') return 'RI';
    if (d.contains('ELECTRONICS & COMPUTER') ||
        d.contains('ELECTRONICS AND COMPUTER') ||
        d == 'EI') {
      return 'EI';
    }
    if (d == 'CI' || d == 'AIML') return 'CI';
    if (d == 'CB' || d == 'CSBS') return 'CB';
    return d;
  }
}
