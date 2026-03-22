import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// AUTH-01 — Splash con detección de sesión y lógica de decisión.
///
/// Muestra el logo + indicador de carga mientras [AuthNotifier] resuelve
/// el estado inicial. Si Firebase no responde en 5 segundos, redirige a
/// /login con un banner de error de red.
///
/// La navegación post-carga la maneja el redirect global del router —
/// esta pantalla no hace context.go() excepto en el caso de timeout.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startTimeoutGuard();
  }

  /// Si tras 5 segundos el estado sigue siendo [AuthLoading], fuerza
  /// AuthUnauthenticated para que el redirect global lleve a /login.
  /// Navegar directamente con context.go() quedaría atrapado en el guard
  /// que redirige a splash mientras el estado sea AuthLoading.
  void _startTimeoutGuard() {
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      final current = ref.read(authNotifierProvider).authState;
      if (current is AuthLoading) {
        ref.read(authNotifierProvider).forceUnauthenticated();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión. Intentá nuevamente.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo TuM2
            Text(
              'TuM2',
              style: AppTextStyles.headingLg.copyWith(
                color: AppColors.primary500,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 32),
            // Indicador de carga sutil
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
