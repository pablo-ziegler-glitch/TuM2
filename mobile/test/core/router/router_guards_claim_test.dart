import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/core/auth/owner_access_summary.dart';
import 'package:tum2/core/auth/auth_state.dart';
import 'package:tum2/core/router/app_routes.dart';
import 'package:tum2/core/router/router_guards.dart';

class _FakeUser extends Fake implements User {}

void main() {
  late User user;

  setUp(() {
    user = _FakeUser();
  });

  test('usuario autenticado customer puede navegar a /claim', () {
    final result = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'customer',
      ),
      location: AppRoutes.claimIntro,
    );
    expect(result, isNull);
  });

  test('usuario sin sesión en /claim redirige a /login', () {
    final result = RouterGuards.evaluate(
      authState: const AuthUnauthenticated(),
      location: AppRoutes.claimIntro,
    );
    expect(result, AppRoutes.login);
  });

  test('owner_pending puede navegar a /claim/status', () {
    final result = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'owner',
        ownerPending: true,
      ),
      location: AppRoutes.claimStatus,
    );
    expect(result, isNull);
  });

  test('E2E-01 claim aprobado + refresh permite entrada OWNER-01', () {
    final result = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'owner',
        ownerPending: false,
        merchantId: 'merchant-approved',
        ownerAccessSummary: const OwnerAccessSummary(
          summaryVersion: 1,
          defaultMerchantId: 'merchant-approved',
          approvedMerchantIdsCount: 1,
          pendingClaimMerchantIdsCount: 0,
          hasConcurrentPendingClaims: false,
          primaryContextMode: OwnerPrimaryContextMode.ownerSingle,
          restrictionState: OwnerRestrictionState.none,
          restrictionReasonCode: null,
          blockedUntil: null,
        ),
      ),
      location: AppRoutes.login,
    );
    expect(result, AppRoutes.ownerResolve);
  });

  test('deep link stale a owner desde customer redirige a access updated', () {
    final result = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'customer',
      ),
      location: AppRoutes.ownerProducts,
    );
    expect(
      result,
      AppRoutes.accessUpdatedPath(
        target: 'customer',
        reason: 'deep_route_access_changed',
        from: AppRoutes.ownerProducts,
      ),
    );
  });

  test(
      'owner con pending concurrente y comercio aprobado mantiene acceso a rutas owner',
      () {
    final result = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'owner',
        ownerPending: true,
        merchantId: 'merchant-a',
        ownerAccessSummary: const OwnerAccessSummary(
          summaryVersion: 1,
          defaultMerchantId: 'merchant-a',
          approvedMerchantIdsCount: 1,
          pendingClaimMerchantIdsCount: 2,
          hasConcurrentPendingClaims: true,
          primaryContextMode: OwnerPrimaryContextMode.ownerWithPending,
          restrictionState: OwnerRestrictionState.none,
          restrictionReasonCode: null,
          blockedUntil: null,
        ),
      ),
      location: AppRoutes.ownerProducts,
    );
    expect(result, isNull);
  });

  test('owner restringido no puede reingresar a subrutas owner por deep link',
      () {
    final result = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'owner',
        merchantId: 'merchant-a',
        ownerAccessSummary: const OwnerAccessSummary(
          summaryVersion: 1,
          defaultMerchantId: 'merchant-a',
          approvedMerchantIdsCount: 1,
          pendingClaimMerchantIdsCount: 0,
          hasConcurrentPendingClaims: false,
          primaryContextMode: OwnerPrimaryContextMode.restricted,
          restrictionState: OwnerRestrictionState.blocked,
          restrictionReasonCode: 'fraud_confirmed',
          blockedUntil: null,
        ),
      ),
      location: AppRoutes.ownerProducts,
    );
    expect(result, AppRoutes.ownerDashboard);
  });

  test(
      'E2E-06 offline con estado stale no habilita owner hasta refresh exitoso',
      () {
    final staleResult = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'owner',
        ownerPending: true,
      ),
      location: AppRoutes.ownerProducts,
    );
    expect(staleResult, AppRoutes.ownerDashboard);

    final refreshedResult = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'owner',
        ownerPending: false,
        merchantId: 'merchant-ok',
        ownerAccessSummary: const OwnerAccessSummary(
          summaryVersion: 1,
          defaultMerchantId: 'merchant-ok',
          approvedMerchantIdsCount: 1,
          pendingClaimMerchantIdsCount: 0,
          hasConcurrentPendingClaims: false,
          primaryContextMode: OwnerPrimaryContextMode.ownerSingle,
          restrictionState: OwnerRestrictionState.none,
          restrictionReasonCode: null,
          blockedUntil: null,
        ),
      ),
      location: AppRoutes.ownerProducts,
    );
    expect(refreshedResult, isNull);
  });

  test('owner sin comercios aprobados y con pending no entra a owner products',
      () {
    final result = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'owner',
        ownerPending: true,
      ),
      location: AppRoutes.ownerProducts,
    );
    expect(result, AppRoutes.ownerDashboard);
  });

  test(
      'E2E-08 múltiples claims concurrentes sin aprobados mantienen ruta de pending',
      () {
    final result = RouterGuards.evaluate(
      authState: AuthAuthenticated(
        user: user,
        role: 'owner',
        ownerPending: true,
        ownerAccessSummary: const OwnerAccessSummary(
          summaryVersion: 1,
          defaultMerchantId: null,
          approvedMerchantIdsCount: 0,
          pendingClaimMerchantIdsCount: 2,
          hasConcurrentPendingClaims: true,
          primaryContextMode: OwnerPrimaryContextMode.ownerPendingOnly,
          restrictionState: OwnerRestrictionState.none,
          restrictionReasonCode: null,
          blockedUntil: null,
        ),
      ),
      location: AppRoutes.ownerProducts,
    );
    expect(result, AppRoutes.ownerDashboard);
  });
}
