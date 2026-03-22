import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// PROFILE-01 — Perfil del usuario (tab Perfil) placeholder.
///
/// Adapta sus acciones de prueba según el rol del usuario autenticado:
/// - owner → muestra botón "Ir a mi comercio"
/// - admin → muestra botón "Panel admin"
/// Será reemplazada en TuM2-0054/0055.
class ProfilePlaceholderScreen extends ConsumerWidget {
  const ProfilePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider).authState;

    final List<NavAction> actions = [
      NavAction(
        label: 'Configuración (PROFILE-02)',
        onTap: () => context.push(AppRoutes.profileSettings),
      ),
    ];

    if (authState case AuthAuthenticated(:final role)) {
      if (role == 'owner') {
        actions.insert(
          0,
          NavAction(
            label: 'Ir a mi comercio (OWNER-01)',
            onTap: () => context.push(AppRoutes.owner),
          ),
        );
      } else if (role == 'admin') {
        actions.insert(
          0,
          NavAction(
            label: 'Panel admin (ADMIN-01)',
            onTap: () => context.push(AppRoutes.admin),
          ),
        );
      }
    }

    return PlaceholderScreen(
      screenId: 'PROFILE-01',
      label: 'Mi perfil',
      navActions: actions,
    );
  }
}
