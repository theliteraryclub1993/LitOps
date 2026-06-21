import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/enums/enums.dart';
import '../../../core/utils/responsive.dart';



class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  // List of EXACT routes that should show the bottom navigation bar
  static const Set<String> routesWithNavbar = {
    '/dashboard',
    '/events',
    '/leaderboard',
    '/profile',
    '/students',
    '/registration',
    '/attendance',
    '/assignments',
    '/results',
    '/rounds',
    '/certificates',
    '/feedback',
    '/appeals',
    '/analytics',
    '/settings',
    '/admin',
    '/rulebook/view',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final profile = ref.watch(currentProfileProvider);
    final isFourthYear = profile != null && (profile.year == 4 || profile.academicYear == 4);
    final isJunior = profile != null &&
        !isFourthYear &&
        profile.role != UserRole.superAdmin && (
        profile.role == UserRole.juniorWing ||
        profile.year == 1 ||
        profile.year == 2 ||
        profile.academicYear == 1 ||
        profile.academicYear == 2
    );
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final isDashboard = currentLocation == '/dashboard';
    
    // Only show navbar if current location is EXACTLY one of the top-level routes
    final bool shouldShowNavbar = routesWithNavbar.contains(currentLocation);
    
    print("=== AppShell Debug ===");
    print("currentLocation = '$currentLocation'");
    print("shouldShowNavbar = $shouldShowNavbar");
    print("routesWithNavbar = $routesWithNavbar");
    print("=== End AppShell Debug ===");
 
    final navItems = [
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
      if (role.isAdmin && (!isFourthYear || role.isSuperAdmin))
        NavBarItem(
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          label: 'Admin',
          route: '/admin',
        )
      else if (isJunior)
        NavBarItem(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'Members',
          route: '/leaderboard',
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



    int calculateSelectedIndex() {
      for (int i = 0; i < navItems.length; i++) {
        if (currentLocation.startsWith(navItems[i].route)) {
          return i;
        }
      }
      return 0; // Default to first item
    }

    void onItemTapped(int index) {
      if (index >= 0 && index < navItems.length) {
        context.go(navItems[index].route);
      }
    }

    return Scaffold(
      backgroundColor: LitColors.void_,
      body: Stack(
        children: [
          child,
          if (isDashboard && shouldShowNavbar)
            Positioned(
              right: context.r.w(24),
              bottom: context.r.h(120),
              child: GestureDetector(
                onTap: () => context.push('/registration'),
                child: Container(
                  height: context.r.w(56),
                  width: context.r.w(56),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [LitColors.ember, LitColors.emberDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: LitColors.ember.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: const Color(0xFF1A0D05),
                    size: context.r.icon(26),
                  ),
                ),
              ),
            ),
        ],
      ),
      extendBody: shouldShowNavbar,
      bottomNavigationBar: shouldShowNavbar
          ? ClayBottomNavBar(
              selectedIndex: calculateSelectedIndex(),
              items: navItems,
              onDestinationSelected: onItemTapped,
            )
          : null,
    );
  }
}

class ClayBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<NavBarItem> items;
  final ValueChanged<int> onDestinationSelected;

  const ClayBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Container(
      margin: EdgeInsets.fromLTRB(r.w(16), 0, r.w(16), r.h(24)),
      height: r.h(72),
      padding: EdgeInsets.symmetric(horizontal: r.w(8)),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(r.radius(36)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = selectedIndex == index;

          return GestureDetector(
            onTap: () => onDestinationSelected(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              padding: EdgeInsets.all(r.w(5)),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(r.radius(30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    height: r.w(44),
                    width: r.w(44),
                    decoration: BoxDecoration(
                      color: isSelected ? LitColors.ember : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected ? const Color(0xFF1A0D05) : LitColors.ash,
                      size: r.icon(22),
                    ),
                  ),
                  if (isSelected) ...[
                    SizedBox(width: r.w(8)),
                    Padding(
                      padding: EdgeInsets.only(right: r.w(12)),
                      child: Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: LitColors.bone,
                          fontSize: r.sp(14),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
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
