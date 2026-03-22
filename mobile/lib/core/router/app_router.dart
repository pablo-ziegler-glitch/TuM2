import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../../modules/auth/screens/splash_screen.dart';
import '../../modules/auth/screens/onboarding_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/auth/screens/verify_email_screen.dart';
import '../../modules/home/screens/home_screen.dart';

// ── Nombres de rutas ──────────────────────────────────────────────────────────

abstract class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const verifyEmail = '/verify-email';
  static const home = '/home';
}

// ── Provider del router ───────────────────────────────────────────────────────

/// Provider del GoRouter. Se actualiza cuando cambia el estado de auth.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Escucha cambios de sesión para refrescar el redirect
  final authState = ref.watch(authStateProvider);
  final isFirstLaunchAsync = ref.watch(isFirstLaunchProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthLoading = authState.isLoading;

      // Mientras carga el estado de auth, queda en splash
      if (isAuthLoading) return AppRoutes.splash;

      final location = state.uri.path;

      final isInAuthFlow = location == AppRoutes.login ||
          location == AppRoutes.onboarding ||
          location == AppRoutes.verifyEmail;

      // Con sesión en splash o en auth flow → home
      if (isLoggedIn && (location == AppRoutes.splash || isInAuthFlow)) {
        return AppRoutes.home;
      }

      // Sin sesión en splash o en rutas protegidas → redirigir según primer uso
      // El guard isAuthLoading ya cubre la espera; aquí auth ya resolvió
      if (!isLoggedIn && !isInAuthFlow) {
        final isFirstLaunch = isFirstLaunchAsync.valueOrNull ?? false;
        return isFirstLaunch ? AppRoutes.onboarding : AppRoutes.login;
      }

      return null; // sin redirect
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) {
          // El email se pasa como query param desde AUTH-03
          final email = state.uri.queryParameters['email'] ?? '';
          return VerifyEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});
