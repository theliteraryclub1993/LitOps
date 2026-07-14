import 'package:intl/intl.dart';

class AppUtils {
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  static String formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatDate(date);
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return RegExp(r'^[+]?[\d\s-]{10,15}$').hasMatch(phone);
  }

  static bool isValidUSN(String usn) {
    return RegExp(r'^[A-Z0-9]{6,15}$').hasMatch(usn.toUpperCase());
  }

  static String extractUsnFromScan(String rawValue) {
    var clean = rawValue.trim();
    if (clean.isEmpty) return '';

    // Remove barcode symbology prefixes like ]C1 or similar (e.g. GS1-128 AIM IDs)
    if (clean.toUpperCase().startsWith(']C1')) {
      clean = clean.substring(3).trim();
    }

    // 1. Check if it's a URL
    try {
      final uri = Uri.parse(clean);
      if (uri.scheme.startsWith('http')) {
        // Check query parameters first
        if (uri.queryParameters.containsKey('usn')) {
          return uri.queryParameters['usn']!.toUpperCase().trim();
        }
        if (uri.queryParameters.containsKey('id')) {
          final idVal = uri.queryParameters['id']!.toUpperCase().trim();
          if (RegExp(r'^[A-Z0-9]{6,15}$').hasMatch(idVal)) {
            return idVal;
          }
        }
        // Otherwise, check the last path segment
        final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        final parsedSegment = lastSegment.toUpperCase().trim();
        if (RegExp(r'^[A-Z0-9]{6,15}$').hasMatch(parsedSegment)) {
          return parsedSegment;
        }
      }
    } catch (_) {
      // Not a valid URL, continue with text parsing
    }

    // 2. Try to find a VTU USN-like pattern in the text (case-insensitive)
    // Matches patterns like 4MC22CS001, 4MC23IS002, 4MC22MCA01
    final usnRegex = RegExp(r'\b\d[A-Z]{2}\d{2}[A-Z]{2,3}\d{2,3}\b', caseSensitive: false);
    final match = usnRegex.firstMatch(clean);
    if (match != null) {
      return match.group(0)!.toUpperCase();
    }

    // 3. Fallback: search for any alphanumeric word of length 6 to 15 that contains both letters and digits.
    // This handles cases where the scanner returned extra text or control chars.
    final words = clean.split(RegExp(r'[\s,;:?=&|/\\\x00]')); // includes null char \x00
    for (var word in words) {
      final w = word.trim().toUpperCase();
      // Remove any control/null characters from word
      final cleanWord = w.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
      if (cleanWord.length >= 6 && cleanWord.length <= 15) {
        if (RegExp(r'[A-Z]').hasMatch(cleanWord) && RegExp(r'[0-9]').hasMatch(cleanWord)) {
          return cleanWord;
        }
      }
    }

    // 4. Ultimate fallback: remove control characters and return trimmed uppercase
    return clean.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').toUpperCase();
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static List<String> branches = const [
    'CSE', 'ISE', 'CI', 'CB', 'RI', 'ECE', 'VL', 'EI', 'EE', 'CV', 'ME'
  ];

  static String mapUsnBranchToOfficial(String usnBranch) {
    final b = usnBranch.toUpperCase().trim();
    if (b.contains('COMPUTER SCIENCE') || b == 'CS' || b == 'CSE') {
      if (b.contains('AI') || b.contains('ML')) return 'CI';
      if (b.contains('BUSINESS') || b.contains('BS') || b.contains('CSBS')) return 'CB';
      return 'CSE';
    }
    if (b.contains('INFORMATION SCIENCE') || b == 'IS' || b == 'ISE') return 'ISE';
    if (b.contains('ELECTRONICS & COMM') || b.contains('ELECTRONICS AND COMM') || b == 'EC' || b == 'ECE') return 'ECE';
    if (b.contains('ELECTRICAL') || b == 'EE' || b == 'EEE') return 'EE';
    if (b.contains('MECHANICAL') || b == 'ME') return 'ME';
    if (b.contains('CIVIL') || b == 'CV' || b == 'CE' || b == 'CIVIL') return 'CV';
    if (b.contains('VLSI') || b == 'VL') return 'VL';
    if (b.contains('ROBOTICS') || b == 'RI' || b == 'RAI') return 'RI';
    if (b.contains('ELECTRONICS & COMPUTER') || b.contains('ELECTRONICS AND COMPUTER') || b == 'EI') return 'EI';
    if (b == 'CI' || b == 'AIML') return 'CI';
    if (b == 'CB' || b == 'CSBS') return 'CB';
    return b;
  }

  static String extractBranchFromUsn(String usn) {
    final clean = usn.trim().toUpperCase();
    if (clean.length >= 7) {
      final match = RegExp(r'^\d[A-Z]{2}\d{2}([A-Z]{2,3})').firstMatch(clean);
      if (match != null) {
        return mapUsnBranchToOfficial(match.group(1)!);
      }
      return mapUsnBranchToOfficial(clean.substring(5, 7));
    }
    return '';
  }

  /// Extracts the raw admission year from a VTU-style USN.
  /// For example, `4MC22CS001` → `2022`, `4MC25ME021` → `2025`.
  /// Returns `null` if the USN doesn't match the expected pattern.
  ///
  /// **READ-ONLY**: This method extracts information from the USN string.
  /// It does NOT and must NEVER modify the USN or any stored field.
  /// A student's USN is a permanent, immutable identifier.
  ///
  /// This does NOT compute the current study year — use [inferCurrentStudyYearFromUsn] for that.
  static int? extractAdmissionYearFromUsn(String usn) {
    final clean = usn.trim().toUpperCase();
    final match = RegExp(r'^\d[A-Z]{2}(\d{2})').firstMatch(clean);
    if (match != null) {
      final yearPart = match.group(1)!;
      return int.tryParse("20$yearPart");
    }
    return null;
  }

  /// Dynamically **estimates** the current study year (1–4) from a VTU-style USN
  /// by comparing the admission year digits to the current calendar date.
  ///
  /// **⚠️ UI PRE-FILL ONLY**: This is an estimate for UI convenience
  /// (e.g., pre-filling form dropdowns when adding a student manually).
  ///
  /// **🚫 NEVER** use this to:
  /// - Overwrite a student's `year` field in the database
  /// - Modify the USN string in any way
  /// - Determine the admission year portion of the USN
  /// - Replace the batch year embedded in the USN
  ///
  /// The student's `year` field should ALWAYS come from the CSV import
  /// or explicit user input. The USN itself must NEVER be altered.
  ///
  /// For example, `4MC22CS001` scanned in August 2025 → study year 4.
  /// The USN remains `4MC22CS001` — the '22' is NEVER changed to '25'.
  static int? inferCurrentStudyYearFromUsn(String usn) {
    final admissionYear = extractAdmissionYearFromUsn(usn);
    if (admissionYear != null) {
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;
      int studyYear = currentYear - admissionYear;
      if (currentMonth >= 8) {
        studyYear += 1;
      }
      if (studyYear >= 1 && studyYear <= 4) {
        return studyYear;
      }
    }
    return null;
  }

  static List<int> years = const [1, 2, 3, 4];

  static List<Map<String, dynamic>> calculateEventStandings(List<Map<String, dynamic>> results) {
    final allBranches = [
      'CSE', 'ISE', 'CI', 'CB', 'RI', 'ECE', 'VL', 'EI', 'EE', 'CV', 'ME'
    ];
    final branchDisplayNames = {
      'CSE': 'Computer Science',
      'ISE': 'Information Science',
      'CI': 'Artificial Intelligence and Machine Learning',
      'CB': 'Computer Science and Business Studies',
      'RI': 'Robotics & Intelligence',
      'ECE': 'Electronics & Communication',
      'VL': 'VLSI',
      'EI': 'Electronics & Instrumentation',
      'EE': 'Electrical & Electronics',
      'CV': 'Civil',
      'ME': 'Mechanical',
    };

    final points = <String, int>{};
    for (final b in allBranches) {
      points[b] = 0;
    }

    for (final res in results) {
      final reg = res['registrations'] as Map<String, dynamic>?;
      final student = reg != null ? reg['student_master'] as Map<String, dynamic>? : null;
      if (student == null) continue;

      final branch = (student['branch'] as String?)?.toUpperCase();
      if (branch == null || !allBranches.contains(branch)) continue;

      final position = res['position'] as String?;
      if (position == null) continue;

      int pts = 0;
      if (position == 'winner') {
        pts = 10;
      } else if (position == 'runner_up') pts = 7;
      else if (position == 'second_runner_up') pts = 5;
      else if (position == 'participation') pts = 1;

      points[branch] = (points[branch] ?? 0) + pts;
    }

    final sorted = points.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final standings = <Map<String, dynamic>>[];
    int rank = 1;
    for (int i = 0; i < sorted.length; i++) {
      final entry = sorted[i];
      if (i > 0 && entry.value < sorted[i - 1].value) {
        rank = i + 1;
      }
      standings.add({
        'branch': entry.key,
        'name': branchDisplayNames[entry.key] ?? entry.key,
        'points': entry.value,
        'rank': rank,
        'isTie': false,
      });
    }

    // Mark ties
    final rankCounts = <int, int>{};
    for (final s in standings) {
      final r = s['rank'] as int;
      rankCounts[r] = (rankCounts[r] ?? 0) + 1;
    }
    for (final s in standings) {
      final r = s['rank'] as int;
      s['isTie'] = (rankCounts[r] ?? 0) > 1;
    }

    return standings;
  }
}
