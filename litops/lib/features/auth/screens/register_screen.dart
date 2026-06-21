import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/responsive.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Passwords do not match!')),
            ],
          ),
          backgroundColor: LitColors.coral,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }
    await ref.read(authStateProvider.notifier).signUp(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final r = context.r;

    ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        if (next.error == 'REGISTRATION_SUCCESS') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: r.icon(20)),
                  SizedBox(width: r.w(10)),
                  Expanded(child: Text('Registration successful! Please sign in.')),
                ],
              ),
              backgroundColor: LitColors.moss,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(r.w(16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.radius(14))),
            ),
          );
          context.go('/login');
        } else {
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
      }
    });

    return Scaffold(
      backgroundColor: LitColors.void_,
      body: SafeArea(
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
                        'Create an account',
                        style: GoogleFonts.fredoka(
                          fontSize: r.sp(22),
                          fontWeight: FontWeight.w600,
                          color: LitColors.bone,
                        ),
                      ),
                      SizedBox(height: r.h(4)),
                      Text(
                        'Join the fest operations',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: r.sp(12),
                          color: LitColors.ash,
                        ),
                      ),
                      SizedBox(height: r.h(32)),

                      // Email
                      ClayTextField(
                        controller: _emailController,
                        hintText: 'College email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Please enter your email' : null,
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
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: r.h(12)),

                      // Confirm Password
                      ClayTextField(
                        controller: _confirmPasswordController,
                        hintText: '••••••••••',
                        obscureText: _obscureConfirmPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          child: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Please confirm your password' : null,
                      ),

                      SizedBox(height: r.h(24)),

                      // Register Button
                      ClayButton(
                        onPressed: authState.isLoading ? null : _handleRegister,
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
                            : const Text('Create Account'),
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

                      SizedBox(height: r.h(20)),
                      // Info Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, color: LitColors.ash, size: r.icon(11)),
                          SizedBox(width: r.w(4)),
                          Text(
                            'Secured by Supabase Auth',
                            style: GoogleFonts.plusJakartaSans(color: LitColors.ash, fontSize: r.sp(10)),
                          ),
                        ],
                      ),

                      SizedBox(height: r.h(32)),
                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: GoogleFonts.plusJakartaSans(
                              color: LitColors.ash,
                              fontSize: r.sp(13),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              'Sign in',
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
    );
  }
}