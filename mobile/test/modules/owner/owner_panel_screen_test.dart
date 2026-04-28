import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tum2/core/auth/auth_state.dart';
import 'package:tum2/core/auth/owner_access_summary.dart';
import 'package:tum2/modules/owner/models/operational_signals.dart';
import 'package:tum2/modules/owner/models/owner_merchant_summary.dart';
import 'package:tum2/modules/owner/providers/owner_providers.dart';
import 'package:tum2/modules/owner/screens/owner_panel_screen.dart';

class _FakeUser extends Fake implements User {}

void main() {
  late User fakeUser;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeUser = _FakeUser();
  });

  OwnerMerchantSummary buildMerchant() {
    return OwnerMerchantSummary(
      id: 'merchant-1',
      name: 'Farmacia Central',
      razonSocial: 'Farmacia Central SRL',
      nombreFantasia: 'Farmacia Central',
      categoryId: 'farmacia',
      zoneId: 'palermo',
      address: 'Av. Principal 100',
      status: 'active',
      visibilityStatus: 'visible',
      verificationStatus: 'verified',
      sourceType: 'owner_created',
      hasProducts: true,
      hasSchedules: true,
      hasOperationalSignals: true,
      catalogProductLimitOverride: null,
      activeProductCount: 4,
      updatedAt: DateTime(2026, 4, 8),
      createdAt: DateTime(2026, 4, 1),
      isDataComplete: true,
    );
  }

  OwnerMerchantSummary buildMerchantTwo() {
    return OwnerMerchantSummary(
      id: 'merchant-2',
      name: 'Kiosco Palermo',
      razonSocial: 'Kiosco Palermo SA',
      nombreFantasia: 'Kiosco Palermo',
      categoryId: 'kiosk',
      zoneId: 'palermo',
      address: 'Av. Secundaria 200',
      status: 'active',
      visibilityStatus: 'visible',
      verificationStatus: 'claimed',
      sourceType: 'owner_created',
      hasProducts: true,
      hasSchedules: true,
      hasOperationalSignals: true,
      catalogProductLimitOverride: null,
      activeProductCount: 2,
      updatedAt: DateTime(2026, 4, 9),
      createdAt: DateTime(2026, 4, 2),
      isDataComplete: true,
    );
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required AuthState authState,
    required Future<OwnerMerchantResolution> Function(Ref ref) merchantLoader,
    Future<OwnerOperationalSignal?> Function(Ref ref, String merchantId)?
        signalLoader,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ownerAuthStateProvider.overrideWith((ref) => authState),
          ownerMerchantProvider.overrideWith(merchantLoader),
          if (signalLoader != null)
            ownerOperationalSignalProvider.overrideWith(signalLoader),
        ],
        child: const MaterialApp(home: OwnerPanelScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra estado owner_pending con acceso restringido',
      (tester) async {
    await pumpDashboard(
      tester,
      authState: AuthAuthenticated(
        user: fakeUser,
        role: 'owner',
        ownerPending: true,
      ),
      merchantLoader: (ref) async => const OwnerMerchantResolution(
        primaryMerchant: null,
        allMerchants: [],
      ),
    );

    expect(find.text('Tu validación de dueño está pendiente'), findsOneWidget);
  });

  testWidgets('muestra estado sin comercio vinculado', (tester) async {
    await pumpDashboard(
      tester,
      authState: AuthAuthenticated(user: fakeUser, role: 'owner'),
      merchantLoader: (ref) async => const OwnerMerchantResolution(
        primaryMerchant: null,
        allMerchants: [],
      ),
    );

    expect(find.text('Todavía no tenés un comercio vinculado'), findsOneWidget);
    expect(find.text('Vincular comercio'), findsOneWidget);
  });

  testWidgets('bloquea acceso para usuario no owner', (tester) async {
    await pumpDashboard(
      tester,
      authState: AuthAuthenticated(user: fakeUser, role: 'customer'),
      merchantLoader: (ref) async => const OwnerMerchantResolution(
        primaryMerchant: null,
        allMerchants: [],
      ),
    );

    expect(find.text('Acceso no permitido'), findsOneWidget);
  });

  testWidgets(
      'muestra estado abierto por horario habitual y cards Horarios/Avisos sin aviso activo',
      (tester) async {
    final merchant = buildMerchant();
    await pumpDashboard(
      tester,
      authState: AuthAuthenticated(user: fakeUser, role: 'owner'),
      merchantLoader: (ref) async => OwnerMerchantResolution(
        primaryMerchant: merchant,
        allMerchants: [merchant],
      ),
      signalLoader: (ref, merchantId) async => OwnerOperationalSignal.empty(
        merchantId: merchantId,
        ownerUserId: 'owner-1',
      ).copyWith(
        isOpenNow: true,
      ),
    );

    expect(find.text('Abierto ahora'), findsOneWidget);
    expect(
      find.text(
          'Fuente: horario habitual. Los vecinos ven tu comercio como abierto.'),
      findsOneWidget,
    );
    expect(find.text('Horarios'), findsOneWidget);
    expect(find.text('Definí cuándo atendés normalmente.'), findsOneWidget);
    expect(find.text('Editar horarios'), findsAtLeastNWidgets(1));
    expect(find.text('Avisos de hoy'), findsOneWidget);
    expect(
      find.text('Informá si cerrás, abrís más tarde o estás de vacaciones.'),
      findsOneWidget,
    );
    expect(find.text('Avisar cambio'), findsOneWidget);
    expect(find.text('Revisar perfil'), findsAtLeastNWidgets(1));
  });

  testWidgets('muestra aviso activo con tipo visible y acción de desactivar',
      (tester) async {
    final merchant = buildMerchant();
    await pumpDashboard(
      tester,
      authState: AuthAuthenticated(user: fakeUser, role: 'owner'),
      merchantLoader: (ref) async => OwnerMerchantResolution(
        primaryMerchant: merchant,
        allMerchants: [merchant],
      ),
      signalLoader: (ref, merchantId) async => OwnerOperationalSignal.empty(
        merchantId: merchantId,
        ownerUserId: 'owner-1',
      ).copyWith(
        signalType: OperationalSignalType.vacation,
        isActive: true,
        forceClosed: true,
        message: 'Volvemos el lunes.',
      ),
    );

    expect(find.text('Aviso activo: De vacaciones'), findsOneWidget);
    expect(
      find.text('Fuente: aviso activo. Volvemos el lunes.'),
      findsOneWidget,
    );
    expect(find.text('Avisos de hoy'), findsOneWidget);
    expect(find.text('De vacaciones'), findsOneWidget);
    expect(find.text('Desactivar aviso'), findsOneWidget);
  });

  testWidgets('owner restringido muestra bloqueo explícito', (tester) async {
    await pumpDashboard(
      tester,
      authState: AuthAuthenticated(
        user: fakeUser,
        role: 'owner',
        ownerAccessSummary: const OwnerAccessSummary(
          summaryVersion: 1,
          defaultMerchantId: null,
          approvedMerchantIdsCount: 0,
          pendingClaimMerchantIdsCount: 0,
          hasConcurrentPendingClaims: false,
          primaryContextMode: OwnerPrimaryContextMode.restricted,
          restrictionState: OwnerRestrictionState.blocked,
          restrictionReasonCode: 'fraud_confirmed',
          blockedUntil: null,
        ),
      ),
      merchantLoader: (ref) async => const OwnerMerchantResolution(
        primaryMerchant: null,
        allMerchants: [],
      ),
    );

    expect(find.text('Acceso owner bloqueado'), findsOneWidget);
    expect(find.textContaining('fraud_confirmed'), findsOneWidget);
  });

  testWidgets('owner multi-merchant muestra selector de comercio activo',
      (tester) async {
    final merchant1 = buildMerchant();
    final merchant2 = buildMerchantTwo();

    await pumpDashboard(
      tester,
      authState: AuthAuthenticated(
        user: fakeUser,
        role: 'owner',
        ownerPending: false,
        ownerAccessSummary: const OwnerAccessSummary(
          summaryVersion: 1,
          defaultMerchantId: 'merchant-1',
          approvedMerchantIdsCount: 2,
          pendingClaimMerchantIdsCount: 0,
          hasConcurrentPendingClaims: false,
          primaryContextMode: OwnerPrimaryContextMode.ownerMulti,
          restrictionState: OwnerRestrictionState.none,
          restrictionReasonCode: null,
          blockedUntil: null,
        ),
      ),
      merchantLoader: (ref) async => OwnerMerchantResolution(
        primaryMerchant: merchant1,
        allMerchants: [merchant1, merchant2],
      ),
    );

    expect(find.text('Comercio activo'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets(
      'owner con pending concurrente y comercio aprobado mantiene panel operativo',
      (tester) async {
    final merchant = buildMerchant();

    await pumpDashboard(
      tester,
      authState: AuthAuthenticated(
        user: fakeUser,
        role: 'owner',
        ownerPending: true,
        merchantId: merchant.id,
        ownerAccessSummary: const OwnerAccessSummary(
          summaryVersion: 1,
          defaultMerchantId: 'merchant-1',
          approvedMerchantIdsCount: 1,
          pendingClaimMerchantIdsCount: 2,
          hasConcurrentPendingClaims: true,
          primaryContextMode: OwnerPrimaryContextMode.ownerWithPending,
          restrictionState: OwnerRestrictionState.none,
          restrictionReasonCode: null,
          blockedUntil: null,
        ),
      ),
      merchantLoader: (ref) async => OwnerMerchantResolution(
        primaryMerchant: merchant,
        allMerchants: [merchant],
      ),
      signalLoader: (ref, merchantId) async => OwnerOperationalSignal.empty(
        merchantId: merchantId,
        ownerUserId: 'owner-1',
      ).copyWith(
        isOpenNow: true,
      ),
    );

    expect(find.text('Mi catálogo'), findsOneWidget);
    expect(
        find.text('Tu validación como dueño sigue pendiente'), findsOneWidget);
  });
}
