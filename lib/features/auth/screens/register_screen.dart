import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  DateTime? _selectedDob;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your Date of Birth'),
          backgroundColor: LitColors.amber,
        ),
      );
      return;
    }
    await ref.read(authStateProvider.notifier).signUp(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
          _selectedDob!,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        if (next.error == 'REGISTRATION_SUCCESS') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Please sign in.'),
              backgroundColor: LitColors.moss,
              duration: Duration(seconds: 3),
            ),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              GoRouter.of(context).go('/login');
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.error!), backgroundColor: LitColors.coral),
          );
        }
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
                      // MCE Tag Box
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: LitColors.clay2,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(4, 4),
                              blurRadius: 9,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'LIT',
                          style: GoogleFonts.fredoka(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: LitColors.ember,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Join LitOps',
                        style: GoogleFonts.fredoka(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: LitColors.bone,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create an account to participate',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: LitColors.ash,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Register Card
                      ClayCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Register',
                              style: GoogleFonts.fredoka(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: LitColors.bone,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Full name
                            ClayTextField(
                              controller: _nameController,
                              hintText: 'Full Name',
                              prefixIcon: const Icon(Icons.person_outline),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Enter your name' : null,
                            ),
                            const SizedBox(height: 12),

                            // Email
                            ClayTextField(
                              controller: _emailController,
                              hintText: 'College Email / USN Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Enter email' : null,
                            ),
                            const SizedBox(height: 12),

                            // Date of Birth
                            InkWell(
                              onTap: () async {
                                final now = DateTime.now();
                                final firstDate = DateTime(1900);
                                final lastDate = DateTime(now.year - 10);
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDob ?? DateTime(2004, 1, 1),
                                  firstDate: firstDate,
                                  lastDate: lastDate,
                                );
                                if (picked != null) {
                                  setState(() => _selectedDob = picked);
                                }
                              },
                              child: ClayInsetCard(
                                borderRadius: 14,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, color: LitColors.ash, size: 16),
                                    const SizedBox(width: 12),
                                    Text(
                                      _selectedDob == null
                                          ? 'Select Date of Birth'
                                          : "${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: _selectedDob == null ? LitColors.ash.withOpacity(0.5) : LitColors.bone,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Password
                            ClayTextField(
                              controller: _passwordController,
                              hintText: 'Password',
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
                                  v == null || v.length < 6 ? 'Password must be 6+ chars' : null,
                            ),
                            const SizedBox(height: 20),

                            // Register button
                            ClayButton(
                              onPressed: authState.isLoading ? null : _handleRegister,
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
                                  : const Text('Register'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      // Already have account
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: GoogleFonts.plusJakartaSans(
                              color: LitColors.ash,
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              'Login',
                              style: GoogleFonts.plusJakartaSans(
                                color: LitColors.ember,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
