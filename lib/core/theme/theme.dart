import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _primaryColor = Color(0xFFFF6A2C); // Ember
  static const _secondaryColor = Color(0xFFFFB14D); // Amber
  static const _accentColor = Color(0xFF6FAE8F); // Moss
  static const _surfaceColor = Color(0xFF0A0A0A); // Void / Black
  static const _cardColor = Color(0xFF1D1A18); // Clay
  static const _errorColor = Color(0xFFFF5C5C); // Coral

  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: _surfaceColor,
    cardColor: _cardColor,
    colorScheme: const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: _primaryColor,
      secondary: _secondaryColor,
      surface: _cardColor,
      error: _errorColor,
      onPrimary: Color(0xFF1A0D05),
      onSecondary: Color(0xFF1A0D05),
      onSurface: Color(0xFFF3ECE2),
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.fredoka(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFF3ECE2),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: const Color(0xFFF3ECE2),
      iconTheme: const IconThemeData(color: Color(0xFFF3ECE2)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF262220), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
    ),
  );

  static final darkTheme = lightTheme;

  // Category colors matching the design system
  static const balwaanColor = Color(0xFFFF6A2C); // Ember
  static const buddhimaanColor = Color(0xFFFFB14D); // Amber
  static const darpanColor = Color(0xFFEC4899); // Pink
  static const kalakruthiColor = Color(0xFF6FAE8F); // Moss

  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'balwaan':
        return balwaanColor;
      case 'buddhimaan':
        return buddhimaanColor;
      case 'darpan':
        return darpanColor;
      case 'kalakruthi':
        return kalakruthiColor;
      default:
        return _primaryColor;
    }
  }

  // Status colors
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return const Color(0xFF8C857C); // ash
      case 'upcoming':
        return const Color(0xFFFFB14D); // amber
      case 'registration_open':
        return const Color(0xFF6FAE8F); // moss
      case 'registration_closed':
        return const Color(0xFFFF6A2C); // ember
      case 'ongoing':
        return const Color(0xFFFF6A2C); // ember
      case 'completed':
        return const Color(0xFF6FAE8F); // moss
      case 'results_published':
        return const Color(0xFF6FAE8F); // moss
      case 'archived':
        return const Color(0xFF8C857C); // ash
      default:
        return const Color(0xFF8C857C);
    }
  }
}
