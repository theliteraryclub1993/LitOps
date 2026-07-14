import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/enums/enums.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/config/role_config.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  // List of EXACT routes that should show the bottom navigation bar
  static const Set<String> routesWithNavbar = Responsive.routesWithNavbar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleConfig = ref.watch(roleConfigProvider);
    final currentLocation = GoRouterState.of(context).matchedLocation;
    
    // Only show navbar if current location is EXACTLY one of the top-level routes
    final bool shouldShowNavbar = routesWithNavbar.contains(currentLocation);
    
    print("=== AppShell Debug ===");
    print("currentLocation = '$currentLocation'");
    print("shouldShowNavbar = $shouldShowNavbar");
    print("routesWithNavbar = $routesWithNavbar");
    print("=== End AppShell Debug ===");
 
    final navItems = roleConfig.getNavItems();



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

    final isScheduling = currentLocation == '/scheduling';
    
    return Scaffold(
      backgroundColor: LitColors.void_,
      body: child,
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
