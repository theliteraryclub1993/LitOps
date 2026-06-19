import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

// ── Design Tokens ──────────────────────────────────────────────────────────
class LitColors {
  static const void_ = Color(0xFF0A0A0A);
  static const clay = Color(0xFF1D1A18);
  static const clay2 = Color(0xFF262220);
  static const clay3 = Color(0xFF312B27);
  static const border = Color(0xFF262220);
  static const bone = Color(0xFFF3ECE2);
  static const ash = Color(0xFF8C857C);
  static const ember = Color(0xFFFF6A2C);
  static const emberDark = Color(0xFFC2470F);
  static const amber = Color(0xFFFFB14D);
  static const moss = Color(0xFF6FAE8F);
  static const coral = Color(0xFFFF5C5C);
}

// ── Inset Shadow Painter ──────────────────────────────────────────────────
class InsetShadowPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final List<BoxShadow> insetShadows;

  InsetShadowPainter({
    required this.borderRadius,
    required this.insetShadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (insetShadows.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    for (final shadow in insetShadows) {
      final paint = Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius * 0.5);

      canvas.save();
      canvas.clipRRect(rrect);

      // Create an outer boundary then subtract the hole shifted by offset
      final outerRect = rect.inflate(shadow.blurRadius + shadow.spreadRadius + 50);
      final shadowPath = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(outerRect)
        ..addRRect(rrect.shift(shadow.offset));

      canvas.drawPath(shadowPath, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant InsetShadowPainter oldDelegate) {
    return borderRadius != oldDelegate.borderRadius || insetShadows != oldDelegate.insetShadows;
  }
}

class RadialGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6A2C).withOpacity(0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.18, 0), radius: size.width * 0.8));

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFB14D).withOpacity(0.07),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width, size.height * 0.2), radius: size.width * 0.7));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Claymorphic Widgets ────────────────────────────────────────────────────

class ClayCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;
  final double? width;
  final double? height;

  const ClayCard({
    super.key,
    required this.child,
    this.borderRadius = 18.0,
    this.padding,
    this.margin,
    this.onTap,
    this.borderColor,
    this.color,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(borderRadius);
    final bg = color ?? LitColors.clay;

    Widget content = child;

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    } else {
      content = Padding(padding: const EdgeInsets.all(14.0), child: content);
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          child: content,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: br,
        border: borderColor != null ? Border.all(color: borderColor!, width: 1.3) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            offset: const Offset(7, 7),
            blurRadius: 15,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.025),
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: content,
      ),
    );
  }
}

class ClayInsetCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderSide? border;
  final double? width;
  final double? height;

  const ClayInsetCard({
    super.key,
    required this.child,
    this.borderRadius = 18.0,
    this.padding,
    this.margin,
    this.color,
    this.border,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(borderRadius);
    final bg = color ?? LitColors.clay2;

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: br,
        border: border != null ? Border.fromBorderSide(border!) : null,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: CustomPaint(
          painter: InsetShadowPainter(
            borderRadius: br,
            insetShadows: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                offset: const Offset(5, 5),
                blurRadius: 11,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.02),
                offset: const Offset(-3, -3),
                blurRadius: 8,
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

class ClayButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isGhost;
  final bool isDanger;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const ClayButton({
    super.key,
    required this.child,
    this.onPressed,
    this.isPrimary = true,
    this.isGhost = false,
    this.isDanger = false,
    this.width,
    this.height,
    this.padding,
    this.borderRadius = 16.0,
  });

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onPressed == null;
    
    // Background style
    Decoration decoration;
    Color textColor = disabled ? LitColors.ash.withOpacity(0.5) : LitColors.bone;
    
    final br = BorderRadius.circular(widget.borderRadius);
    
    if (disabled) {
      decoration = BoxDecoration(
        color: LitColors.clay2.withOpacity(0.5),
        borderRadius: br,
      );
    } else if (widget.isGhost) {
      decoration = BoxDecoration(
        color: LitColors.clay2,
        borderRadius: br,
        boxShadow: _isPressed
            ? [
                BoxShadow(color: Colors.black.withOpacity(0.25), offset: const Offset(1.5, 1.5), blurRadius: 4),
              ]
            : [
                BoxShadow(color: Colors.black.withOpacity(0.5), offset: const Offset(5, 5), blurRadius: 11),
                BoxShadow(color: Colors.white.withOpacity(0.02), offset: const Offset(-3, -3), blurRadius: 7),
              ],
      );
    } else if (widget.isDanger) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [LitColors.coral, Color(0xFFA23A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: br,
        boxShadow: _isPressed
            ? [
                BoxShadow(color: Colors.black.withOpacity(0.25), offset: const Offset(1.5, 1.5), blurRadius: 4),
              ]
            : [
                BoxShadow(color: Colors.black.withOpacity(0.5), offset: const Offset(6, 6), blurRadius: 13),
              ],
      );
    } else {
      // Primary button
      textColor = const Color(0xFF1A0D05);
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [LitColors.ember, LitColors.emberDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: br,
        boxShadow: _isPressed
            ? [
                BoxShadow(color: Colors.black.withOpacity(0.25), offset: const Offset(1.5, 1.5), blurRadius: 4),
              ]
            : [
                BoxShadow(color: Colors.black.withOpacity(0.5), offset: const Offset(6, 6), blurRadius: 13),
              ],
      );
    }

    Widget content = widget.child;
    
    // Apply default styles for buttons
    content = DefaultTextStyle.merge(
      style: GoogleFonts.plusJakartaSans(
        color: textColor,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: textColor, size: 16),
        child: content,
      ),
    );

    // Apply inner shadow decoration on top for primary button
    if (!disabled && widget.isPrimary && !widget.isGhost && !widget.isDanger) {
      content = ClipRRect(
        borderRadius: br,
        child: CustomPaint(
          painter: InsetShadowPainter(
            borderRadius: br,
            insetShadows: [
              BoxShadow(color: Colors.white.withOpacity(0.35), offset: const Offset(1.5, 1.5), blurRadius: 2),
              BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(-1.5, -1.5), blurRadius: 4),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: content,
          ),
        ),
      );
    } else {
      content = Container(
        alignment: Alignment.center,
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: content,
      );
    }

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: disabled ? null : (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: disabled ? null : () => setState(() => _isPressed = false),
      child: Transform.translate(
        offset: _isPressed ? const Offset(2.0, 2.0) : Offset.zero,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: decoration,
          child: content,
        ),
      ),
    );
  }
}

class ClayTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onTap;
  final bool readOnly;
  final FocusNode? focusNode;
  final int? maxLines;

  const ClayTextField({
    super.key,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.onTap,
    this.readOnly = false,
    this.focusNode,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(14);
    return ClayInsetCard(
      borderRadius: 14,
      padding: EdgeInsets.zero,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        validator: validator,
        onTap: onTap,
        readOnly: readOnly,
        focusNode: focusNode,
        maxLines: maxLines,
        style: GoogleFonts.plusJakartaSans(
          color: LitColors.bone,
          fontSize: 12,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.plusJakartaSans(
            color: LitColors.ash.withOpacity(0.5),
            fontSize: 12,
          ),
          prefixIcon: prefixIcon != null
              ? IconTheme.merge(
                  data: const IconThemeData(color: LitColors.ash, size: 16),
                  child: prefixIcon!,
                )
              : null,
          suffixIcon: suffixIcon != null
              ? IconTheme.merge(
                  data: const IconThemeData(color: LitColors.ash, size: 16),
                  child: suffixIcon!,
                )
              : null,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: br,
            borderSide: const BorderSide(color: LitColors.ember, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class ClayProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0

  const ClayProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(8);
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: LitColors.clay3,
        borderRadius: br,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: CustomPaint(
          painter: InsetShadowPainter(
            borderRadius: br,
            insetShadows: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [LitColors.ember, LitColors.amber],
                  ),
                  borderRadius: br,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ClaySwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ClaySwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(20);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 34,
        height: 19,
        decoration: BoxDecoration(
          color: value ? null : LitColors.clay3,
          gradient: value
              ? const LinearGradient(
                  colors: [LitColors.ember, LitColors.emberDark],
                )
              : null,
          borderRadius: br,
        ),
        child: ClipRRect(
          borderRadius: br,
          child: CustomPaint(
            painter: InsetShadowPainter(
              borderRadius: br,
              insetShadows: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOut,
                  left: value ? 18.0 : 3.0,
                  top: 3.0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: value ? const Color(0xFF1A0D05) : LitColors.ash,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── LitLifeAppBar ──────────────────────────────────────────────────────────
class LitLifeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;

  const LitLifeAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        title,
        style: GoogleFonts.fredoka(
          fontWeight: FontWeight.w600,
          fontSize: 16.0,
          color: LitColors.bone,
        ),
      ),
      leading: showBack
          ? (leading ??
              IconButton(
                icon: const Icon(Icons.arrow_back, color: LitColors.bone),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/dashboard');
                  }
                },
              ))
          : null,
      automaticallyImplyLeading: showBack,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ── Loading, Error, Empty Views ──────────────────────────────────────────────
class LoadingView extends StatelessWidget {
  final String? message;

  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: LitColors.ember),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: GoogleFonts.plusJakartaSans(
                color: LitColors.ash,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: LitColors.coral),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: LitColors.bone,
                fontSize: 14,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ClayButton(
                onPressed: onRetry,
                width: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh, size: 16),
                    const SizedBox(width: 8),
                    const Text('Retry'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: LitColors.ash.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: LitColors.bone,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: LitColors.ash,
                  fontSize: 13,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── StatCard ───────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LitColors.clay2,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(4, 4),
            blurRadius: 9,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.02),
            offset: const Offset(-2, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.fredoka(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: LitColors.bone,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: LitColors.ash,
                  letterSpacing: 0.04,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chips ──────────────────────────────────────────────────────────────────
class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;

  const StatusChip({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    // Map status label to standard status colors matching html
    Color chipColor = LitColors.ash;
    final lower = label.toLowerCase().replaceAll(' ', '_');
    if (lower == 'ongoing' || lower == 'live') {
      chipColor = LitColors.ember;
    } else if (lower == 'reg._open' || lower == 'registration_open' || lower == 'completed' || lower == 'present') {
      chipColor = LitColors.moss;
    } else if (lower == 'pending') {
      chipColor = LitColors.amber;
    } else if (lower == 'danger' || lower == 'alert' || lower == 'incident' || lower.contains('pending')) {
      chipColor = LitColors.coral;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: chipColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.02,
        ),
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final String category;
  final bool active;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.category,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData getIcon(String cat) {
      switch (cat.toLowerCase()) {
        case 'balwaan':
          return Icons.fitness_center;
        case 'buddhimaan':
          return Icons.lightbulb_outline;
        case 'darpan':
          return Icons.mic_none;
        case 'kalakruthi':
          return Icons.palette_outlined;
        default:
          return Icons.event;
      }
    }

    if (active) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [LitColors.ember, LitColors.emberDark],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(3, 3),
                blurRadius: 7,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(getIcon(category), size: 13, color: const Color(0xFF1A0D05)),
              const SizedBox(width: 6),
              Text(
                category[0].toUpperCase() + category.substring(1),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF1A0D05),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: LitColors.clay2,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              offset: const Offset(3, 3),
              blurRadius: 7,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.02),
              offset: const Offset(-2, -2),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(getIcon(category), size: 13, color: LitColors.ember),
            const SizedBox(width: 6),
            Text(
              category[0].toUpperCase() + category.substring(1),
              style: GoogleFonts.plusJakartaSans(
                color: LitColors.bone,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SearchBar ──────────────────────────────────────────────────────────────
class LitSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const LitSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ClayTextField(
      controller: controller,
      hintText: hintText,
      prefixIcon: const Icon(Icons.search),
      onChanged: onChanged,
      suffixIcon: controller.text.isNotEmpty
          ? GestureDetector(
              child: const Icon(Icons.clear),
              onTap: () {
                controller.clear();
                onClear?.call();
                onChanged?.call('');
              },
            )
          : null,
    );
  }
}

// ── LitCard ────────────────────────────────────────────────────────────────
class LitCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;

  const LitCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      padding: padding,
      margin: margin,
      onTap: onTap,
      borderColor: borderColor,
      color: color,
      child: child,
    );
  }
}

// ── ConfirmDialog ──────────────────────────────────────────────────────────
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final Color? confirmColor;
  final VoidCallback onConfirm;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LitColors.clay,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: LitColors.border, width: 1.3),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: LitColors.bone,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.plusJakartaSans(color: LitColors.ash),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              cancelText,
              style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        ClayButton(
          width: 110,
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop(true);
          },
          isDanger: confirmColor == LitColors.coral,
          child: Text(confirmText),
        ),
      ],
    );
  }

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    required VoidCallback onConfirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        onConfirm: onConfirm,
      ),
    );
    return result ?? false;
  }
}

// ── UserAvatar ──────────────────────────────────────────────────────────────
class UserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;

  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: LitColors.clay3,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(3, 3),
            blurRadius: 6,
          ),
        ],
        image: imageUrl != null && imageUrl!.startsWith('http')
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: (imageUrl == null || !imageUrl!.startsWith('http'))
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: LitColors.amber,
              ),
            )
          : null,
    );
  }
}
