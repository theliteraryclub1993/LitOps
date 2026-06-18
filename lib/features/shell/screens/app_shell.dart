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

    final leftItems = [
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
    ];

    final centerItem = NavBarItem(
      icon: Icons.qr_code_scanner_outlined,
      selectedIcon: Icons.qr_code_scanner,
      label: 'Register',
      route: '/registration',
      isCenter: true,
    );

    final rightItems = [
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

    final allItems = [...leftItems, centerItem, ...rightItems];

    int calculateSelectedIndex() {
      final location = GoRouterState.of(context).matchedLocation;
      for (int i = 0; i < allItems.length; i++) {
        if (location.startsWith(allItems[i].route)) {
          return i;
        }
      }
      return -1;
    }

    void onItemTapped(int index) {
      if (index >= 0 && index < allItems.length) {
        context.go(allItems[index].route);
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: ClayBottomNavBar(
        selectedIndex: calculateSelectedIndex(),
        leftItems: leftItems,
        centerItem: centerItem,
        rightItems: rightItems,
        onDestinationSelected: onItemTapped,
      ),
    );
  }
}

class ClayBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<NavBarItem> leftItems;
  final NavBarItem centerItem;
  final List<NavBarItem> rightItems;
  final ValueChanged<int> onDestinationSelected;

  const ClayBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.leftItems,
    required this.centerItem,
    required this.rightItems,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final centerIndex = leftItems.length;

    Widget buildItem(int globalIndex, NavBarItem item) {
      final isSelected = selectedIndex == globalIndex;
      return GestureDetector(
        onTap: () => onDestinationSelected(globalIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(horizontal: isSelected ? 12 : 0, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? LitColors.ember.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? LitColors.ember : LitColors.clay2,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: isSelected ? LitColors.bone : LitColors.ash,
                  size: 20,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    item.label,
                    key: ValueKey(item.label),
                    style: GoogleFonts.plusJakartaSans(
                      color: LitColors.ember,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Background blurred container
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          // 2. The items Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      leftItems.length,
                      (index) => buildItem(index, leftItems[index]),
                    ),
                  ),
                ),
                const SizedBox(width: 56), // spacer for floating button
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      rightItems.length,
                      (index) => buildItem(leftItems.length + 1 + index, rightItems[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 3. Floating action button
          Positioned(
            left: 0,
            right: 0,
            bottom: 8.0,
            child: Center(
              child: Container(
                transform: Matrix4.translationValues(0.0, -20.0, 0.0),
                child: ClayButton(
                  width: 56,
                  height: 56,
                  borderRadius: 28,
                  padding: EdgeInsets.zero,
                  onPressed: () => onDestinationSelected(centerIndex),
                  child: Icon(
                    centerItem.icon,
                    color: const Color(0xFF1A0D05),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NavBarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
  final bool isCenter;

  NavBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
    this.isCenter = false,
  });
}
