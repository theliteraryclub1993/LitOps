import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/responsive.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(authStateProvider.notifier)
        .resetPassword(_emailController.text.trim());

    final error = ref.read(authStateProvider).error;
    if (error == null) {
      setState(() => _emailSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: LitColors.coral,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            child: CustomPaint(
              painter: RadialGlowPainter(),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Back button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => context.go('/login'),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: LitColors.bone),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Icon Container
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _emailSent ? LitColors.moss : LitColors.clay2,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(4, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _emailSent
                              ? Icons.mark_email_read_rounded
                              : Icons.lock_reset_rounded,
                          size: 32,
                          color: _emailSent ? const Color(0xFF1A0D05) : LitColors.ember,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        _emailSent ? 'Check Your Email' : 'Reset Password',
                        style: GoogleFonts.fredoka(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: LitColors.bone,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _emailSent
                            ? 'We\'ve sent a password reset link to\n${_emailController.text.trim()}'
                            : 'Enter your email address and we\'ll send\nyou a link to reset your password.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: LitColors.ash,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      if (!_emailSent) ...[
                        // Recessed input and button card
                        ClayCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              ClayTextField(
                                controller: _emailController,
                                hintText: 'Email Address',
                                prefixIcon: const Icon(Icons.email_outlined),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Enter your email';
                                  }
                                  if (!v.contains('@')) return 'Invalid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              ClayButton(
                                onPressed: authState.isLoading ? null : _handleReset,
                                child: authState.isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFF1A0D05),
                                          ),
                                        ),
                                      )
                                    : const Text('Send Reset Link'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Success state
                        ClayCard(
                          color: LitColors.clay2,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                'Didn\'t receive the email?',
                                style: GoogleFonts.plusJakartaSans(
                                  color: LitColors.ash,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => setState(() => _emailSent = false),
                                child: Text(
                                  'Try Again',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: LitColors.ember,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          '← Back to Sign In',
                          style: GoogleFonts.plusJakartaSans(
                            color: LitColors.ash,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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
