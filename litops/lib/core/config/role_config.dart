import 'package:flutter/material.dart';
import '../enums/enums.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

enum InterfaceGroup {
  groupA,     // Junior Wing, Assistant Coordinator (Year 1 & 2)
  groupB,     // 3rd & 4th Year Coordinator (Year 3 & 4)
  coreAdmin,  // Admin & Core Committee
}

class RoleConfig {
  final Profile? profile;
  
  const RoleConfig(this.profile);

  UserRole get role => profile?.role ?? UserRole.juniorWing;
  int get year => profile?.year ?? profile?.academicYear ?? 1;

  InterfaceGroup get interfaceGroup {
    if (profile == null) return InterfaceGroup.groupA;
    if (role.isSuperAdmin) return InterfaceGroup.coreAdmin;
    
    // Core committee members (President, VP, JS, Creative Dir, Event Dir, Designer in Chief)
    // always use coreAdmin interface group.
    if (role == UserRole.studentPresident ||
        role == UserRole.studentVicePresident ||
        role == UserRole.jointSecretary ||
        role == UserRole.creativeDirector ||
        role == UserRole.eventDirector ||
        role == UserRole.designerInChief) {
      return InterfaceGroup.coreAdmin;
    }

    // Group A (Junior Wing and Assistant Coordinator)
    if (role == UserRole.juniorWing ||
        role == UserRole.assistantCoordinator ||
        year == 1 ||
        year == 2) {
      return InterfaceGroup.groupA;
    }

    // Group B (3rd and 4th Year Coordinators)
    return InterfaceGroup.groupB;
  }

  bool get isJunior => interfaceGroup == InterfaceGroup.groupA;
  bool get isSeniorCoordinator => interfaceGroup == InterfaceGroup.groupB;
  bool get isCoreAdmin => interfaceGroup == InterfaceGroup.coreAdmin;

  // Navigation Items for Bottom Navigation Bar
  List<NavBarItem> getNavItems() {
    switch (interfaceGroup) {
      case InterfaceGroup.groupA:
        return [
          NavBarItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Home',
            route: '/dashboard',
          ),
          NavBarItem(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view,
            label: 'Events',
            route: '/events',
          ),
          NavBarItem(
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: 'Members',
            route: '/leaderboard',
          ),
          NavBarItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Profile',
            route: '/profile',
          ),
        ];
      case InterfaceGroup.groupB:
        return [
          NavBarItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Home',
            route: '/dashboard',
          ),
          NavBarItem(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view,
            label: 'Events',
            route: '/events',
          ),
          NavBarItem(
            icon: Icons.emoji_events_outlined,
            selectedIcon: Icons.emoji_events,
            label: 'Rank',
            route: '/leaderboard',
          ),
          NavBarItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Profile',
            route: '/profile',
          ),
        ];
      case InterfaceGroup.coreAdmin:
        final bool isFourthYear = year == 4;
        final bool showAdmin = role.isAdmin && (!isFourthYear || role.isSuperAdmin);
        return [
          NavBarItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Home',
            route: '/dashboard',
          ),
          NavBarItem(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view,
            label: 'Events',
            route: '/events',
          ),
          if (showAdmin)
            NavBarItem(
              icon: Icons.admin_panel_settings_outlined,
              selectedIcon: Icons.admin_panel_settings,
              label: 'Admin',
              route: '/admin',
            )
          else
            NavBarItem(
              icon: Icons.emoji_events_outlined,
              selectedIcon: Icons.emoji_events,
              label: 'Rank',
              route: '/leaderboard',
            ),
          NavBarItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Profile',
            route: '/profile',
          ),
        ];
    }
  }

  // Dashboard card controls
  bool get showAdminConsole => role.isSuperAdmin;
  bool get showRulebookCard => isJunior;
  bool get showLiveRankings => !isJunior;
  bool get showMyAssignedEvents => isJunior;

  // Quick Services list
  List<Map<String, dynamic>> getQuickServices() {
    final showAssignments = role.canAssignMembers || year == 4;
    return [
      {'icon': Icons.qr_code_scanner_rounded, 'label': 'Scan QR', 'route': '/registration', 'color': LitColors.ember},
      {'icon': Icons.calendar_today_rounded, 'label': 'Events', 'route': '/events', 'color': LitColors.amber},
      if (showAssignments)
        {'icon': Icons.assignment_ind_rounded, 'label': 'Assign Crew', 'route': '/assignments', 'color': LitColors.amber},
      {'icon': Icons.group_rounded, 'label': 'Students', 'route': '/students', 'color': LitColors.ash},
      if (!isJunior) ...[
        {'icon': Icons.emoji_events_rounded, 'label': 'Results', 'route': '/results', 'color': LitColors.ember},
        {'icon': Icons.analytics_rounded, 'label': 'Analytics', 'route': '/analytics', 'color': LitColors.amber},
      ],
    ];
  }

  // Centralized permissions matching UserRole & profile context
  bool get isSuperAdmin => role.isSuperAdmin;
  bool get isAdmin => role.isAdmin;
  bool get isCoreCommittee => role.isCoreCommittee;
  bool get canRegisterParticipants => role.canRegisterParticipants;
  bool get canEditRegistrations => role.canEditRegistrations;
  bool get canDeleteRegistrations => role.canDeleteRegistrations;
  bool get canManualEntry => role.canManualEntry;
  bool get canManageEvents => role.canManageEvents || year == 4;
  bool get canCreateEvents => role.canCreateEvents;
  bool get canManageDatabase => role.canManageDatabase;
  bool get canResetDatabase => role.canResetDatabase;
  bool get canViewAppeals => role.canViewAppeals;
  bool get canManageResults => role.canManageResults;
  bool get canGenerateCertificates => role.canGenerateCertificates;
  bool get canMarkAttendance => role.canMarkAttendance;
  bool get canEditPoints => role.canEditPoints;
  bool get canManageMembers => role.canManageMembers;
  bool get canManageYearlyData => role.canManageYearlyData;
  bool get canViewAuditLogs => role.canViewAuditLogs;
  bool get canImportData => role.canImportData;

  bool get canAssignMembers => role.canAssignMembers || year == 4;

  bool get canManageEventSchedule => role.isSuperAdmin || 
                                     role == UserRole.eventDirector ||
                                     role == UserRole.eventManager ||
                                     role == UserRole.eventManagerCoEditorial ||
                                     year == 4;
}

class NavBarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  NavBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}
