import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// PROFILE-01 — Tab Perfil.
/// Muestra datos del usuario y accesos a favoritos, historial y configuración.
/// Variante owner (con tarjeta "Mi Comercio") disponible cuando el usuario
/// tiene el claim role='owner' en Firebase Auth (TuM2-0054).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isOwner = ref.watch(isOwnerProvider).valueOrNull ?? false;
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 20),
            const Text('Mi Perfil', style: AppTextStyles.headingLg),
            const SizedBox(height: 4),
            const Text(
              'Gestiona tu experiencia en el barrio.',
              style: AppTextStyles.bodySm,
            ),
            const SizedBox(height: 20),
            // tarjeta de usuario
            _UserCard(
              name: user?.displayName ?? 'Alex Rivera',
              email: user?.email ?? 'alex.rivera@ejemplo.com',
            ),
            // sección PANEL ADMIN — solo si el usuario tiene rol admin
            if (isAdmin) ...[
              const SizedBox(height: 20),
              Text(
                'ADMINISTRACIÓN',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.neutral500,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => context.push(AppRoutes.admin),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.neutral800,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.neutral700,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.admin_panel_settings_outlined,
                            color: AppColors.surface, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Panel de administración',
                              style: AppTextStyles.headingSm
                                  .copyWith(color: AppColors.surface),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Gestionar comercios y datos →',
                              style: AppTextStyles.bodySm
                                  .copyWith(color: AppColors.neutral400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // sección MI COMERCIO — solo si el usuario tiene rol owner
            if (isOwner) ...[
              const SizedBox(height: 20),
              Text(
                'MI COMERCIO',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.neutral500,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => context.push(AppRoutes.owner),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary500,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.storefront,
                            color: AppColors.surface, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'Mi Comercio',
                              style: AppTextStyles.headingSm
                                  .copyWith(color: AppColors.surface),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Gestionar mi comercio →',
                              style: AppTextStyles.bodySm
                                  .copyWith(color: AppColors.primary100),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // menú principal
            _MenuCard(
              items: [
                _MenuItem(
                  icon: Icons.favorite_border,
                  label: 'Mis Favoritos',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.history,
                  label: 'Historial de Visitas',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Configuración',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            // cerrar sesión
            _MenuCard(
              items: [
                _MenuItem(
                  icon: Icons.logout,
                  label: 'Cerrar sesión',
                  labelColor: AppColors.errorFg,
                  iconColor: AppColors.errorFg,
                  showChevron: false,
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Muestra un diálogo de confirmación antes de cerrar la sesión.
Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Querés cerrar tu sesión en TuM2?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.errorFg),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await ref.read(authOpProvider.notifier).signOut();
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({required this.name, required this.email});
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary100,
            child: Icon(Icons.person_outline,
                color: AppColors.primary500, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTextStyles.headingSm),
              const SizedBox(height: 2),
              Text(email, style: AppTextStyles.bodySm),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items});
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              items[i],
              if (i < items.length - 1)
                const Divider(
                    height: 1, color: AppColors.neutral100, indent: 52),
            ],
          );
        }),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.iconColor,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.neutral600, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.labelMd.copyWith(color: labelColor),
              ),
            ),
            if (showChevron)
              const Icon(Icons.chevron_right,
                  color: AppColors.neutral400, size: 20),
          ],
        ),
      ),
    );
  }
}
