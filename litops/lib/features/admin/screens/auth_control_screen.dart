import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/admin_providers.dart';
import '../../auth/providers/auth_settings_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/responsive.dart';

class AuthControlScreen extends ConsumerStatefulWidget {
  const AuthControlScreen({super.key});

  @override
  ConsumerState<AuthControlScreen> createState() => _AuthControlScreenState();
}

class _AuthControlScreenState extends ConsumerState<AuthControlScreen> {
  final _messageController = TextEditingController();
  bool _isSavingMessage = false;
  bool _isTogglingSignIn = false;
  bool _isTogglingRegistration = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _toggleSignIn(bool enabled) async {
    setState(() => _isTogglingSignIn = true);
    try {
      await ref.read(adminControllerProvider).toggleSignIn(enabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled ? 'Sign-in is now open' : 'Sign-in is now closed'),
            backgroundColor: enabled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update sign-in setting: $e'),
            backgroundColor: LitColors.coral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingSignIn = false);
    }
  }

  Future<void> _toggleRegistration(bool enabled) async {
    setState(() => _isTogglingRegistration = true);
    try {
      await ref.read(adminControllerProvider).toggleRegistration(enabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled ? 'Registration is now open' : 'Registration is now closed'),
            backgroundColor: enabled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update registration setting: $e'),
            backgroundColor: LitColors.coral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingRegistration = false);
    }
  }

  Future<void> _saveMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message cannot be empty'),
          backgroundColor: LitColors.coral,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSavingMessage = true);
    try {
      await ref.read(adminControllerProvider).updateSignInDisabledMessage(message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maintenance message saved'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save message: $e'),
            backgroundColor: LitColors.coral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingMessage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final settingsAsync = ref.watch(authSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Authentication Control',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF3ECE2),
            fontWeight: FontWeight.bold,
            fontSize: r.sp(18),
          ),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load auth settings.\nRun supabase/app_settings.sql in your project.\n\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
        data: (settings) {
          if (_messageController.text.isEmpty) {
            _messageController.text = settings.signInDisabledMessage;
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(r.w(20), r.h(8), r.w(20), r.h(32)),
            children: [
              Text(
                'Control who can sign in or register. Super Admin can always sign in, even when sign-in is closed.',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C857C),
                  fontSize: r.sp(13),
                  height: 1.5,
                ),
              ),
              SizedBox(height: r.h(20)),
              _buildControlCard(
                context,
                title: 'Sign In',
                subtitle: settings.signInEnabled
                    ? 'Users can sign in to LitOps'
                    : 'Sign-in is closed for all users except Super Admin',
                icon: Icons.login_rounded,
                accentColor: settings.signInEnabled
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                value: settings.signInEnabled,
                isLoading: _isTogglingSignIn,
                onChanged: _toggleSignIn,
              ),
              SizedBox(height: r.h(16)),
              _buildControlCard(
                context,
                title: 'New Registrations',
                subtitle: settings.registrationEnabled
                    ? 'New users can create accounts'
                    : 'Account creation is disabled',
                icon: Icons.person_add_alt_1_rounded,
                accentColor: settings.registrationEnabled
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                value: settings.registrationEnabled,
                isLoading: _isTogglingRegistration,
                onChanged: _toggleRegistration,
              ),
              SizedBox(height: r.h(24)),
              Text(
                'Sign-in closed message',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF3ECE2),
                  fontSize: r.sp(15),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: r.h(8)),
              Text(
                'Shown on the login screen when sign-in is disabled.',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C857C),
                  fontSize: r.sp(12),
                ),
              ),
              SizedBox(height: r.h(12)),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1A18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF262220)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFF3ECE2),
                        fontSize: r.sp(13),
                      ),
                      decoration: InputDecoration(
                        hintText: AuthSettings.defaultSignInDisabledMessage,
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C857C),
                          fontSize: r.sp(12),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isSavingMessage ? null : _saveMessage,
                        child: _isSavingMessage
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Save message',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFFF6A2C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControlCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool value,
    required bool isLoading,
    required ValueChanged<bool> onChanged,
  }) {
    final r = Responsive(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262220)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          SizedBox(width: r.w(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF3ECE2),
                    fontSize: r.sp(15),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C857C),
                    fontSize: r.sp(11),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ClaySwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
