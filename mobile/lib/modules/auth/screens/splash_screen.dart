import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// AUTH-01 — Splash / Loading
///
/// Pantalla de entrada. Detecta si hay sesión activa y redirige.
/// Fondo azul primary500, logo TuM2 centrado.
///
/// Flujo:
///   sesión activa     → /home
///   primer uso        → /onboarding
///   sesión expirada   → /login
///
/// Nota: la navegación la maneja el redirect de go_router en app_router.dart.
/// Esta pantalla solo muestra el logo mientras el estado de auth se resuelve.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escucha el estado de auth. go_router redirige automáticamente
    // cuando authStateProvider deja de estar loading.
    ref.listen(authStateProvider, (_, next) {
      if (!next.isLoading) {
        final user = next.valueOrNull;
        if (user != null) {
          context.go(AppRoutes.home);
        }
        // Sin sesión: el redirect de app_router maneja onboarding vs login
      }
    });

    return Scaffold(
      backgroundColor: AppColors.primary500,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TODO(figma): reemplazar con asset logo TuM2 en blanco
            Text(
              'TuM2',
              style: AppTextStyles.headingLg.copyWith(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu metro cuadrado',
              style: AppTextStyles.bodySm.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
