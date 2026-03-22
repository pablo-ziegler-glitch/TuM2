import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Shell del tab bar principal de la app.
///
/// Envuelve el [StatefulNavigationShell] de go_router para proveer
/// la barra de navegación inferior (Material 3 NavigationBar) con 3 tabs:
/// Inicio, Buscar y Perfil.
///
/// El tab bar se oculta automáticamente cuando la ruta activa es una
/// pantalla de detalle (/commerce/*) o un modal (/owner, /admin),
/// ya que esas rutas viven fuera del [StatefulShellRoute] y se presentan
/// sobre el shell completo.
class CustomerTabs extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const CustomerTabs({super.key, required this.navigationShell});

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
    // Al tocar el tab activo → reset del stack al root (comportamiento nativo iOS)
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
