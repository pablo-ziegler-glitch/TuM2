import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_state.dart';
import '../providers/auth_providers.dart';
import 'app_routes.dart';
import 'pending_route_provider.dart';
import 'router_guards.dart';
import '../../modules/auth/screens/splash_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/auth/screens/onboarding_screen.dart';
import '../../modules/auth/screens/verify_email_screen.dart';
import '../../modules/auth/screens/display_name_screen.dart';
import '../../modules/home/screens/home_screen.dart';
import '../../modules/home/screens/abierto_ahora_screen.dart';
import '../../modules/search/screens/search_screen.dart';
import '../../modules/search/screens/search_results_screen.dart';
import '../../modules/search/screens/search_map_screen.dart';
import '../../modules/search/screens/pharmacy_results_screen.dart';
import '../../modules/search/screens/location_fallback_screen.dart';
import '../../modules/profile/screens/profile_screen.dart';
import '../../modules/owner/screens/owner_panel_screen.dart';
import '../../modules/admin/screens/admin_panel_placeholder_screen.dart';
import '../../modules/shared/screens/commerce_detail_screen.dart';
import '../../modules/shell/customer_tabs.dart';
import '../../modules/brand/onboarding_owner/onboarding_owner_flow.dart';
import '../../modules/brand/onboarding_owner/models/onboarding_draft.dart';
import '../../modules/pharmacy/screens/pharmacy_duty_screen.dart';
import '../../modules/pharmacy/screens/pharmacy_duty_detail_screen.dart';
import '../../modules/pharmacy/models/pharmacy_duty_item.dart';
import '../../shared/widgets/placeholder_screen.dart';

// Re-exportar para que otros módulos puedan usar AppRoutes importando app_router.dart
export 'app_routes.dart';

// ── Router provider ──────────────────────────────────────────────────────────

/// Provider del [GoRouter] de la aplicación.
///
/// Usa [AuthNotifier] (ChangeNotifier) como [refreshListenable] para re-evaluar
/// los guards cada vez que el estado de autenticación cambia.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-evaluar el redirect inicial cuando se resuelve el primer lanzamiento.
  ref.watch(isFirstLaunchProvider);

  // authNotifier aquí es el ChangeNotifier de auth_notifier.dart
  final authNotifier = ref.read(authNotifierProvider);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) => _buildRedirect(ref, state),
    routes: _buildRoutes(),
  );

  ref.onDispose(router.dispose);
  return router;
});

// ── Redirect global ──────────────────────────────────────────────────────────

String? _buildRedirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authNotifierProvider).authState;
  final locationPath = state.uri.path;
  final location = state.uri.query.isEmpty
      ? locationPath
      : '$locationPath?${state.uri.query}';
  var pendingRoute = ref.read(pendingRouteProvider);

  // ── 1. Entrada sin sesión: splash → onboarding o home invitado ──
  if (authState is AuthUnauthenticated && locationPath == AppRoutes.splash) {
    final firstLaunchState = ref.read(isFirstLaunchProvider);
    if (firstLaunchState.isLoading) return null;
    final isFirstLaunch = firstLaunchState.valueOrNull ?? false;
    return RouterGuards.unauthenticatedEntryPath(
      isFirstLaunch: isFirstLaunch,
    );
  }

  // ── 2. Micro-step displayName para usuarios de magic link sin nombre ──
  if (authState is AuthAuthenticated) {
    final user = authState.user;
    final displayNameEmpty =
        user.displayName == null || user.displayName!.isEmpty;
    final isEmailLinkUser =
        !user.providerData.any((p) => p.providerId == 'google.com');
    final skipped = ref.read(displayNameSkippedProvider);
    final onDisplayNameScreen = locationPath == AppRoutes.displayName;

    if (displayNameEmpty &&
        isEmailLinkUser &&
        !skipped &&
        !onDisplayNameScreen) {
      // Solo redirigir si viene de una ruta de auth o de home
      // (no interrumpir flujo de onboarding de owner u otras rutas profundas)
      if (RouterGuards.isAuthPath(locationPath) ||
          locationPath == AppRoutes.home) {
        return AppRoutes.displayName;
      }
    }
  }

  // ── 3. Guardar pending route para deep links pre-auth ──
  if (authState is AuthUnauthenticated &&
      !RouterGuards.isPublicPath(locationPath) &&
      locationPath != AppRoutes.login &&
      locationPath != AppRoutes.splash &&
      pendingRoute != location) {
    pendingRoute = location;
    ref.read(pendingRouteProvider.notifier).state = location;
  }

  // ── 4. Guards estándar ──
  return RouterGuards.evaluate(
    authState: authState,
    location: location,
    pendingRoute: pendingRoute,
    consumePendingRoute: () =>
        ref.read(pendingRouteProvider.notifier).state = null,
  );
}

