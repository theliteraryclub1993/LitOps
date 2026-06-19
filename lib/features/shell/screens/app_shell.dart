import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import 'dart:ui';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final isSuperAdmin = role.isSuperAdmin;

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
      if (isSuperAdmin)
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

    int calculateSelectedIndex() {
      final location = GoRouterState.of(context).matchedLocation;
      for (int i = 0; i < navItems.length; i++) {
        if (location.startsWith(navItems[i].route)) {
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 100), // Height of bar + margin
            child: child,
          ),
          Positioned(
            right: 24,
            bottom: 130,
            child: GestureDetector(
              onTap: () => context.push('/registration'),
              child: Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [LitColors.ember, LitColors.emberDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: LitColors.ember.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF1A0D05),
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: ClayBottomNavBar(
        selectedIndex: calculateSelectedIndex(),
        items: navItems,
        onDestinationSelected: onItemTapped,
      ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(35),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? LitColors.ember : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected ? const Color(0xFF1A0D05) : LitColors.ash,
                      size: 24,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: LitColors.bone,
                          fontSize: 15,
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
