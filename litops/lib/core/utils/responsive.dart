import 'package:flutter/material.dart';

/// Responsive utility for scaling UI elements based on screen size.
///
/// Design base: 375 x 812 (iPhone 13 mini / SE 3rd gen).
/// All hardcoded pixel values in the codebase were authored against this base.
///
/// Usage:
///   final r = Responsive(context);
///   Text('Hello', style: TextStyle(fontSize: r.sp(14)));
///   SizedBox(width: r.w(16));
///   Padding(padding: EdgeInsets.all(r.w(16)));
///
/// Or with the BuildContext extension:
///   context.r.sp(14)
///   context.r.w(16)
class Responsive {
  static const double _designWidth = 375.0;
  static const double _designHeight = 812.0;

  final double screenWidth;
  final double screenHeight;
  final double textScaleFactor;

  Responsive._(this.screenWidth, this.screenHeight, this.textScaleFactor);

  factory Responsive(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Responsive._(
      mq.size.width,
      mq.size.height,
      mq.textScaler.scale(1.0),
    );
  }

  // ── Scale Factors ────────────────────────────────────────────────────

  /// Width-based scale factor (clamped to avoid extreme scaling)
  double get scaleWidth => (screenWidth / _designWidth).clamp(0.8, 1.4);

  /// Height-based scale factor
  double get scaleHeight => (screenHeight / _designHeight).clamp(0.8, 1.4);

  /// Average scale (useful for icons, border radius, etc.)
  double get scale => (scaleWidth + scaleHeight) / 2;

  // ── Scaled Values ───────────────────────────────────────────────────

  /// Scale a width/horizontal value proportionally.
  double w(num value) => value * scaleWidth;

  /// Scale a height/vertical value proportionally.
  double h(num value) => value * scaleHeight;

  /// Scale a font size proportionally (uses width scale to keep text
  /// readable regardless of phone height differences).
  double sp(num value) => value * scaleWidth;

  /// Scale an icon size.
  double icon(num value) => value * scale;

  /// Scale a border radius.
  double radius(num value) => value * scale;

  // ── Breakpoint Helpers ──────────────────────────────────────────────

  /// True on very small phones (width < 340px, e.g. iPhone SE 1st gen)
  bool get isSmall => screenWidth < 340;

  /// True on standard phones (340-400px)
  bool get isMedium => screenWidth >= 340 && screenWidth < 400;

  /// True on large phones / small tablets (>= 400px)
  bool get isLarge => screenWidth >= 400;

  /// True on tablets (>= 600px width)
  bool get isTablet => screenWidth >= 600;

  // ── Layout Helpers ──────────────────────────────────────────────────

  /// Dynamic grid column count based on screen width.
  int gridColumns({int small = 2, int medium = 3, int large = 4}) {
    if (isTablet) return large;
    if (isLarge) return medium;
    if (isSmall) return small;
    return medium;
  }

  /// Horizontal padding that adapts to screen width.
  double get pagePadding => w(16);

  /// Bottom padding for lists that accounts for the floating navbar.
  double get listBottomPadding => h(130);

  /// Responsive EdgeInsets for page content.
  EdgeInsets get pageInsets => EdgeInsets.symmetric(
        horizontal: pagePadding,
        vertical: h(10),
      );
}

/// Extension to conveniently access Responsive from BuildContext.
extension ResponsiveContext on BuildContext {
  Responsive get r => Responsive(this);
}
