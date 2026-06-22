import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  final double bottomSafeArea;
  final bool hasNavbar;

  Responsive._({
    required this.screenWidth,
    required this.screenHeight,
    required this.textScaleFactor,
    required this.bottomSafeArea,
    required this.hasNavbar,
  });

  factory Responsive(BuildContext context) {
    final mq = MediaQuery.of(context);
    bool hasNavbar = false;
    try {
      final state = GoRouterState.of(context);
      hasNavbar = routesWithNavbar.contains(state.matchedLocation);
    } catch (_) {}

    return Responsive._(
      screenWidth: mq.size.width,
      screenHeight: mq.size.height,
      textScaleFactor: mq.textScaler.scale(1.0),
      bottomSafeArea: mq.padding.bottom,
      hasNavbar: hasNavbar,
    );
  }

  static const Set<String> routesWithNavbar = {
    '/dashboard',
    '/events',
    '/leaderboard',
    '/profile',
    '/students',
    '/registration',
    '/attendance',
    '/assignments',
    '/results',
    '/rounds',
    '/certificates',
    '/feedback',
    '/appeals',
    '/analytics',
    '/settings',
    '/admin',
    '/rulebook/view',
    '/scheduling',
  };

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

  /// The height of the custom floating bottom navigation bar.
  double get navbarHeight => h(72);

  /// The bottom margin of the custom floating bottom navigation bar.
  double get navbarMargin => h(24);

  /// Dynamically calculates bottom spacing required to fully clear either
  /// the custom floating bottom navigation bar or the system safe area.
  double bottomSpacing({double extra = 16.0, bool? forceNavbar}) {
    final useNavbar = forceNavbar ?? hasNavbar;
    if (useNavbar) {
      return navbarHeight + navbarMargin + bottomSafeArea + h(extra);
    } else {
      return bottomSafeArea + h(extra);
    }
  }

  /// Bottom padding for lists that accounts for the floating navbar.
  double get listBottomPadding => bottomSpacing();

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
