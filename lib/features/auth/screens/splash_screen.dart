import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authState = ref.read(authStateProvider);
    if (authState.isAuthenticated) {
      context.go('/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LitColors.void_,
      body: Stack(
        children: [
          // Background Glows
          Positioned.fill(
            child: CustomPaint(
              painter: RadialGlowPainter(),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Dashed outline clay container
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: LitColors.clay,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: LitColors.ember,
                        width: 2.0,
                        style: BorderStyle.solid, // Flutter doesn't have native dashed border without package, we use solid with opacity or custom paint.
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          offset: const Offset(8, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'LIT',
                      style: GoogleFonts.fredoka(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: LitColors.ember,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'LitLife',
                    style: GoogleFonts.fredoka(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: LitColors.bone,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Malnad Fest, operated.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: LitColors.ash,
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          // Footer
          Positioned(
            bottom: 34,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(120, 14),
                    painter: WavyLinePainter(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'v2.4.0 · Malnad Fest Build',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      color: LitColors.ash,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class WavyLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LitColors.ember.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    double w = size.width;
    double h = size.height;
    path.moveTo(0, h * 0.5);
    path.cubicTo(w * 0.15, h * 0.0, w * 0.15, h * 1.0, w * 0.3, h * 0.5);
    path.cubicTo(w * 0.45, h * 0.0, w * 0.45, h * 1.0, w * 0.6, h * 0.5);
    path.cubicTo(w * 0.75, h * 0.0, w * 0.75, h * 1.0, w * 0.9, h * 0.5);
    path.lineTo(w, h * 0.5);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
