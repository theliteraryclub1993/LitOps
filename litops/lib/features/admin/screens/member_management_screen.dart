import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/enums/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/top_notification.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_tables.dart';
import '../../profile/widgets/profile_picture_editor.dart';
import '../providers/admin_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

class MemberManagementScreen extends ConsumerStatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  ConsumerState<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends ConsumerState<MemberManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(memberListProvider);
    final r = context.r;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Member Governance',
          style: GoogleFonts.fredoka(
            fontSize: r.sp(16),
            fontWeight: FontWeight.w600,
          ),
        ),
        foregroundColor: const Color(0xFFF3ECE2),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(r.w(16.0)),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Color(0xFFF3ECE2)),
              decoration: const InputDecoration(
                hintText: 'Search by name, email or USN...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),

          // Members list
          Expanded(
            child: membersAsync.when(
              data: (members) {
                final filtered = members.where((m) {
                  final name = m.memberName?.toLowerCase() ?? '';
                  final email = m.memberEmail?.toLowerCase() ?? '';
                  final role = m.role.label.toLowerCase();
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      role.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyView(
                    icon: Icons.people_outline,
                    title: 'No members found',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'Try searching with different terms.'
                        : 'No users have registered yet.',
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: r.pagePadding),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final member = filtered[index];
                    return _buildMemberCard(member);
                  },
                );
              },
              loading: () => const LoadingView(message: 'Retrieving club members...'),
              error: (e, _) => ErrorView(
                message: 'Failed to load members: $e',
                onRetry: () => ref.invalidate(memberListProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(ClubMember member) {
    final isSuspended = member.status == MemberStatus.suspended;
    final r = context.r;
    
    Color statusColor;
    switch (member.status) {
      case MemberStatus.active:
        statusColor = const Color(0xFF10B981);
        break;
      case MemberStatus.suspended:
        statusColor = const Color(0xFFEF4444);
        break;
      case MemberStatus.inactive:
        statusColor = Colors.grey;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: r.h(12)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(r.radius(24)),
        border: Border.all(
          color: const Color(0xFF262220),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(r.w(16.0)),
        child: Row(
          children: [
            UserAvatar(
              name: member.memberName ?? '?',
              radius: r.radius(24),
            ),
            SizedBox(width: r.w(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.memberName ?? 'Unknown User',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF3ECE2),
                      fontSize: r.sp(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: r.h(4)),
                  Text(
                    member.memberEmail ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C857C),
                      fontSize: r.sp(12),
                    ),
                  ),
                  if (member.memberPhone != null && member.memberPhone!.isNotEmpty) ...[
                    SizedBox(height: r.h(4)),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: r.icon(12), color: const Color(0xFF8C857C)),
                        SizedBox(width: r.w(4)),
                        Text(
                          member.memberPhone!,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF8C857C),
                            fontSize: r.sp(12),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: r.h(8)),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(4)),
                        decoration: BoxDecoration(
                          color: LitColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.radius(8)),
                        ),
                        child: Text(
                          member.role.label,
                          style: GoogleFonts.dancingScript(
                            color: LitColors.amber,
                            fontSize: r.sp(14),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: r.w(8)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(4)),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.radius(8)),
                        ),
                        child: Text(
                          member.status.label,
                          style: GoogleFonts.plusJakartaSans(
                            color: statusColor,
                            fontSize: r.sp(11),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: const Color(0xFF8C857C), size: r.icon(20)),
              color: const Color(0xFF1D1A18),
              onSelected: (action) => _handleMenuAction(action, member),
              itemBuilder: (context) {
                final currentUserRole = ref.read(currentUserRoleProvider);
                final isSuperAdmin = currentUserRole.isSuperAdmin;
                return [
                  if (isSuperAdmin)
                    PopupMenuItem(
                      value: 'edit_details',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: const Color(0xFF6FAE8F), size: r.icon(20)),
                          SizedBox(width: r.w(8)),
                          const Text('Edit Details', style: TextStyle(color: Color(0xFFF3ECE2))),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'change_role',
                    child: Row(
                      children: [
                        Icon(Icons.manage_accounts_rounded, color: const Color(0xFFFFB14D), size: r.icon(20)),
                        SizedBox(width: r.w(8)),
                        const Text('Change Role', style: TextStyle(color: Color(0xFFF3ECE2))),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: isSuspended ? 'activate' : 'suspend',
                    child: Row(
                      children: [
                        Icon(
                          isSuspended ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          color: isSuspended ? const Color(0xFF6FAE8F) : const Color(0xFFFFB14D),
                          size: r.icon(20),
                        ),
                        SizedBox(width: r.w(8)),
                        Text(
                          isSuspended ? 'Reactivate' : 'Suspend Member',
                          style: const TextStyle(color: Color(0xFFF3ECE2)),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove_rounded, color: const Color(0xFFFF5C5C), size: r.icon(20)),
                        SizedBox(width: r.w(8)),
                        const Text('Remove Member', style: TextStyle(color: Color(0xFFF3ECE2))),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action, ClubMember member) {
    switch (action) {
      case 'edit_details':
        _showEditMemberDetailsDialog(member);
        break;
      case 'change_role':
        _showChangeRoleDialog(member);
        break;
      case 'suspend':
        _showSuspendDialog(member);
        break;
      case 'activate':
        _confirmReactivate(member);
        break;
      case 'remove':
        _confirmRemove(member);
    }
  }

  Future<String?> _pickAndEditPhotoForUser(BuildContext context, String targetUserId) async {
    final ImagePicker picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1D1A18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFF3ECE2)),
              title: const Text('Choose from Gallery', style: TextStyle(color: Color(0xFFF3ECE2))),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFF3ECE2)),
              title: const Text('Take Photo', style: TextStyle(color: Color(0xFFF3ECE2))),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    final XFile? imageFile = await picker.pickImage(source: source);
    if (imageFile == null) return null;

    if (!context.mounted) return null;

    final Uint8List? croppedBytes = await ProfilePictureEditor.show(context, imageFile);
    if (croppedBytes == null) return null;

    if (!context.mounted) return null;

    // Show loading spinner
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
          .uploadProfileImage(croppedBytes, targetUserId);
      if (context.mounted) Navigator.pop(context); // close loader
      return imageUrl;
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
      return null;
    }
  }

  void _showEditMemberDetailsDialog(ClubMember member) {
    showDialog(
      context: context,
      builder: (context) {
        Profile? loadedProfile;
        bool isLoading = true;
        String? fetchError;

        TextEditingController? nameCtrl;
        TextEditingController? emailCtrl;
        TextEditingController? phoneCtrl;
        TextEditingController? usnCtrl;
        TextEditingController? branchCtrl;
        TextEditingController? deptCtrl;
        TextEditingController? permCtrl;
        
        DateTime? selectedDob;
        int? selectedYear;
        UserRole? selectedRole;
        bool? selectedIsActive;
        String? newPhotoUrl;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (isLoading && fetchError == null) {
              Future.microtask(() async {
                try {
                  final data = await SupabaseConfig.client
                      .from(SupabaseTables.profiles)
                      .select()
                      .eq('id', member.userId)
                      .single();
                  setDialogState(() {
                    loadedProfile = Profile.fromJson(data);
                    isLoading = false;
                  });
                } catch (e) {
                  setDialogState(() {
                    fetchError = e.toString();
                    isLoading = false;
                  });
                }
              });
            }

            if (isLoading) {
              return const AlertDialog(
                backgroundColor: Color(0xFF1D1A18),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: LitColors.ember),
                    SizedBox(height: 16),
                    Text('Fetching profile details...', style: TextStyle(color: Color(0xFFF3ECE2))),
                  ],
                ),
              );
            }

            if (fetchError != null) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1D1A18),
                title: const Text('Error', style: TextStyle(color: Color(0xFFFF5C5C))),
                content: Text(fetchError!, style: const TextStyle(color: Color(0xFFF3ECE2))),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(color: Color(0xFF8C857C))),
                  ),
                ],
              );
            }

            if (loadedProfile != null && nameCtrl == null) {
              final p = loadedProfile!;
              nameCtrl = TextEditingController(text: p.fullName);
              emailCtrl = TextEditingController(text: p.email);
              phoneCtrl = TextEditingController(text: p.phone ?? '');
              usnCtrl = TextEditingController(text: p.usn ?? '');
              branchCtrl = TextEditingController(text: p.branch ?? '');
              deptCtrl = TextEditingController(text: p.department ?? '');
              permCtrl = TextEditingController(text: p.customPermissions.join(', '));
              selectedDob = p.dateOfBirth;
              selectedYear = p.year;
              selectedRole = p.role;
              selectedIsActive = p.isActive;
              newPhotoUrl = p.photoUrl;
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1D1A18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Edit Member Details',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar Picker Section
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              shape: BoxShape.circle,
                              border: Border.all(color: LitColors.border, width: 2),
                              image: (newPhotoUrl != null && !newPhotoUrl!.startsWith('avatar:'))
                                  ? DecorationImage(
                                      image: NetworkImage(newPhotoUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (newPhotoUrl == null || newPhotoUrl!.startsWith('avatar:'))
                                ? const Icon(Icons.person, size: 40, color: Colors.white)
                                : null,
                          ),
                          GestureDetector(
                            onTap: () async {
                              final url = await _pickAndEditPhotoForUser(context, member.userId);
                              if (url != null) {
                                setDialogState(() {
                                  newPhotoUrl = url;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: LitColors.ember,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Color(0xFFF3ECE2)),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Color(0xFF8C857C)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      style: const TextStyle(color: Color(0xFFF3ECE2)),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Color(0xFF8C857C)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      style: const TextStyle(color: Color(0xFFF3ECE2)),
                      decoration: const InputDecoration(
                        labelText: 'Phone',
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
                    TextField(
                      controller: permCtrl,
                      style: const TextStyle(color: Color(0xFFF3ECE2)),
                      decoration: const InputDecoration(
                        labelText: 'Permissions (comma separated)',
                        labelStyle: TextStyle(color: Color(0xFF8C857C)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // DOB Picker
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
                          setDialogState(() {
                            selectedDob = picked;
                          });
                        }
                      },
                    ),
                    const Divider(color: Color(0xFF262220)),

                    // Year Dropdown
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
                        setDialogState(() {
                          selectedYear = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Role Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole?.value,
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
                          setDialogState(() {
                            selectedRole = UserRole.fromString(val);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Account Status Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Account Status', style: TextStyle(color: Color(0xFFF3ECE2), fontSize: 14)),
                      subtitle: Text(
                        selectedIsActive == true ? 'Enabled' : 'Disabled',
                        style: TextStyle(color: selectedIsActive == true ? Colors.green : Colors.red, fontSize: 12),
                      ),
                      value: selectedIsActive ?? true,
                      activeThumbColor: LitColors.ember,
                      onChanged: (val) {
                        setDialogState(() {
                          selectedIsActive = val;
                        });
                      },
                    ),
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
                    try {
                      final perms = permCtrl!.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();

                      await ref.read(adminControllerProvider).updateMemberDetails(
                            userId: member.userId,
                            memberName: nameCtrl!.text.trim(),
                            memberEmail: emailCtrl!.text.trim(),
                            memberPhone: phoneCtrl!.text.trim(),
                            dob: selectedDob,
                            usn: usnCtrl!.text.trim(),
                            branch: branchCtrl!.text.trim(),
                            department: deptCtrl!.text.trim(),
                            year: selectedYear,
                            role: selectedRole,
                            isActive: selectedIsActive,
                            customPermissions: perms,
                            photoUrl: newPhotoUrl,
                          );
                      showTopNotification(context, 'Member details updated successfully', type: NotificationType.success);
                    } catch (e) {
                      showTopNotification(context, 'Failed to update details: $e', type: NotificationType.error);
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

  void _showChangeRoleDialog(ClubMember member) {
    UserRole selectedRole = member.role;
    final currentUserRole = ref.read(currentUserRoleProvider);
    final isSuperAdmin = currentUserRole.isSuperAdmin;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1A18),
          title: Text(
            'Change Member Role',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update role for ${member.memberName ?? "user"}',
                    style: const TextStyle(color: Color(0xFF8C857C), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRole.value,
                        dropdownColor: const Color(0xFF1D1A18),
                        isExpanded: true,
                        style: const TextStyle(color: Color(0xFFF3ECE2)),
                        onChanged: (String? newVal) {
                          if (newVal != null) {
                            setDialogState(() {
                              selectedRole = UserRole.fromString(newVal);
                            });
                          }
                        },
                        items: () {
                          if (isSuperAdmin) {
                            // Super admin can choose ANY role
                            return UserRole.values.map((r) => DropdownMenuItem<String>(
                              key: ValueKey(r.value),
                              value: r.value,
                              child: Text(r.label, style: const TextStyle(color: Color(0xFFF3ECE2))),
                            )).toList();
                          } else {
                            // Regular admin logic
                            final memberYear = member.memberYear;
                            List<UserRole> availableRoles;
                            if (memberYear == 1) {
                              availableRoles = [UserRole.juniorWing];
                            } else if (memberYear == 2) {
                              availableRoles = [UserRole.assistantCoordinator];
                            } else {
                              availableRoles = UserRole.values.where((r) =>
                                r != UserRole.superAdmin &&
                                r != UserRole.juniorWing &&
                                r != UserRole.assistantCoordinator).toList();
                            }
                            return availableRoles.map((r) => DropdownMenuItem<String>(
                              key: ValueKey(r.value),
                              value: r.value,
                              child: Text(r.label, style: const TextStyle(color: Color(0xFFF3ECE2))),
                            )).toList();
                          }
                        }(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C857C))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await ref.read(adminControllerProvider).updateMemberRole(
                        member.id,
                        member.userId,
                        selectedRole,
                      );
                  showTopNotification(context, 'Member role updated successfully', type: NotificationType.success);
                } catch (e) {
                  showTopNotification(context, 'Failed to update role: $e', type: NotificationType.error);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showSuspendDialog(ClubMember member) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1A18),
          title: Text(
            'Suspend Member',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Provide suspension details for ${member.memberName}',
                style: const TextStyle(color: Color(0xFF8C857C), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Color(0xFFF3ECE2)),
                decoration: const InputDecoration(
                  hintText: 'Enter reason for suspension...',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C857C))),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) return;
                Navigator.pop(context);
                try {
                  await ref.read(adminControllerProvider).updateMemberStatus(
                        member.id,
                        member.userId,
                        MemberStatus.suspended,
                        reason: reason,
                      );
                  showTopNotification(context, 'Member suspended successfully', type: NotificationType.warning);
                } catch (e) {
                  showTopNotification(context, 'Failed to suspend member: $e', type: NotificationType.error);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C5C),
                foregroundColor: const Color(0xFF1A0D05),
              ),
              child: const Text('Suspend'),
            ),
          ],
        );
      },
    );
  }

  void _confirmReactivate(ClubMember member) {
    ConfirmDialog.show(
      context,
      title: 'Reactivate Member',
      message: 'Are you sure you want to reactivate ${member.memberName}?',
      confirmText: 'Reactivate',
      confirmColor: Colors.green,
      onConfirm: () async {
        try {
          await ref.read(adminControllerProvider).updateMemberStatus(
                member.id,
                member.userId,
                MemberStatus.active,
              );
          showTopNotification(context, 'Member reactivated successfully', type: NotificationType.success);
        } catch (e) {
          showTopNotification(context, 'Failed to reactivate: $e', type: NotificationType.error);
        }
      },
    );
  }

  void _confirmRemove(ClubMember member) {
    ConfirmDialog.show(
      context,
      title: 'Remove Member',
      message: 'Are you sure you want to permanently remove ${member.memberName}? '
          'This will delete their account and all associated data, preventing them from logging in.',
      confirmText: 'Remove',
      confirmColor: Colors.redAccent,
      onConfirm: () async {
        try {
          await ref.read(adminControllerProvider).removeMember(member.id, member.userId);
          showTopNotification(context, 'Member removed successfully', type: NotificationType.success);
        } catch (e) {
          showTopNotification(context, 'Failed to remove member: $e', type: NotificationType.error);
        }
      },
    );
  }
}
