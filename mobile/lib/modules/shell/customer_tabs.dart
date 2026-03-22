import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Shell del tab bar principal — 3 tabs: Inicio, Buscar, Perfil.
///
/// Envuelve el [StatefulNavigationShell] de go_router para proveer
/// la barra de navegación inferior (Material 3 NavigationBar).
/// El tab bar se oculta automáticamente en rutas fuera del shell
/// (detalle de comercio, panel owner, etc.).
class CustomerTabs extends StatelessWidget {
  const CustomerTabs({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary100,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTabSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
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

  void _onTabSelected(int index) {
    // Si se toca el tab activo → reset al root del stack (comportamiento nativo)
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
