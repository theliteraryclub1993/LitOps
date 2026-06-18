import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  // Avatar color palettes matching the setup screen
  static const List<List<Color>> _avatarGradients = [
    [Color(0xFFFF6A2C), Color(0xFFFFB14D)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFF10B981), Color(0xFF34D399)],
    [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    [Color(0xFFEF4444), Color(0xFFF87171)],
    [Color(0xFF06B6D4), Color(0xFF22D3EE)],
    [Color(0xFFD946EF), Color(0xFFE879F9)],
  ];

  static const List<IconData> _avatarIcons = [
    Icons.person_rounded,
    Icons.face_rounded,
    Icons.emoji_emotions_rounded,
    Icons.school_rounded,
    Icons.star_rounded,
    Icons.local_fire_department_rounded,
    Icons.auto_awesome_rounded,
    Icons.psychology_rounded,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    if (profile == null) {
      return const Scaffold(
        body: Center(child: LoadingView()),
      );
    }

    // Extract selected avatar index
    int avatarIndex = 0;
    if (profile.photoUrl != null && profile.photoUrl!.startsWith('avatar:')) {
      final parsed = int.tryParse(profile.photoUrl!.split(':').last);
      if (parsed != null && parsed >= 0 && parsed < _avatarGradients.length) {
        avatarIndex = parsed;
      }
    }

    final String friendlyYear = profile.year != null 
        ? ['First Year', 'Second Year', 'Third Year', 'Fourth Year'][profile.year! - 1]
        : 'Not set';

    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Member Profile',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.bold,
            color: LitColors.bone,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: LitColors.bone),
            tooltip: 'Edit Profile',
            onPressed: () => context.push('/profile-setup'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            // ── AVATAR DISPLAY ──
            const SizedBox(height: 10),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: (profile.photoUrl != null && !profile.photoUrl!.startsWith('avatar:'))
                          ? Colors.grey.shade900
                          : null,
                      gradient: (profile.photoUrl == null || profile.photoUrl!.startsWith('avatar:'))
                          ? LinearGradient(
                              colors: _avatarGradients[avatarIndex],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      shape: BoxShape.circle,
                      border: Border.all(color: LitColors.border, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: (profile.photoUrl == null || profile.photoUrl!.startsWith('avatar:'))
                              ? _avatarGradients[avatarIndex][0].withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.5),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      image: (profile.photoUrl != null && !profile.photoUrl!.startsWith('avatar:'))
                          ? DecorationImage(
                              image: NetworkImage(profile.photoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (profile.photoUrl == null || profile.photoUrl!.startsWith('avatar:'))
                        ? Icon(
                            _avatarIcons[avatarIndex],
                            size: 56,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  GestureDetector(
                    onTap: () => context.push('/profile-setup'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: LitColors.ember,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Name and Post Label
            Text(
              profile.fullName,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: LitColors.bone,
              ),
            ),
            const SizedBox(height: 8),
            
            // Badges Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Post Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: LitColors.ember.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: LitColors.ember.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, color: LitColors.ember, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        profile.role.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: LitColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Year Badge
                if (profile.year != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: LitColors.moss.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: LitColors.moss.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school_rounded, color: LitColors.moss, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          friendlyYear,
                          style: GoogleFonts.plusJakartaSans(
                            color: LitColors.moss,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            // ── PERSONAL INFORMATION SECTION ──
            _buildSectionHeader('Details & Contact', Icons.badge_outlined),
            const SizedBox(height: 12),
            _buildClayCard(
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.email_outlined,
                    title: 'Email Address',
                    value: profile.email,
                  ),
                  _buildDivider(),
                  _buildInfoTile(
                    icon: Icons.phone_outlined,
                    title: 'Phone Number',
                    value: profile.phone ?? 'Not set',
                  ),
                  _buildDivider(),
                  _buildInfoTile(
                    icon: Icons.cake_outlined,
                    title: 'Date of Birth',
                    value: profile.dateOfBirth != null
                        ? DateFormat('MMMM d, yyyy').format(profile.dateOfBirth!)
                        : 'Not set',
                  ),
                  if (!profile.role.isSuperAdmin) ...[
                    _buildDivider(),
                    _buildInfoTile(
                      icon: Icons.badge_outlined,
                      title: 'USN',
                      value: profile.usn ?? 'Not set',
                    ),
                  ],
                  _buildDivider(),
                  _buildInfoTile(
                    icon: Icons.calendar_today_outlined,
                    title: 'Academic Year',
                    value: friendlyYear,
                  ),
                  _buildDivider(),
                  _buildInfoTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Club Position',
                    value: profile.role.label,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── SECURITY & SESSION ──
            _buildSectionHeader('Session details', Icons.security_rounded),
            const SizedBox(height: 12),
            _buildClayCard(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: LitColors.moss.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.devices_rounded, color: LitColors.moss, size: 20),
                    ),
                    title: Text(
                      'Current Active Session',
                      style: GoogleFonts.plusJakartaSans(
                        color: LitColors.bone,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'This Device • Secure Supabase Login',
                      style: GoogleFonts.plusJakartaSans(
                        color: LitColors.ash,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (profile.role.isSuperAdmin) ...[
                    _buildDivider(),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: LitColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.dvr_rounded, color: LitColors.amber, size: 20),
                      ),
                      title: Text(
                        'Manage Active Sessions',
                        style: GoogleFonts.plusJakartaSans(
                          color: LitColors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: LitColors.amber),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All device sessions are currently active and healthy.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── SYSTEM SETTINGS & UTILITIES ──
            _buildSectionHeader('App Settings & Verification', Icons.settings_outlined),
            const SizedBox(height: 12),
            _buildClayCard(
              child: Column(
                children: [
                  _buildActionTile(
                    context: context,
                    icon: Icons.settings_suggest_outlined,
                    title: 'Settings',
                    subtitle: 'Change app preferences',
                    onTap: () => context.push('/settings'),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    context: context,
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Verify Certificate',
                    subtitle: 'Scan QR to check validity',
                    onTap: () => context.push('/verify/'),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    context: context,
                    icon: Icons.info_outline_rounded,
                    title: 'About Lit Life',
                    subtitle: 'Version 1.0.0 (Stable Build)',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Lit Life',
                        applicationVersion: '1.0.0',
                        applicationIcon: Image.asset(
                          'assets/images/logo.png',
                          width: 48,
                          height: 48,
                          errorBuilder: (c, e, s) => Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: LitColors.ember,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.import_contacts, color: Colors.white),
                          ),
                        ),
                        children: [
                          Text(
                            'Lit Life is the official operations and database management application for The Literary Club.',
                            style: TextStyle(color: LitColors.ash),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: LitColors.ember, size: 18),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: LitColors.ember,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildClayCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: LitColors.clay,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LitColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: LitColors.clay2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: LitColors.ash, size: 18),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: LitColors.ash,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: LitColors.bone,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: LitColors.ember.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: LitColors.ember, size: 18),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: LitColors.bone,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            color: LitColors.ash,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: LitColors.ash, size: 18),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: LitColors.border,
      indent: 16,
      endIndent: 16,
    );
  }
}


