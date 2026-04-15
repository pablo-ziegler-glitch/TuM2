import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/owner/application/owner_dashboard_logic.dart';
import 'package:tum2/modules/owner/models/operational_signals.dart';
import 'package:tum2/modules/owner/models/owner_merchant_summary.dart';

void main() {
  OwnerMerchantSummary buildMerchant({
    String status = 'active',
    String visibilityStatus = 'visible',
    bool hasProducts = true,
    bool hasSchedules = true,
  }) {
    return OwnerMerchantSummary(
      id: 'merchant-1',
      name: 'Farmacia Central',
      razonSocial: 'Farmacia Central SRL',
      nombreFantasia: 'Farmacia Central',
      categoryId: 'farmacia',
      zoneId: 'palermo',
      address: 'Av. Principal 100',
      status: status,
      visibilityStatus: visibilityStatus,
      verificationStatus: 'verified',
      sourceType: 'owner_created',
      hasProducts: hasProducts,
      hasSchedules: hasSchedules,
      hasOperationalSignals: true,
      catalogProductLimitOverride: null,
      activeProductCount: 4,
      updatedAt: DateTime(2026, 4, 8),
      createdAt: DateTime(2026, 4, 1),
      isDataComplete: true,
    );
  }

  group('resolveOperationalSummary', () {
    test('devuelve Abierto ahora cuando isOpenNow=true', () {
      final summary = resolveOperationalSummary(
        merchant: buildMerchant(),
        signal: OwnerOperationalSignal.empty(
          merchantId: 'merchant-1',
          ownerUserId: 'owner-1',
        ).copyWith(
          isOpenNow: true,
          todayScheduleLabel: 'Abierto hasta 20:00',
        ),
      );

      expect(summary.title, 'Abierto ahora');
      expect(summary.isUnknown, isFalse);
    });

    test('prioriza condición especial cuando hay forceClosed activo', () {
      final summary = resolveOperationalSummary(
        merchant: buildMerchant(),
        signal: OwnerOperationalSignal.empty(
          merchantId: 'merchant-1',
          ownerUserId: 'owner-1',
        ).copyWith(
          signalType: OperationalSignalType.temporaryClosure,
          isActive: true,
          forceClosed: true,
          message: 'Cerrado por mantenimiento',
        ),
      );

      expect(summary.title, 'Cerrado por condición especial');
      expect(summary.isSpecialCondition, isTrue);
    });

    test('devuelve desconocido cuando no hay estado operativo', () {
      final summary = resolveOperationalSummary(
        merchant: buildMerchant(),
        signal: null,
      );

      expect(summary.title, 'Estado no disponible');
      expect(summary.isUnknown, isTrue);
    });
  });

  group('buildOwnerDashboardAlerts', () {
    test('prioriza owner_pending como alerta crítica', () {
      final alerts = buildOwnerDashboardAlerts(
        merchant: buildMerchant(visibilityStatus: 'visible'),
        ownerPending: true,
        signal: OwnerOperationalSignal.empty(
          merchantId: 'merchant-1',
          ownerUserId: 'owner-1',
        ),
      );

      expect(alerts.first.id, 'owner_pending');
      expect(alerts.first.severity, OwnerDashboardAlertSeverity.critical);
    });

    test('incluye alerta de comercio oculto con CTA a perfil', () {
      final alerts = buildOwnerDashboardAlerts(
        merchant: buildMerchant(visibilityStatus: 'hidden'),
        ownerPending: false,
        signal: OwnerOperationalSignal.empty(
          merchantId: 'merchant-1',
          ownerUserId: 'owner-1',
        ),
      );

      final hiddenAlert =
          alerts.firstWhere((item) => item.id == 'visibility_hidden');
      expect(hiddenAlert.ctaRoute, '/owner/edit');
    });

    test('incluye alertas de horarios y catálogo faltante', () {
      final alerts = buildOwnerDashboardAlerts(
        merchant: buildMerchant(hasProducts: false, hasSchedules: false),
        ownerPending: false,
        signal: null,
      );

      expect(alerts.any((item) => item.id == 'missing_schedules'), isTrue);
      expect(alerts.any((item) => item.id == 'missing_products'), isTrue);
    });
  });
}
