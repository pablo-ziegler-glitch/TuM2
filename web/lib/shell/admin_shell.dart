import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/admin_semantic_assets.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/admin_theme_mode.dart';
import '../core/theme/app_text_styles.dart';

const _worldcupLogoCropPath = 'assets/worldcup/logo/logo_worldcup_crop.png';

/// Shell de administración con sidebar fijo y área de contenido.
/// Estructura: sidebar 220px oscuro + content area blanca.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = AdminThemeScope.of(context);
    return Scaffold(
      backgroundColor:
          theme.isWorldcup ? const Color(0xFFF5F9FF) : AppColors.scaffoldBg,
      body: Row(
        children: [
          _AdminSidebar(),
          Expanded(
            child: Column(
              children: [
                _TopBar(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ──────────────────────────────────────────────────────────────────

class _AdminSidebar extends StatelessWidget {
  static const _navItems = [
    _NavItem(
      icon: Icons.grid_view_outlined,
      label: 'Panel',
      path: '/dashboard',
    ),
    _NavItem(
      icon: Icons.storefront_outlined,
      label: 'Limites de catalogo',
      path: '/businesses',
    ),
    _NavItem(
      icon: Icons.category_outlined,
      label: 'Categorias',
      path: '/categories',
    ),
    _NavItem(
      icon: Icons.fact_check_outlined,
      label: 'Revision de reclamos',
      path: '/claims',
    ),
    _NavItem(
      icon: Icons.storage_outlined,
      label: 'Importaciones',
      path: '/imports',
    ),
    _NavItem(
      icon: Icons.description_outlined,
      label: 'Plantillas',
      path: '/templates',
    ),
    _NavItem(
      icon: Icons.bar_chart_outlined,
      label: 'Analitica',
      path: '/analytics',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      label: 'Configuracion',
      path: '/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = AdminThemeScope.of(context);
    final location = GoRouterState.of(context).uri.path;

    return Container(
      width: 220,
      color: theme.isWorldcup ? const Color(0xFF0B1E46) : AppColors.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del sidebar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (theme.isWorldcup)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          _worldcupLogoCropPath,
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary500,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    const SizedBox(width: 10),
                    Text(
                      theme.isWorldcup
                          ? 'TuM2 Mundialista'
                          : 'TuM2 Administracion',
                      style: AppTextStyles.headingSm.copyWith(
                        color: AppColors.surface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'GESTION DE DATOS',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.neutral600,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Items de navegación
          ...(_navItems.map((item) {
            // Importaciones activo para todas las rutas /imports*
            final isActive = item.path == '/imports'
                ? location.startsWith('/imports') ||
                    location.startsWith('/datasets')
                : location.startsWith(item.path);
            return _SidebarNavItem(item: item, isActive: isActive);
          })),
          const Spacer(),
          // Footer del sidebar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary500,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      theme.isWorldcup ? 'WM' : 'AU',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usuario administrador',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                      Text(
                        'Responsable del sistema',
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.neutral600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.path});
  final IconData icon;
  final String label;
  final String path;
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({required this.item, required this.isActive});
  final _NavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = AdminThemeScope.of(context);
    return GestureDetector(
      onTap: () => context.go(item.path),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? (theme.isWorldcup
                      ? const Color(0xFF2B6EF3)
                      : AppColors.primary500)
                  .withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(
                  color: (theme.isWorldcup
                          ? const Color(0xFF2B6EF3)
                          : AppColors.primary500)
                      .withValues(alpha: 0.3),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 16,
              color: isActive ? AppColors.surface : AppColors.neutral500,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: AppTextStyles.labelSm.copyWith(
                  fontSize: 13,
                  color: isActive ? AppColors.surface : AppColors.neutral500,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = AdminThemeScope.of(context);
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      height: 52,
      color: theme.isWorldcup ? const Color(0xFFEFF4FF) : AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Campo de búsqueda
          Expanded(
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, size: 14, color: AppColors.neutral500),
                  const SizedBox(width: 8),
                  Text(
                    'Buscar importaciones, registros o entidades...',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.neutral400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          _ThemeToggleButton(controller: theme),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            color: AppColors.neutral600,
            iconSize: 18,
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.logout),
            color: AppColors.neutral600,
            iconSize: 18,
            onPressed: () => FirebaseAuth.instance.signOut(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 8),
          Text(
            user?.email ?? 'admin',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.help_outline),
            color: AppColors.neutral600,
            iconSize: 18,
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 8),
          Text(
            theme.isWorldcup ? 'TuM2 Portal Mundialista' : 'TuM2 Portal',
            style: AppTextStyles.bodyXs.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(width: 8),
          if (theme.isWorldcup)
            ClipOval(
              child: Image.asset(
                _worldcupLogoCropPath,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.secondary500,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'AU',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.controller});

  final AdminThemeController controller;

  @override
  Widget build(BuildContext context) {
    final isWorldcup = controller.isWorldcup;
    return TextButton.icon(
      onPressed: controller.toggle,
      style: TextButton.styleFrom(
        backgroundColor:
            isWorldcup ? const Color(0xFF1D4ED8) : AppColors.neutral100,
        foregroundColor: isWorldcup ? Colors.white : AppColors.neutral700,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 0),
      ),
      icon: AdminSemanticIcon(
        iconKey: AdminIconKey.brand,
        size: 16,
        color: isWorldcup ? Colors.white : AppColors.neutral700,
        fallbackOverride:
            isWorldcup ? Icons.flag_circle : Icons.palette_outlined,
      ),
      label: Text(
        isWorldcup ? 'Mundialista' : 'Clásico',
        style: AppTextStyles.bodyXs.copyWith(
          color: isWorldcup ? Colors.white : AppColors.neutral700,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
