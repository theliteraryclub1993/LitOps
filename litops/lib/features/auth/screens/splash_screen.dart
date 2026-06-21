import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/responsive.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();
    
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeIn,
      ),
    );

    _textSlide = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    _runAnimations();
  }

  Future<void> _runAnimations() async {
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    _textController.forward();
    
    await Future.delayed(const Duration(milliseconds: 1800));
    _checkAuth();
  }

  Future<void> _checkAuth() async {
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
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Scaffold(
      backgroundColor: Colors.black, // Matching the exact black background of the logo
      body: Stack(
        children: [
          // Background ambient glows (subtle)
          Positioned.fill(
            child: CustomPaint(
              painter: RadialGlowPainter(),
            ),
          ),
          
          // Central Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Exact Logo Image from assets
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoFade.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: r.w(200),
                          height: r.w(200),
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
                
                SizedBox(height: r.h(80)),
              ],
            ),
          ),
          
          // Bottom Branding Footer
          Positioned(
            bottom: r.h(34),
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textFade.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: Size(r.w(120), r.h(14)),
                        painter: WavyLinePainter(),
                      ),
                      SizedBox(height: r.h(10)),
                      Text(
                        'v2.4.0 · Malnad Fest Build',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: r.sp(10),
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
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
      ..color = const Color(0xFFFF6A2C).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
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
