import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Main scaffold with bottom navigation for TuM2 core navigation.
/// Uses standard navigation labels per REGLA CRÍTICA DE UX.
class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(location),
        onDestinationSelected: (index) => _onDestinationSelected(context, index),
        backgroundColor: TuM2Colors.background,
        indicatorColor: TuM2Colors.primaryLight.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_pharmacy_outlined),
            selectedIcon: Icon(Icons.local_pharmacy),
            label: 'Farmacias',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outlined),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Ideas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/mapa')) return 1;
    if (location.startsWith('/farmacias')) return 2;
    if (location.startsWith('/roadmap')) return 3;
    if (location.startsWith('/perfil')) return 4;
    return 0; // '/' — Buscar (Discover)
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/mapa');
      case 2:
        context.go('/farmacias');
      case 3:
        context.go('/roadmap');
      case 4:
        context.go('/perfil');
    }
  }
}
