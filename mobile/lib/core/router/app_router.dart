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
import '../../modules/merchant_claim/screens/merchant_claim_flow_screens.dart';
import '../../modules/owner/screens/owner_panel_screen.dart';
import '../../modules/owner/screens/owner_operational_signals_screen.dart';
import '../../modules/owner/screens/owner_schedule_screen.dart';
import '../../modules/owner/screens/owner_resolve_page.dart';
import '../../modules/owner/screens/owner_access_guard_page.dart';
import '../../modules/owner/screens/owner_access_updated_screen.dart';
import '../../modules/owner/screens/owner_products_screen.dart';
import '../../modules/owner/screens/product_form_screen.dart';
import '../../modules/owner/screens/product_saved_screen.dart';
import '../../modules/owner/screens/owner_pharmacy_duties_screen.dart';
import '../../modules/owner/screens/owner_pharmacy_duty_editor_screen.dart';
import '../../modules/owner/pharmacy/presentation/upcoming_duty_confirmation_screen.dart';
import '../../modules/owner/pharmacy/presentation/report_duty_incident_screen.dart';
import '../../modules/owner/pharmacy/presentation/select_replacement_candidates_screen.dart';
import '../../modules/owner/pharmacy/presentation/reassignment_tracking_screen.dart';
import '../../modules/owner/pharmacy/presentation/coverage_invitation_screen.dart';
import '../../modules/owner/pharmacy/presentation/coverage_response_result_screen.dart';
import '../../modules/owner/pharmacy/presentation/public_duty_status_screen.dart';
import '../../modules/admin/screens/admin_panel_placeholder_screen.dart';
import '../../modules/merchant_detail/presentation/merchant_detail_page.dart';
import '../../modules/merchant_detail/presentation/product_detail_page.dart';
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
      path: AppRoutes.claimIntro,
      builder: (_, __) => const ClaimIntroScreen(),
    ),
    GoRoute(
      path: AppRoutes.claimSelect,
      builder: (_, __) => const ClaimSelectMerchantScreen(),
    ),
    GoRoute(
      path: AppRoutes.claimApplicant,
      builder: (_, __) => const ClaimApplicantDataScreen(),
    ),
    GoRoute(
      path: AppRoutes.claimEvidence,
      builder: (_, __) => const ClaimEvidenceScreen(),
    ),
    GoRoute(
      path: AppRoutes.claimConsent,
      builder: (_, __) => const ClaimConsentScreen(),
    ),
    GoRoute(
      path: AppRoutes.claimSuccess,
      builder: (_, __) => const ClaimSuccessScreen(),
    ),
    GoRoute(
      path: AppRoutes.claimStatus,
      builder: (_, __) => const ClaimStatusScreen(),
    ),
    GoRoute(
      path: AppRoutes.accessUpdated,
      builder: (_, state) {
        final targetRaw =
            (state.uri.queryParameters['target'] ?? 'customer').trim();
        final reasonRaw =
            (state.uri.queryParameters['reason'] ?? 'deep_route_access_changed')
                .trim();
        final from = state.uri.queryParameters['from'];

        final target = targetRaw == 'owner'
            ? OwnerAccessUpdatedTarget.owner
            : OwnerAccessUpdatedTarget.customer;
        final reason = switch (reasonRaw) {
          'approved_transition' => OwnerAccessUpdatedReason.approvedTransition,
          'claim_closed' => OwnerAccessUpdatedReason.claimClosed,
          _ => OwnerAccessUpdatedReason.deepRouteAccessChanged,
        };

        return OwnerAccessUpdatedScreen(
          target: target,
          reason: reason,
          fromPath: from,
        );
      },
    ),

    // ── OwnerStack (modal full-screen) ────────────────────────────────────────
    GoRoute(
      path: AppRoutes.ownerResolve,
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: OwnerResolvePage(
          targetLocation: state.uri.queryParameters['target'],
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.owner,
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: OwnerResolvePage(
          targetLocation: state.uri.queryParameters['target'],
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.ownerDashboard,
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: const OwnerPanelScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.ownerEdit,
      builder: (_, __) => const OwnerAccessGuardPage(
        title: 'Editar comercio',
        child: PlaceholderScreen(
          screenId: 'OWNER-02',
          label: 'Editar perfil del comercio',
          roleRequired: 'owner',
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.ownerProducts,
      builder: (_, __) => const OwnerAccessGuardPage(
        title: 'Productos',
        requireOwnerRole: true,
        child: OwnerProductsScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.ownerProductsNew,
      builder: (_, __) => const OwnerAccessGuardPage(
        title: 'Nuevo producto',
        requireOwnerRole: true,
        child: ProductFormScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.ownerProductsEdit,
      builder: (_, state) {
        final productId = state.pathParameters['productId']!;
        return OwnerAccessGuardPage(
          title: 'Editar producto',
          requireOwnerRole: true,
          child: ProductFormScreen(productId: productId),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.ownerProductsSaved,
      builder: (_, state) {
        final payload = state.extra as ProductSavedPayload?;
        if (payload == null) {
          return const OwnerAccessGuardPage(
            title: 'Producto guardado',
            requireOwnerRole: true,
            child: OwnerProductsScreen(),
          );
        }
        return OwnerAccessGuardPage(
          title: 'Producto guardado',
          requireOwnerRole: true,
          child: ProductSavedScreen(payload: payload),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.ownerSchedules,
      builder: (_, __) => const OwnerAccessGuardPage(
        title: 'Editar horarios',
        child: OwnerScheduleScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.ownerSignals,
      builder: (_, __) => const OwnerAccessGuardPage(
        title: 'Avisos de hoy',
        child: OwnerOperationalSignalsScreen(),
      ),
    ),
    // Compatibilidad temporal con path histórico.
    GoRoute(
      path: AppRoutes.ownerPharmacyDuties,
      builder: (_, __) => const OwnerAccessGuardPage(
        title: 'Turnos de farmacia',
        child: OwnerPharmacyDutiesScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.ownerDuties,
      builder: (_, __) => const OwnerAccessGuardPage(
        title: 'Turnos de farmacia',
        child: OwnerPharmacyDutiesScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.ownerPharmacyDutyNew,
      builder: (_, state) => OwnerAccessGuardPage(
        title: 'Nuevo turno',
        child: OwnerPharmacyDutyEditorScreen(
          initialDateKey: state.uri.queryParameters['date'],
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.ownerPharmacyDutyEdit,
      builder: (_, state) {
        final dutyId = state.pathParameters['dutyId']!;
        final extra = state.extra as OwnerPharmacyDutyEditorExtra?;
        return OwnerAccessGuardPage(
          title: 'Editar turno',
          child: OwnerPharmacyDutyEditorScreen(
            dutyId: dutyId,
            extra: extra,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.ownerPharmacyDutyUpcoming,
      builder: (_, __) => const OwnerAccessGuardPage(
        title: 'Confirmación de guardia',
        child: UpcomingDutyConfirmationScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.ownerPharmacyDutyIncidentReport,
      builder: (_, state) {
        final dutyId = state.pathParameters['dutyId']!;
        return OwnerAccessGuardPage(
          title: 'Reportar incidente',
          child: ReportDutyIncidentScreen(dutyId: dutyId),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.ownerPharmacyDutySelectCandidates,
      builder: (_, state) {
        final dutyId = state.pathParameters['dutyId']!;
        return OwnerAccessGuardPage(
          title: 'Seleccionar candidatas',
          child: SelectReplacementCandidatesScreen(dutyId: dutyId),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.ownerPharmacyDutyTracking,
      builder: (_, state) {
        final dutyId = state.pathParameters['dutyId']!;
        return OwnerAccessGuardPage(
          title: 'Seguimiento',
          child: ReassignmentTrackingScreen(dutyId: dutyId),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.ownerPharmacyDutyCoverageInvitation,
      builder: (_, state) {
        final requestId = state.pathParameters['requestId']!;
        return OwnerAccessGuardPage(
          title: 'Invitación',
          child: CoverageInvitationScreen(requestId: requestId),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.ownerPharmacyDutyCoverageResult,
      builder: (_, state) {
        final status = state.uri.queryParameters['status'] ?? '';
        final action = state.uri.queryParameters['action'] ?? '';
        return OwnerAccessGuardPage(
          title: 'Resultado',
          child: CoverageResponseResultScreen(
            status: status,
            action: action,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.ownerPharmacyDutyPublicStatus,
      builder: (_, __) => const OwnerAccessGuardPage(
        title: 'Estado público',
        child: PublicDutyStatusScreen(),
      ),
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
      path: AppRoutes.commerceProductDetail,
      builder: (context, state) {
        final merchantId = state.pathParameters['merchantId']!;
        final productId = state.pathParameters['productId']!;
        return ProductDetailPage(
          merchantId: merchantId,
          productId: productId,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.commerceDetail,
      builder: (context, state) {
        final merchantId = state.pathParameters['merchantId']!;
        final source =
            (state.uri.queryParameters['source'] ?? 'unknown').trim();
        return MerchantDetailPage(
          merchantId: merchantId,
          source: source.isEmpty ? 'unknown' : source,
        );
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
          onComplete: () => context.go(AppRoutes.ownerResolve),
          onExit: () => context.go(AppRoutes.home),
        );
      },
    ),
  ];
}
