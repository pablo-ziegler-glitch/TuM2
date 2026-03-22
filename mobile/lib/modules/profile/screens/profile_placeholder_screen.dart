import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// PROFILE-01 — Perfil del usuario (tab Perfil).
///
/// Muestra la vista de cliente o la vista de owner/admin según el rol.
/// Los datos del usuario vienen del estado de autenticación reactivo.
class ProfilePlaceholderScreen extends ConsumerWidget {
  const ProfilePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider).authState;

    if (authState is! AuthAuthenticated) {
      return const SizedBox.shrink();
    }

    final role = authState.role;
    if (role == 'owner' || role == 'admin') {
      return _OwnerProfileView(user: authState.user);
    }
    return _CustomerProfileView(user: authState.user);
  }
}

// ── Vista Customer ─────────────────────────────────────────────────────────────

class _CustomerProfileView extends StatelessWidget {
  final User user;

  const _CustomerProfileView({required this.user});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.displayName ?? user.email ?? 'U');

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mi Perfil', style: AppTextStyles.headingMd),
              const SizedBox(height: 4),
              Text(
                'Gestiona tu experiencia en el barrio.',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.neutral600,
                ),
              ),
              const SizedBox(height: 24),

              // Avatar + nombre
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary100,
                      child: Text(
                        initials,
                        style: AppTextStyles.headingSm.copyWith(
                          color: AppColors.primary500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.displayName ?? 'Usuario',
                      style: AppTextStyles.labelMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email ?? '',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              const Divider(color: AppColors.neutral100),
              const SizedBox(height: 8),

              _MenuRow(
                label: 'Mis Favoritos',
                icon: Icons.favorite_border,
                onTap: () {},
              ),
              _MenuRow(
                label: 'Historial de Visitas',
                icon: Icons.history,
                onTap: () {},
              ),
              _MenuRow(
                label: 'Configuración',
                icon: Icons.settings_outlined,
                onTap: () => context.push(AppRoutes.profileSettings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vista Owner / Admin ────────────────────────────────────────────────────────

class _OwnerProfileView extends StatelessWidget {
  final User user;

  const _OwnerProfileView({required this.user});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.displayName ?? user.email ?? 'U');
    final displayName = user.displayName ?? 'Usuario';
    final email = user.email ?? '';

    // Nombre del comercio mockeado — se reemplazará con datos reales en TuM2-0064
    const commerceName = 'Mi comercio';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mi perfil', style: AppTextStyles.headingMd),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    color: AppColors.neutral600,
                    onPressed: () => context.push(AppRoutes.profileSettings),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Avatar + nombre
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary100,
                    child: Text(
                      initials,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: AppTextStyles.labelMd.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        email,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.neutral600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Card azul "Gestionar mi comercio"
              GestureDetector(
                onTap: () => context.push(AppRoutes.owner),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              commerceName,
                              style: AppTextStyles.labelMd.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Gestionar mi comercio →',
                              style: AppTextStyles.bodySm.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sección MI CUENTA
              Text(
                'MI CUENTA',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.neutral500,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),

              _MenuRow(label: 'Notificaciones', icon: Icons.notifications_none, onTap: () {}),
              _MenuRow(label: 'Zona activa', icon: Icons.location_on_outlined, onTap: () {}),
              _MenuRow(label: 'Ayuda', icon: Icons.help_outline, onTap: () {}),
              _MenuRow(
                label: 'Cerrar sesión',
                icon: Icons.logout,
                labelColor: AppColors.errorFg,
                iconColor: AppColors.errorFg,
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                },
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'TuM2 Business v2.4.0',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.neutral400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget reutilizable de fila de menú ───────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;

  const _MenuRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.labelColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? AppColors.neutral600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMd.copyWith(
                  color: labelColor ?? AppColors.neutral900,
                ),
              ),
            ),
            if (labelColor == null)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.neutral400,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Helper ─────────────────────────────────────────────────────────────────────

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : 'U';
}
