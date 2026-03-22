import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../../modules/auth/screens/splash_screen.dart';
import '../../modules/auth/screens/onboarding_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/auth/screens/verify_email_screen.dart';
import '../../modules/home/screens/home_screen.dart';
import '../../modules/search/screens/search_screen.dart';
import '../../modules/profile/screens/profile_screen.dart';
import '../../modules/owner/screens/owner_panel_screen.dart';
import '../../modules/shared/screens/commerce_detail_screen.dart';
import '../../modules/shell/customer_tabs.dart';
import '../../modules/brand/onboarding_owner/onboarding_owner_flow.dart';
import '../../modules/brand/onboarding_owner/models/onboarding_draft.dart';
import '../../shared/widgets/placeholder_screen.dart';

// ── Nombres de rutas ──────────────────────────────────────────────────────────

abstract class AppRoutes {
  // Auth
  static const splash              = '/';
  static const onboarding          = '/onboarding';
  static const login               = '/login';
  static const verifyEmail         = '/verify-email';

  // CustomerTabs — Tab Inicio
  static const home                = '/home';
  static const homeAbiertoAhora   = '/home/abierto-ahora';
  static const homeFarmacias       = '/home/farmacias-de-turno';

  // CustomerTabs — Tab Buscar
  static const search              = '/search';
  static const searchMap           = '/search/mapa';

  // CustomerTabs — Tab Perfil
  static const profile             = '/profile';

  // Owner (modal full-screen)
  static const owner               = '/owner';
  static const ownerEdit           = '/owner/edit';
  static const ownerProducts       = '/owner/products';
  static const ownerSchedules      = '/owner/schedules';
  static const ownerDuties         = '/owner/duties';

  // Shared
  static const commerceDetail      = '/commerce/:id';
  static const onboardingOwner     = '/onboarding/owner';

  /// Construye la ruta concreta de detalle de un comercio.
  static String commerceDetailPath(String id) => '/commerce/$id';
}

// ── Provider del router ───────────────────────────────────────────────────────

/// Provider del GoRouter. Se recrea cuando cambia el estado de auth
/// para que el redirect global se re-evalúe.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState    = ref.watch(authStateProvider);
  final isFirstLaunchAsync = ref.watch(isFirstLaunchProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isLoggedIn   = authState.valueOrNull != null;
      final isAuthLoading = authState.isLoading;

      // Mientras Firebase resuelve la sesión → quedarse en splash
      if (isAuthLoading) return AppRoutes.splash;

      final location = state.uri.path;

      final isInAuthFlow = location == AppRoutes.login ||
          location == AppRoutes.onboarding ||
          location == AppRoutes.verifyEmail;

      // Con sesión en splash o en auth flow → home
      if (isLoggedIn && (location == AppRoutes.splash || isInAuthFlow)) {
        return AppRoutes.home;
      }

      // Sin sesión en rutas protegidas → auth flow
      if (!isLoggedIn && !isInAuthFlow && location != AppRoutes.splash) {
        final isFirstLaunch = isFirstLaunchAsync.valueOrNull ?? false;
        return isFirstLaunch ? AppRoutes.onboarding : AppRoutes.login;
      }

      return null; // sin redirect
    },
    routes: [
      // ── Auth Stack ────────────────────────────────────────────────────────
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
          final email = state.uri.queryParameters['email'] ?? '';
          return VerifyEmailScreen(email: email);
        },
      ),

      // ── CustomerTabs (StatefulShellRoute — estado preservado) ─────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            CustomerTabs(navigationShell: navigationShell),
        branches: [
          // Tab Inicio
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'abierto-ahora',
                    builder: (_, __) => const PlaceholderScreen(
                      screenId: 'HOME-02',
                      label: 'Abierto ahora',
                    ),
                  ),
                  GoRoute(
                    path: 'farmacias-de-turno',
                    builder: (_, __) => const PlaceholderScreen(
                      screenId: 'HOME-03',
                      label: 'Farmacias de turno',
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Tab Buscar
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (_, __) => const SearchScreen(),
                routes: [
                  GoRoute(
                    path: 'mapa',
                    builder: (_, __) => const PlaceholderScreen(
                      screenId: 'SEARCH-03',
                      label: 'Mapa',
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Tab Perfil
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Owner (modal full-screen) ─────────────────────────────────────────
      GoRoute(
        path: AppRoutes.owner,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const OwnerPanelScreen(),
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, __) => const PlaceholderScreen(
              screenId: 'OWNER-02',
              label: 'Editar perfil del comercio',
            ),
          ),
          GoRoute(
            path: 'products',
            builder: (_, __) => const PlaceholderScreen(
              screenId: 'OWNER-03',
              label: 'Productos',
            ),
          ),
          GoRoute(
            path: 'schedules',
            builder: (_, __) => const PlaceholderScreen(
              screenId: 'OWNER-06',
              label: 'Horarios y señales',
            ),
          ),
          GoRoute(
            path: 'duties',
            builder: (_, __) => const PlaceholderScreen(
              screenId: 'OWNER-09',
              label: 'Turnos de farmacia',
            ),
          ),
        ],
      ),

      // ── Ficha de comercio (fuera del shell → sin tab bar) ─────────────────
      GoRoute(
        path: '/commerce/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CommerceDetailScreen(commerceId: id);
        },
      ),

      // ── Onboarding owner (TuM2-0030 — path estable para no romper PR #15) ─
      GoRoute(
        path: AppRoutes.onboardingOwner,
        builder: (context, state) {
          final extra = state.extra as OnboardingDraft?;
          return OnboardingOwnerFlow(
            existingDraft: extra,
            onComplete: () => context.go(AppRoutes.owner),
            onExit: () => context.go(AppRoutes.home),
          );
        },
      ),
    ],
  );
});
