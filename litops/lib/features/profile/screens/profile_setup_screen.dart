import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/responsive.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;
  String? _debugError;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(currentProfileProvider);
      if (profile != null) {
        _nameController.text = profile.fullName;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    debugPrint('--- _saveProfile called ---');
    final isFormValid = _formKey.currentState!.validate();
    if (!isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Please fill in all required fields correctly',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: LitColors.coral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      setState(() => _debugError = null);
      final currentProfile = ref.read(currentProfileProvider);
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        throw Exception('No user session');
      }

      final profileData = <String, dynamic>{
        'id': user.id,
        'email': user.email,
        'full_name': _nameController.text.trim(),
        'profile_completed': true,
        'profile_status': 'pending_review',
      };

      debugPrint('--- SAVE PROFILE CLICKED ---');
      debugPrint('Update payload: $profileData');

      // Insert or update the profile
      await SupabaseConfig.client
          .from(SupabaseTables.profiles)
          .upsert(profileData, onConflict: 'id');

      // Refresh the profile
      await ref.read(authStateProvider.notifier).refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Profile saved! Waiting for admin approval.',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: LitColors.moss,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Navigate to dashboard
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _debugError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: LitColors.coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = SupabaseConfig.client.auth.currentUser;
    final r = context.r;

    return Scaffold(
      backgroundColor: LitColors.void_,
      body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: r.w(24), vertical: r.h(16)),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      // ── HEADER ──
                      SizedBox(height: r.h(8)),
                      Container(
                        padding: r.pageInsets,
                        decoration: BoxDecoration(
                          color: LitColors.clay2.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.radius(30)),
                          border: Border.all(
                            color: LitColors.clay2.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note_rounded, color: LitColors.amber, size: r.icon(18)),
                            SizedBox(width: r.w(8)),
                            Text(
                              'Profile Setup',
                              style: GoogleFonts.plusJakartaSans(
                                color: LitColors.amber,
                                fontSize: r.sp(13),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: r.h(20)),
                      Text(
                        'Complete Your Profile',
                        style: GoogleFonts.fredoka(
                          fontSize: r.sp(28),
                          fontWeight: FontWeight.w800,
                          color: LitColors.bone,
                        ),
                      ),
                      SizedBox(height: r.h(6)),
                      Text(
                        'Set up your identity',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: r.sp(14),
                          color: LitColors.ash,
                        ),
                      ),
                      SizedBox(height: r.h(32)),

                      // ── PERSONAL DETAILS ──
                      _buildSection(
                        context,
                        title: 'Personal Details',
                        icon: Icons.badge_outlined,
                        child: Column(
                          children: [
                            // Full Name
                            ClayTextField(
                              controller: _nameController,
                              hintText: 'Enter your full name',
                              prefixIcon: const Icon(Icons.person_outline_rounded),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Enter your full name' : null,
                            ),
                            SizedBox(height: r.h(14)),
                            // Email (Read-only)
                            _buildReadOnlyField(
                              context,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              value: user?.email ?? '',
                            ),
                            SizedBox(height: r.h(14)),
                            // User ID (Read-only)
                            _buildReadOnlyField(
                              context,
                              label: 'User ID',
                              icon: Icons.key_outlined,
                              value: user?.id ?? '',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: r.h(32)),

                      // ── SAVE BUTTON ──
                      ClayButton(
                        onPressed: authState.isLoading || _isSaving ? null : _saveProfile,
                        child: authState.isLoading || _isSaving
                            ? SizedBox(
                                height: r.w(22),
                                width: r.w(22),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Save Profile'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: LitColors.ash, size: r.icon(18)),
            SizedBox(width: r.w(8)),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: LitColors.ash,
                fontSize: r.sp(13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: r.h(12)),
        child,
      ],
    );
  }

  Widget _buildReadOnlyField(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String value,
  }) {
    final r = context.r;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: r.w(16), vertical: r.h(16)),
      decoration: BoxDecoration(
        color: LitColors.clay2.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(r.radius(14)),
        border: Border.all(
          color: LitColors.clay2,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: LitColors.ash, size: r.icon(18)),
              SizedBox(width: r.w(8)),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: LitColors.ash,
                  fontSize: r.sp(12),
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(6)),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: LitColors.bone,
              fontSize: r.sp(15),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}