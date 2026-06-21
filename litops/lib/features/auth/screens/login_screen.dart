import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/responsive.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
    ));
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authStateProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text,
          rememberMe: _rememberMe,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final r = context.r;

    ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: r.icon(20)),
                SizedBox(width: r.w(10)),
                Expanded(child: Text(next.error!)),
              ],
            ),
            backgroundColor: LitColors.coral,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(r.w(16)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.radius(14))),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: LitColors.void_,
      body: Stack(
        children: [
          // Background Glows
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _LoginGlowPainter(glowOpacity: _glowAnimation.value),
                );
              },
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: r.w(24), vertical: r.h(16)),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: r.h(12)),
                          // MCE Tag Box
                          Container(
                            width: r.w(46),
                            height: r.w(46),
                            decoration: BoxDecoration(
                              color: LitColors.clay2,
                              borderRadius: BorderRadius.circular(r.radius(14)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  offset: Offset(r.w(4), r.w(4)),
                                  blurRadius: r.radius(9),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'MCE',
                              style: GoogleFonts.fredoka(
                                fontSize: r.sp(13),
                                fontWeight: FontWeight.bold,
                                color: LitColors.amber,
                              ),
                            ),
                          ),
                          SizedBox(height: r.h(12)),
                          Text(
                            'Welcome back',
                            style: GoogleFonts.fredoka(
                              fontSize: r.sp(22),
                              fontWeight: FontWeight.w600,
                              color: LitColors.bone,
                            ),
                          ),
                          SizedBox(height: r.h(4)),
                          Text(
                            'Sign in to run the fest',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: r.sp(12),
                              color: LitColors.ash,
                            ),
                          ),
                          SizedBox(height: r.h(32)),

                          // Email
                          ClayTextField(
                            controller: _emailController,
                            hintText: 'USN or college email',
                            prefixIcon: const Icon(Icons.person_outline),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Please enter your email/USN' : null,
                          ),
                          SizedBox(height: r.h(12)),

                          // Password
                          ClayTextField(
                            controller: _passwordController,
                            hintText: '••••••••••',
                            obscureText: _obscurePassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                              child: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Please enter your password' : null,
                          ),
                          SizedBox(height: r.h(10)),

                          // Remember Me & Forgot Password Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                child: Row(
                                  children: [
                                    Container(
                                      width: r.w(18),
                                      height: r.w(18),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(r.radius(5)),
                                        border: Border.all(
                                          color: _rememberMe ? LitColors.ember : LitColors.ash.withValues(alpha: 0.4),
                                          width: 1.5,
                                        ),
                                        color: _rememberMe ? LitColors.ember : Colors.transparent,
                                      ),
                                      child: _rememberMe
                                          ? Icon(Icons.check, size: r.icon(12), color: Colors.white)
                                          : null,
                                    ),
                                    SizedBox(width: r.w(8)),
                                    Text(
                                      'Remember me',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: LitColors.ash,
                                        fontSize: r.sp(12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/forgot-password'),
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: LitColors.amber,
                                    fontSize: r.sp(11),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: r.h(24)),

                          // Sign In Button
                          ClayButton(
                            onPressed: authState.isLoading ? null : _handleLogin,
                            child: authState.isLoading
                                ? SizedBox(
                                    height: r.w(18),
                                    width: r.w(18),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF1A0D05),
                                      ),
                                    ),
                                  )
                                : const Text('Sign In'),
                          ),
                          
                          SizedBox(height: r.h(16)),
                          Row(
                            children: [
                              Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08))),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: r.w(10)),
                                child: Text(
                                  'or',
                                  style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(10)),
                                ),
                              ),
                              Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08))),
                            ],
                          ),
                          SizedBox(height: r.h(16)),

                          // Tap ID Card Button
                          ClayButton(
                            isGhost: true,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('NFC/ID scanning is currently mock-only. Use credentials.'),
                                  backgroundColor: LitColors.clay2,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.radius(10))),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_scanner, size: r.icon(14)),
                                SizedBox(width: r.w(8)),
                                const Text('Tap College ID Card'),
                              ],
                            ),
                          ),

                          SizedBox(height: r.h(20)),
                          // Info Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shield_outlined, color: LitColors.ash, size: r.icon(11)),
                              SizedBox(width: r.w(4)),
                              Flexible(
                                child: Text(
                                  'Access is role-based · secured by Supabase Auth',
                                  style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(10)),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: r.h(32)),
                          // Create account link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'New here? ',
                                style: GoogleFonts.plusJakartaSans(
                                  color: LitColors.ash,
                                  fontSize: r.sp(13),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/register'),
                                child: Text(
                                  'Create an account',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: LitColors.ember,
                                    fontSize: r.sp(13),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: r.h(24)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginGlowPainter extends CustomPainter {
  final double glowOpacity;

  _LoginGlowPainter({required this.glowOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6A2C).withValues(alpha: glowOpacity * 0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.85, size.height * 0.1),
        radius: size.width * 0.5,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFB14D).withValues(alpha: glowOpacity * 0.07),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.1, size.height * 0.85),
        radius: size.width * 0.45,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
  }

  @override
  bool shouldRepaint(_LoginGlowPainter oldDelegate) =>
      oldDelegate.glowOpacity != glowOpacity;
}
