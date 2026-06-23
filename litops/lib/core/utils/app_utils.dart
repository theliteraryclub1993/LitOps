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
    final clean = rawValue.trim();
    if (clean.isEmpty) return '';

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
    'CS', 'IS', 'CI', 'CB', 'RI', 'EC', 'VL', 'EI', 'EE', 'CV', 'ME'
  ];

  static List<int> years = const [1, 2, 3, 4];
}
