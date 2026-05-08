import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({
    required this.child,
    required this.location,
    super.key,
  });

  final Widget child;
  final String location;

  static const _tabs = [
    _NavTab(
      route: AppRoutes.home,
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Discover',
    ),
    _NavTab(
      route: AppRoutes.search,
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: 'Search',
    ),
    _NavTab(
      route: AppRoutes.myList,
      icon: Icons.bookmark_border_outlined,
      activeIcon: Icons.bookmark,
      label: 'My List',
    ),
    _NavTab(
      route: AppRoutes.settings,
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  int get _currentIndex {
    final idx = _tabs.indexWhere((t) => location.startsWith(t.route));
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].route),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.activeIcon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
