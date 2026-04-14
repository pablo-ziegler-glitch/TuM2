import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/core/auth/auth_state.dart';
import 'package:tum2/modules/owner/models/operational_signals.dart';
import 'package:tum2/modules/owner/models/owner_merchant_summary.dart';
import 'package:tum2/modules/owner/providers/owner_providers.dart';
import 'package:tum2/modules/owner/screens/owner_panel_screen.dart';

class _FakeUser extends Fake implements User {}

void main() {
  late User fakeUser;

  setUp(() {
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

  testWidgets('renderiza dashboard con estado operativo y quick actions',
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
    expect(find.text('Revisar perfil'), findsOneWidget);
  });
}
