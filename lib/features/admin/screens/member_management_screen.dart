import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/enums/enums.dart';
import '../../../core/models/models.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/top_notification.dart';
import '../providers/admin_providers.dart';
import '../../auth/providers/auth_provider.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Member Governance'),
        foregroundColor: const Color(0xFFF3ECE2),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF262220),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            UserAvatar(
              name: member.memberName ?? '?',
              radius: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.memberName ?? 'Unknown User',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF3ECE2),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.memberEmail ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C857C),
                      fontSize: 12,
                    ),
                  ),
                  if (member.memberPhone != null && member.memberPhone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF8C857C)),
                        const SizedBox(width: 4),
                        Text(
                          member.memberPhone!,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF8C857C),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          member.role.label,
                          style: GoogleFonts.plusJakartaSans(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          member.status.label,
                          style: GoogleFonts.plusJakartaSans(
                            color: statusColor,
                            fontSize: 11,
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
              icon: const Icon(Icons.more_vert, color: Color(0xFF8C857C)),
              color: const Color(0xFF1D1A18),
              onSelected: (action) => _handleMenuAction(action, member),
              itemBuilder: (context) {
                final currentUserRole = ref.read(currentUserRoleProvider);
                final isSuperAdmin = currentUserRole.isSuperAdmin;
                return [
                  if (isSuperAdmin)
                    const PopupMenuItem(
                      value: 'edit_details',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: Color(0xFF6FAE8F), size: 20),
                          SizedBox(width: 8),
                          Text('Edit Details', style: TextStyle(color: Color(0xFFF3ECE2))),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'change_role',
                    child: Row(
                      children: [
                        Icon(Icons.manage_accounts_rounded, color: Color(0xFFFFB14D), size: 20),
                        SizedBox(width: 8),
                        Text('Change Role', style: TextStyle(color: Color(0xFFF3ECE2))),
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
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSuspended ? 'Reactivate' : 'Suspend Member',
                          style: const TextStyle(color: Color(0xFFF3ECE2)),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove_rounded, color: Color(0xFFFF5C5C), size: 20),
                        SizedBox(width: 8),
                        Text('Remove Member', style: TextStyle(color: Color(0xFFF3ECE2))),
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

  void _showEditMemberDetailsDialog(ClubMember member) {
    final nameCtrl = TextEditingController(text: member.memberName ?? '');
    final emailCtrl = TextEditingController(text: member.memberEmail ?? '');
    final phoneCtrl = TextEditingController(text: member.memberPhone ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1A18),
          title: Text(
            'Edit Member Details',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF3ECE2), fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Color(0xFFF3ECE2)),
                decoration: const InputDecoration(
                  hintText: 'Full Name',
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Color(0xFF8C857C)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                style: const TextStyle(color: Color(0xFFF3ECE2)),
                decoration: const InputDecoration(
                  hintText: 'email@example.com',
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Color(0xFF8C857C)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                style: const TextStyle(color: Color(0xFFF3ECE2)),
                decoration: const InputDecoration(
                  hintText: '+1234567890',
                  labelText: 'Phone',
                  labelStyle: TextStyle(color: Color(0xFF8C857C)),
                ),
                keyboardType: TextInputType.phone,
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
                Navigator.pop(context);
                try {
                  await ref.read(adminControllerProvider).updateMemberDetails(
                    userId: member.userId,
                    memberName: nameCtrl.text.trim(),
                    memberEmail: emailCtrl.text.trim(),
                    memberPhone: phoneCtrl.text.trim(),
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
      message: 'Are you sure you want to remove ${member.memberName} from Lit Life? '
          'Their profile access level will revert to Junior Wing.',
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
