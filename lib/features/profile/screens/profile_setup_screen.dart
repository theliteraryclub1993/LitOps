import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../auth/providers/auth_provider.dart';
import '../../../core/enums/enums.dart';
import '../../../core/router/router.dart';
import '../../../core/supabase/supabase_config.dart';
import 'package:uuid/uuid.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usnController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _selectedDob;
  int _selectedYear = 1;
  UserRole _selectedRole = UserRole.juniorWing;
  int _selectedAvatarIndex = 0;
  XFile? _selectedImage;
  String? _currentPhotoUrl;
  bool _isSaving = false;
  String? _debugError;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Avatar color palettes
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

  List<UserRole> _getRolesForYear(int year) {
    if (year == 1) return [UserRole.juniorWing];
    if (year == 2) return [UserRole.assistantCoordinator];
    if (year == 3) {
      return [
        UserRole.treasurer,
        UserRole.coTreasurerSocialMedia,
        UserRole.editorialHead,
        UserRole.eventManager,
        UserRole.eventManagerCoEditorial,
        UserRole.creativeHead,
        UserRole.digitalHead,
        UserRole.databaseManager,
        UserRole.photographyHead,
      ];
    }
    if (year == 4) {
      return [
        UserRole.studentPresident,
        UserRole.studentVicePresident,
        UserRole.jointSecretary,
        UserRole.creativeDirector,
        UserRole.eventDirector,
        UserRole.designerInChief,
      ];
    }
    return [UserRole.juniorWing];
  }

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
        if (profile.usn != null) {
          _usnController.text = profile.usn!;
        }
        if (profile.phone != null) {
          _phoneController.text = profile.phone!;
        }
        if (profile.dateOfBirth != null) {
          setState(() => _selectedDob = profile.dateOfBirth);
        }
        if (profile.year != null) {
          _selectedYear = profile.year!;
        } else {
          // Determine year dynamically if possible
          bool found = false;
          for (int y = 1; y <= 4; y++) {
            if (_getRolesForYear(y).contains(profile.role)) {
              _selectedYear = y;
              found = true;
              break;
            }
          }
          if (!found) _selectedYear = 1;
        }
        
        // Set role from profile, then validate against year
        _selectedRole = profile.role;
        if (profile.role != UserRole.superAdmin) {
          final allowedRoles = _getRolesForYear(_selectedYear);
          if (!allowedRoles.contains(_selectedRole)) {
            _selectedRole = allowedRoles.first;
          }
        }
        setState(() {});
        if (profile.photoUrl != null) {
          if (profile.photoUrl!.startsWith('avatar:')) {
            final index = int.tryParse(profile.photoUrl!.split(':').last);
            if (index != null && index >= 0 && index < _avatarGradients.length) {
              setState(() => _selectedAvatarIndex = index);
            }
          } else {
            _currentPhotoUrl = profile.photoUrl;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usnController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;
    final profile = ref.read(currentProfileProvider);
    if (profile == null) return null;
    final fileExtension = _selectedImage!.name.split('.').last;
    final fileName = '${profile.id}-${const Uuid().v4()}.$fileExtension';
    try {
      final fileBytes = await _selectedImage!.readAsBytes();
      await SupabaseConfig.client.storage.from('profile_pictures').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/$fileExtension',
            ),
          );
      final String publicUrl =
          SupabaseConfig.client.storage.from('profile_pictures').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _saveProfile() async {
    debugPrint('--- _saveProfile called ---');
    final isFormValid = _formKey.currentState!.validate();
    debugPrint('Form validation status: $isFormValid');
    debugPrint('Name controller: "${_nameController.text}"');
    debugPrint('Selected DOB: $_selectedDob');
    debugPrint('Selected Year: $_selectedYear');
    debugPrint('Selected Role: $_selectedRole');

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
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (_selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your Date of Birth'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      setState(() => _debugError = null);
      final email = ref.read(currentProfileProvider)?.email;
      
      String? photoUrl;
      if (_selectedImage != null) {
        photoUrl = await _uploadImage();
      } else if (_currentPhotoUrl != null) {
        photoUrl = _currentPhotoUrl;
      } else {
        photoUrl = 'avatar:$_selectedAvatarIndex';
      }

      final updateData = {
        'full_name': _nameController.text.trim(),
        'date_of_birth': _selectedDob!.toIso8601String().split('T').first,
        'photo_url': photoUrl,
        'year': _selectedYear,
        'role': _selectedRole.value,
        if (email != null) 'email': email,
        if (_usnController.text.trim().isNotEmpty) 'usn': _usnController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty) 'phone': _phoneController.text.trim(),
      };

      debugPrint('--- SAVE PROFILE CLICKED ---');
      debugPrint('Update payload: $updateData');

      await ref.read(authStateProvider.notifier).updateProfile(updateData);

      final updatedProfile = ref.read(currentProfileProvider);
      debugPrint('Profile updated in auth state:');
      debugPrint('Updated Profile fields: id=${updatedProfile?.id}, name="${updatedProfile?.fullName}", phone="${updatedProfile?.phone}", dob="${updatedProfile?.dateOfBirth}", year=${updatedProfile?.year}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Welcome to Lit Life! 🎉',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Navigate to dashboard or return to previous screen
        if (Navigator.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _debugError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF8C857C),
        fontSize: 14,
      ),
      hintStyle: const TextStyle(color: Color(0xFF8C857C)),
      prefixIcon: Icon(icon, color: const Color(0xFF8C857C), size: 20),
      filled: true,
      fillColor: const Color(0xFF262220),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF262220)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF262220)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF6A2C), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      errorStyle: GoogleFonts.plusJakartaSans(
        color: Colors.red.shade300,
        fontSize: 12,
        height: 1.2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      // ── HEADER ──
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6A2C).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFFF6A2C).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded, color: Color(0xFFFFB14D), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Profile Setup',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFFFB14D),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Complete Your Profile',
                        style: GoogleFonts.fredoka(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFF3ECE2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Set up your identity in The Literary Club',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF8C857C),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── AVATAR PICKER ──
                      _buildSection(
                        title: 'Choose Your Avatar',
                        icon: Icons.face_retouching_natural_rounded,
                        child: Column(
                          children: [
                            // Selected avatar preview
                            Stack(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: _selectedImage == null && _currentPhotoUrl == null
                                        ? null
                                        : Colors.grey.shade900,
                                    gradient: _selectedImage == null && _currentPhotoUrl == null
                                        ? LinearGradient(
                                            colors: _avatarGradients[_selectedAvatarIndex],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _selectedImage == null && _currentPhotoUrl == null
                                            ? _avatarGradients[_selectedAvatarIndex][0].withValues(alpha: 0.4)
                                            : Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                    image: _selectedImage != null
                                        ? DecorationImage(
                                            image: FileImage(File(_selectedImage!.path)),
                                            fit: BoxFit.cover,
                                          )
                                        : _currentPhotoUrl != null
                                            ? DecorationImage(
                                                image: NetworkImage(_currentPhotoUrl!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                  ),
                                  child: _selectedImage == null && _currentPhotoUrl == null
                                      ? Icon(
                                          _avatarIcons[_selectedAvatarIndex],
                                          size: 48,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: const Color(0xFF1D1A18),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                        ),
                                        builder: (context) => SafeArea(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(
                                                  leading: const Icon(Icons.photo_library, color: Color(0xFFFF6A2C)),
                                                  title: Text('Choose from Gallery', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2))),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _pickImage(ImageSource.gallery);
                                                  },
                                                ),
                                                ListTile(
                                                  leading: const Icon(Icons.camera_alt, color: Color(0xFFFF6A2C)),
                                                  title: Text('Take a Photo', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2))),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _pickImage(ImageSource.camera);
                                                  },
                                                ),
                                                if (_selectedImage != null || _currentPhotoUrl != null)
                                                  ListTile(
                                                    leading: const Icon(Icons.refresh, color: Color(0xFFFF6A2C)),
                                                    title: Text('Use Default Avatar', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2))),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      setState(() {
                                                        _selectedImage = null;
                                                        _currentPhotoUrl = null;
                                                      });
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF6A2C),
                                        shape: BoxShape.circle,
                                        border: Border.fromBorderSide(BorderSide(color: Color(0xFF0A0A0A), width: 3)),
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Avatar grid
                            if (_selectedImage == null && _currentPhotoUrl == null)
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: List.generate(_avatarGradients.length, (i) {
                                  final isSelected = _selectedAvatarIndex == i;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedAvatarIndex = i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: _avatarGradients[i],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: isSelected ? 2.5 : 0,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: _avatarGradients[i][0].withValues(alpha: 0.5),
                                                  blurRadius: 12,
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Icon(
                                        _avatarIcons[i],
                                        size: 22,
                                        color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.7),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── PERSONAL DETAILS ──
                      _buildSection(
                        title: 'Personal Details',
                        icon: Icons.badge_outlined,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2)),
                              decoration: _inputDecoration(
                                label: 'Full Name',
                                icon: Icons.person_outline_rounded,
                                hint: 'Enter your full name',
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Enter your full name' : null,
                            ),
                            const SizedBox(height: 14),
                            // Phone Number
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2)),
                              decoration: _inputDecoration(
                                label: 'Phone Number',
                                icon: Icons.phone_outlined,
                                hint: 'Enter your phone number',
                              ),
                              validator: (v) {
                                // Optional field, but if entered, should be valid length
                                if (v != null && v.trim().isNotEmpty && v.trim().length < 10) {
                                  return 'Enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                            if (_selectedRole != UserRole.superAdmin) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _usnController,
                                style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2)),
                                decoration: _inputDecoration(
                                  label: 'USN',
                                  icon: Icons.badge_outlined,
                                  hint: 'Enter your USN',
                                ),
                                textCapitalization: TextCapitalization.characters,
                                validator: (v) {
                                  if (_selectedRole != UserRole.superAdmin && (v == null || v.trim().isEmpty)) {
                                    return 'Enter your USN';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 14),
                            // Date of Birth
                            InkWell(
                              onTap: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDob ?? DateTime(2004, 1, 1),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(now.year - 10),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.dark(
                                          primary: Color(0xFFFF6A2C),
                                          onPrimary: Colors.white,
                                          surface: Color(0xFF1D1A18),
                                          onSurface: Color(0xFFF3ECE2),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) setState(() => _selectedDob = picked);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: InputDecorator(
                                decoration: _inputDecoration(
                                  label: 'Date of Birth',
                                  icon: Icons.cake_outlined,
                                ),
                                child: Text(
                                  _selectedDob == null
                                      ? 'Select Date of Birth'
                                      : DateFormat('MMMM d, yyyy').format(_selectedDob!),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _selectedDob == null
                                        ? const Color(0xFF8C857C)
                                        : const Color(0xFFF3ECE2),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── ACADEMIC INFO ──
                      _buildSection(
                        title: 'Academic Info',
                        icon: Icons.school_outlined,
                        child: Column(
                          children: [
                            // Year selector
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF262220),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedYear,
                                decoration: _inputDecoration(
                                  label: 'Year',
                                  icon: Icons.calendar_today_outlined,
                                ),
                                dropdownColor: const Color(0xFF1D1A18),
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFF3ECE2), fontSize: 14,
                                ),
                                icon: Icon(Icons.expand_more_rounded,
                                    color: const Color(0xFF8C857C)),
                                items: [1, 2, 3, 4].map((year) {
                                  final labels = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
                                  return DropdownMenuItem(
                                    value: year,
                                    child: Text(labels[year - 1]),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null && v != _selectedYear) {
                                    setState(() {
                                      _selectedYear = v;
                                      if (_selectedRole != UserRole.superAdmin) {
                                        final allowedRoles = _getRolesForYear(_selectedYear);
                                        if (!allowedRoles.contains(_selectedRole)) {
                                          _selectedRole = allowedRoles.first;
                                        }
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                                const SizedBox(height: 14),
                                // Role/Post selector
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF262220),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      // Compute available roles for the selected year
                                      List<UserRole> availableRoles = _selectedRole == UserRole.superAdmin 
                                          ? [UserRole.superAdmin] 
                                          : _getRolesForYear(_selectedYear);
                                      
                                      // Ensure current value is in the list
                                      final effectiveRole = availableRoles.contains(_selectedRole)
                                          ? _selectedRole
                                          : availableRoles.first;
                                      if (effectiveRole != _selectedRole) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted) setState(() => _selectedRole = effectiveRole);
                                        });
                                      }
                                      return DropdownButtonFormField<UserRole>(
                                        key: ValueKey('role_$_selectedYear'),
                                        initialValue: effectiveRole,
                                        decoration: _inputDecoration(
                                          label: 'Post / Role',
                                          icon: Icons.workspace_premium_outlined,
                                    ),
                                    dropdownColor: const Color(0xFF1D1A18),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFFF3ECE2), fontSize: 14,
                                    ),
                                    icon: Icon(Icons.expand_more_rounded,
                                        color: const Color(0xFF8C857C)),
                                    isExpanded: true,
                                    items: availableRoles.map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role.label),
                                    )).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _selectedRole = v);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── SAVE & CANCEL BUTTONS ──
                      Builder(
                        builder: (context) {
                          final canPop = Navigator.of(context).canPop();
                          if (canPop) {
                            return Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: OutlinedButton(
                                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF8C857C),
                                        backgroundColor: const Color(0xFF1D1A18),
                                        side: const BorderSide(color: Color(0xFF262220), width: 1.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: _isSaving ? null : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF6A2C),
                                        foregroundColor: const Color(0xFF1A0D05),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.check_rounded, size: 20),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Save',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          return SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6A2C),
                                foregroundColor: const Color(0xFF1A0D05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_rounded, size: 22),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Save & Continue',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Sign Out link
                      TextButton.icon(
                        onPressed: () async {
                          await ref.read(authStateProvider.notifier).signOut();
                          if (mounted) context.go('/login');
                        },
                        icon: Icon(
                          Icons.logout_rounded,
                          color: const Color(0xFF8C857C),
                          size: 16,
                        ),
                        label: Text(
                          'Wrong account? Sign Out',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF8C857C),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1A18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262220)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6A2C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFFF6A2C), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.fredoka(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF3ECE2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