// ── Árbol de rutas ────────────────────────────────────────────────────────────

List<RouteBase> _buildRoutes() {
  return [
    // ── Auth Stack ────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.splash,
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.emailVerification,
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        final crossDevice = state.uri.queryParameters['cross_device'] == 'true';
        return VerifyEmailScreen(email: email, isCrossDevice: crossDevice);
      },
    ),

    // Micro-step de nombre de usuario (magic link sin displayName)
    GoRoute(
      path: AppRoutes.displayName,
      builder: (_, __) => const DisplayNameScreen(),
    ),

    // ── CustomerTabs (StatefulShellRoute con estado preservado) ───────────────
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
                  builder: (_, __) => const AbiertoAhoraScreen(),
                ),
                GoRoute(
                  path: 'farmacias-de-turno',
                  builder: (_, __) => const PharmacyDutyScreen(),
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
                  path: 'resultados',
                  builder: (context, state) {
                    final q = state.uri.queryParameters['q'] ?? '';
                    final openNow =
                        state.uri.queryParameters['openNow'] == 'true';
                    return SearchResultsScreen(
                        query: q, openNowFilter: openNow);
                  },
                ),
                GoRoute(
                  path: 'farmacias',
                  builder: (_, __) => const PharmacyResultsScreen(),
                ),
                GoRoute(
                  path: 'ubicacion',
                  builder: (_, __) => const LocationFallbackScreen(),
                ),
                GoRoute(
                  path: 'mapa',
                  builder: (_, __) => const SearchMapScreen(),
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
              routes: [
                GoRoute(
                  path: 'settings',
                  builder: (_, __) => const PlaceholderScreen(
                    screenId: 'PROFILE-02',
                    label: 'Configuración',
                  ),
                ),
                GoRoute(
                  path: 'propuestas',
                  builder: (_, __) => const PlaceholderScreen(
                    screenId: 'PROFILE-03',
                    label: 'Propuestas y votos',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── OwnerStack (modal full-screen) ────────────────────────────────────────
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
            roleRequired: 'owner',
          ),
        ),
        GoRoute(
          path: 'products',
          builder: (_, __) => const PlaceholderScreen(
            screenId: 'OWNER-03',
            label: 'Productos',
            roleRequired: 'owner',
          ),
        ),
        GoRoute(
          path: 'schedules',
          builder: (_, __) => const PlaceholderScreen(
            screenId: 'OWNER-06',
            label: 'Horarios y señales',
            roleRequired: 'owner',
          ),
        ),
        GoRoute(
          path: 'duties',
          builder: (_, __) => const PlaceholderScreen(
            screenId: 'OWNER-09',
            label: 'Turnos de farmacia',
            roleRequired: 'owner',
          ),
        ),
      ],
    ),

    // ── AdminStack (modal full-screen) ────────────────────────────────────────
    GoRoute(
      path: AppRoutes.admin,
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: const AdminPanelPlaceholderScreen(),
      ),
      routes: [
        GoRoute(
          path: 'merchants',
          builder: (_, __) => const PlaceholderScreen(
            screenId: 'ADMIN-02',
            label: 'Comercios (moderación)',
            roleRequired: 'admin',
          ),
        ),
        GoRoute(
          path: 'signals',
          builder: (_, __) => const PlaceholderScreen(
            screenId: 'ADMIN-04',
            label: 'Señales reportadas',
            roleRequired: 'admin',
          ),
        ),
      ],
    ),

    // ── Shared Screens ─────────────────────────────────────────────────────────
    // DETAIL-01: Ficha de comercio — fuera del shell, el tab bar se oculta.
    GoRoute(
      path: '/commerce/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CommerceDetailScreen(commerceId: id);
      },
    ),

    // Detalle de farmacia de turno — fuera del shell.
    GoRoute(
      path: '/pharmacy/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final item = state.extra as PharmacyDutyItem?;
        return PharmacyDutyDetailScreen(pharmacyId: id, item: item);
      },
    ),

    // DETAIL-03: Onboarding de owner — path estable para compatibilidad.
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
  ];
}
