import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/models/models.dart';
import '../../../core/enums/enums.dart';
import '../widgets/profile_picture_editor.dart';
import '../../../core/utils/responsive.dart';


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

    final r = context.r;

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
            onPressed: () => _showEditProfileDialog(context, ref, profile),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: r.w(20), vertical: r.h(8)),
        child: Column(
          children: [
            // ── AVATAR DISPLAY ──
            SizedBox(height: r.h(10)),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: r.w(120),
                    height: r.w(120),
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
                          blurRadius: r.radius(28),
                          offset: Offset(0, r.h(10)),
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
                            size: r.icon(56),
                            color: Colors.white,
                          )
                        : null,
                  ),
                  GestureDetector(
                    onTap: () => _pickAndEditAvatar(context, ref, profile),
                    child: Container(
                      padding: EdgeInsets.all(r.w(8)),
                      decoration: const BoxDecoration(
                        color: LitColors.ember,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit,
                        size: r.icon(18),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.h(20)),

            // Name and Post Label
            Text(
              profile.fullName,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: r.sp(26),
                fontWeight: FontWeight.w800,
                color: LitColors.bone,
              ),
            ),
            SizedBox(height: r.h(8)),
            
            // Badges Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Post Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: r.w(14), vertical: r.h(6)),
                  decoration: BoxDecoration(
                    color: LitColors.ember.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.radius(20)),
                    border: Border.all(color: LitColors.ember.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded, color: LitColors.ember, size: r.icon(14)),
                      SizedBox(width: r.w(6)),
                      Text(
                        profile.role.label,
                        style: GoogleFonts.dancingScript(
                          color: LitColors.amber,
                          fontSize: r.sp(15),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: r.w(8)),
                // Year Badge
                if (profile.year != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: r.w(14), vertical: r.h(6)),
                    decoration: BoxDecoration(
                      color: LitColors.moss.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(r.radius(20)),
                      border: Border.all(color: LitColors.moss.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school_rounded, color: LitColors.moss, size: r.icon(14)),
                        SizedBox(width: r.w(6)),
                        Text(
                          friendlyYear,
                          style: GoogleFonts.plusJakartaSans(
                            color: LitColors.moss,
                            fontSize: r.sp(12),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: r.h(32)),

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
                    isCursive: true,
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
            SizedBox(height: r.listBottomPadding),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, Profile profile) {
    final nameCtrl = TextEditingController(text: profile.fullName);
    final phoneCtrl = TextEditingController(text: profile.phone ?? '');
    final emailCtrl = TextEditingController(text: profile.email);
    final usnCtrl = TextEditingController(text: profile.usn ?? '');
    final branchCtrl = TextEditingController(text: profile.branch ?? '');
    final deptCtrl = TextEditingController(text: profile.department ?? '');
    
    DateTime? selectedDob = profile.dateOfBirth;
    int? selectedYear = profile.year;
    UserRole selectedRole = profile.role;
    
    final isSuperAdmin = profile.role.isSuperAdmin;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1D1A18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Edit Profile Details',
                style: GoogleFonts.fredoka(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Color(0xFFF3ECE2)),
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: TextStyle(color: Color(0xFF8C857C)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date of Birth', style: TextStyle(color: Color(0xFF8C857C), fontSize: 12)),
                      subtitle: Text(
                        selectedDob != null ? DateFormat('yyyy-MM-dd').format(selectedDob!) : 'Not set',
                        style: const TextStyle(color: Color(0xFFF3ECE2), fontSize: 15),
                      ),
                      trailing: const Icon(Icons.calendar_month, color: LitColors.ember),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDob ?? DateTime(2004, 1, 1),
                          firstDate: DateTime(1980),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: LitColors.ember,
                                  onPrimary: Colors.white,
                                  surface: Color(0xFF1D1A18),
                                  onSurface: Color(0xFFF3ECE2),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDob = picked;
                          });
                        }
                      },
                    ),
                    const Divider(color: Color(0xFF262220)),
                    if (!isSuperAdmin) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 12.0),
                        child: Text(
                          'Other details can only be modified by the Super Admin.',
                          style: TextStyle(color: Color(0xFF8C857C), fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: emailCtrl,
                        style: const TextStyle(color: Color(0xFFF3ECE2)),
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(color: Color(0xFF8C857C)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneCtrl,
                        style: const TextStyle(color: Color(0xFFF3ECE2)),
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: TextStyle(color: Color(0xFF8C857C)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: usnCtrl,
                        style: const TextStyle(color: Color(0xFFF3ECE2)),
                        decoration: const InputDecoration(
                          labelText: 'USN',
                          labelStyle: TextStyle(color: Color(0xFF8C857C)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: branchCtrl,
                        style: const TextStyle(color: Color(0xFFF3ECE2)),
                        decoration: const InputDecoration(
                          labelText: 'Branch',
                          labelStyle: TextStyle(color: Color(0xFF8C857C)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: deptCtrl,
                        style: const TextStyle(color: Color(0xFFF3ECE2)),
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          labelStyle: TextStyle(color: Color(0xFF8C857C)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedYear,
                        dropdownColor: const Color(0xFF1D1A18),
                        style: const TextStyle(color: Color(0xFFF3ECE2)),
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          labelStyle: TextStyle(color: Color(0xFF8C857C)),
                        ),
                        items: [1, 2, 3, 4].map((y) {
                          return DropdownMenuItem<int>(
                            value: y,
                            child: Text(['1st Year', '2nd Year', '3rd Year', '4th Year'][y - 1]),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedYear = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole.value,
                        dropdownColor: const Color(0xFF1D1A18),
                        style: const TextStyle(color: Color(0xFFF3ECE2)),
                        decoration: const InputDecoration(
                          labelText: 'Role/Post',
                          labelStyle: TextStyle(color: Color(0xFF8C857C)),
                        ),
                        items: UserRole.values.map((r) {
                          return DropdownMenuItem<String>(
                            value: r.value,
                            child: Text(r.label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedRole = UserRole.fromString(val);
                            });
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C857C))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final updateData = <String, dynamic>{
                      'full_name': nameCtrl.text.trim(),
                    };
                    if (selectedDob != null) {
                      updateData['date_of_birth'] = selectedDob!.toIso8601String().split('T').first;
                    }
                    if (isSuperAdmin) {
                      updateData['email'] = emailCtrl.text.trim();
                      updateData['phone'] = phoneCtrl.text.trim();
                      updateData['usn'] = usnCtrl.text.trim();
                      updateData['branch'] = branchCtrl.text.trim();
                      updateData['department'] = deptCtrl.text.trim();
                      updateData['year'] = selectedYear;
                      updateData['role'] = selectedRole.value;
                    }
                    
                    try {
                      await ref.read(authStateProvider.notifier).updateProfile(updateData);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Profile updated successfully!'),
                            backgroundColor: LitColors.moss,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update profile: $e'),
                            backgroundColor: LitColors.coral,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndEditAvatar(BuildContext context, WidgetRef ref, Profile profile) async {
    final ImagePicker picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      backgroundColor: LitColors.clay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: LitColors.bone),
              title: Text('Choose from Gallery', style: GoogleFonts.plusJakartaSans(color: LitColors.bone)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: LitColors.bone),
              title: Text('Take Photo', style: GoogleFonts.plusJakartaSans(color: LitColors.bone)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? imageFile = await picker.pickImage(source: source);
    if (imageFile == null) return;

    if (!context.mounted) return;

    final Uint8List? croppedBytes = await ProfilePictureEditor.show(context, imageFile);
    if (croppedBytes == null) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: LitColors.ember),
      ),
    );

    try {
      final String imageUrl = await ref
          .read(authStateProvider.notifier)
          .uploadProfileImage(croppedBytes, profile.id);

      await ref.read(authStateProvider.notifier).updateProfile({
        'photo_url': imageUrl,
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture updated successfully!'),
            backgroundColor: LitColors.moss,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile picture: $e'),
            backgroundColor: LitColors.coral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
    bool isCursive = false,
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
          style: isCursive
              ? GoogleFonts.dancingScript(
                  color: LitColors.amber,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                )
              : GoogleFonts.plusJakartaSans(
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


