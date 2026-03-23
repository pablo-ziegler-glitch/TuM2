import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Shell de administración con sidebar fijo y área de contenido.
/// Estructura: sidebar 220px oscuro + content area blanca.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
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
    _NavItem(icon: Icons.dataset_outlined, label: 'Datasets', path: '/datasets'),
    _NavItem(icon: Icons.storefront_outlined, label: 'Commerces', path: '/commerces'),
    _NavItem(icon: Icons.settings_outlined, label: 'Settings', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Container(
      width: 220,
      color: AppColors.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del sidebar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary500,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'TuM2 Admin',
                      style: AppTextStyles.headingSm.copyWith(color: AppColors.surface),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Local Directory CMS',
                  style: AppTextStyles.bodyXs.copyWith(color: AppColors.sidebarText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Items de navegación
          ...(_navItems.map((item) {
            final isActive = location.startsWith(item.path);
            return _SidebarNavItem(item: item, isActive: isActive);
          })),
          const Spacer(),
          // Footer del sidebar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.neutral700,
                  child: const Icon(Icons.person, color: AppColors.neutral400, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin User',
                        style: AppTextStyles.labelSm.copyWith(color: AppColors.surface),
                      ),
                      Text(
                        'admin@tum2.app',
                        style: AppTextStyles.bodyXs.copyWith(color: AppColors.sidebarText),
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
    return GestureDetector(
      onTap: () => context.go(item.path),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary500.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 18,
              color: isActive ? AppColors.surface : AppColors.sidebarText,
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: AppTextStyles.labelMd.copyWith(
                color: isActive ? AppColors.surface : AppColors.sidebarText,
              ),
            ),
            if (isActive) ...[
              const Spacer(),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
              ),
            ],
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
    return Container(
      height: 56,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Campo de búsqueda
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: AppColors.neutral500),
                  const SizedBox(width: 8),
                  Text(
                    'Search datasets or logs...',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.neutral500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Acciones del top bar
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            color: AppColors.neutral700,
            iconSize: 20,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            color: AppColors.neutral700,
            iconSize: 20,
            onPressed: () {},
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary100,
            child: const Icon(Icons.person, color: AppColors.primary500, size: 18),
          ),
        ],
      ),
    );
  }
}
