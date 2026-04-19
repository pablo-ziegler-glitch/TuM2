import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_badges/domain/merchant_badge_resolver.dart';
import 'package:tum2/modules/merchant_badges/domain/merchant_visual_models.dart';

MerchantVisualState _state({
  MerchantVisibilityState visibility = MerchantVisibilityState.visible,
  MerchantLifecycleState lifecycle = MerchantLifecycleState.active,
  MerchantConfidenceState confidence = MerchantConfidenceState.verified,
  MerchantOpeningState opening = MerchantOpeningState.openNow,
  MerchantPharmacyGuardState guard = MerchantPharmacyGuardState.none,
  MerchantOperationalSignalState signal = MerchantOperationalSignalState.none,
  bool show24h = false,
  bool cooldown = false,
  bool hasScheduleInfo = true,
  MerchantClaimWorkflowState? claim,
}) {
  return MerchantVisualState(
    visibility: visibility,
    lifecycle: lifecycle,
    confidence: confidence,
    opening: opening,
    guardState: guard,
    operationalSignal: signal,
    show24hBadge: show24h,
    twentyFourHourCooldownActive: cooldown,
    categoryLabel: 'Farmacia',
    claimState: claim,
    hasSufficientScheduleInfo: hasScheduleInfo,
    manualOverrideMode: 'none',
    informational: false,
  );
}

void main() {
  group('MerchantBadgeResolver (precedencia e incompatibilidades)', () {
    test('vacation pisa abierto ahora', () {
      final result = MerchantBadgeResolver.resolve(
        state: _state(
          opening: MerchantOpeningState.openNow,
          signal: MerchantOperationalSignalState.vacation,
        ),
        surface: MerchantSurface.searchCard,
      );
      expect(result.primary, MerchantBadgeKey.closedForVacation);
    });

    test('temporary_closure pisa abierto ahora', () {
      final result = MerchantBadgeResolver.resolve(
        state: _state(
          opening: MerchantOpeningState.openNow,
          signal: MerchantOperationalSignalState.temporaryClosure,
        ),
        surface: MerchantSurface.searchCard,
      );
      expect(result.primary, MerchantBadgeKey.temporaryClosure);
    });

    test('Abierto ahora pisa delay', () {
      final result = MerchantBadgeResolver.resolve(
        state: _state(
          opening: MerchantOpeningState.openNow,
          signal: MerchantOperationalSignalState.opensLater,
        ),
        surface: MerchantSurface.searchCard,
      );
      expect(result.primary, MerchantBadgeKey.openNow);
    });

    test('Farmacia de turno pisa delay y Abierto ahora', () {
      final result = MerchantBadgeResolver.resolve(
        state: _state(
          opening: MerchantOpeningState.openNow,
          signal: MerchantOperationalSignalState.opensLater,
          guard: MerchantPharmacyGuardState.onDuty,
        ),
        surface: MerchantSurface.searchCard,
      );
      expect(result.primary, MerchantBadgeKey.onDuty);
    });

    test('guardia en verificación reemplaza De turno', () {
      final result = MerchantBadgeResolver.resolve(
        state: _state(guard: MerchantPharmacyGuardState.guardVerification),
        surface: MerchantSurface.searchCard,
      );
      expect(result.primary, MerchantBadgeKey.guardVerification);
    });

    test('listados muestran solo badge principal', () {
      final result = MerchantBadgeResolver.resolve(
        state: _state(show24h: true),
        surface: MerchantSurface.searchCard,
      );
      expect(result.secondary, isEmpty);
    });

    test('detalle limita secundarios a 2', () {
      final result = MerchantBadgeResolver.resolve(
        state:
            _state(show24h: true, confidence: MerchantConfidenceState.verified),
        surface: MerchantSurface.detail,
      );
      expect(result.secondary.length, lessThanOrEqualTo(2));
      expect(result.secondary, contains(MerchantBadgeKey.alwaysOpen24h));
      expect(result.secondary, contains(MerchantBadgeKey.confidenceVerified));
    });

    test('ficha compacta limita secundarios a 1', () {
      final result = MerchantBadgeResolver.resolve(
        state:
            _state(show24h: true, confidence: MerchantConfidenceState.verified),
        surface: MerchantSurface.compactCard,
      );
      expect(result.secondary.length, 1);
    });

    test('24 hs solo secundario en detalle', () {
      final result = MerchantBadgeResolver.resolve(
        state: _state(show24h: true, opening: MerchantOpeningState.openNow),
        surface: MerchantSurface.detail,
      );
      expect(result.primary, isNot(MerchantBadgeKey.alwaysOpen24h));
      expect(result.secondary, contains(MerchantBadgeKey.alwaysOpen24h));
    });

    test('si esta cerrado no muestra 24 hs', () {
      final result = MerchantBadgeResolver.resolve(
        state: _state(show24h: true, opening: MerchantOpeningState.closed),
        surface: MerchantSurface.detail,
      );
      expect(result.primary, MerchantBadgeKey.closed);
      expect(result.secondary, isNot(contains(MerchantBadgeKey.alwaysOpen24h)));
    });

    test('cooldown de 24 hs elimina badge sin pasar a referencial', () {
      final result = MerchantBadgeResolver.resolve(
        state: _state(
            show24h: true,
            cooldown: true,
            opening: MerchantOpeningState.openNow),
        surface: MerchantSurface.detail,
      );
      expect(result.primary, MerchantBadgeKey.openNow);
      expect(result.secondary, isNot(contains(MerchantBadgeKey.alwaysOpen24h)));
      expect(result.primary, isNot(MerchantBadgeKey.referentialSchedule));
    });

    test('hidden/suppressed no exponen estado público', () {
      final hidden = MerchantBadgeResolver.resolve(
        state: _state(visibility: MerchantVisibilityState.hidden),
        surface: MerchantSurface.searchCard,
      );
      final suppressed = MerchantBadgeResolver.resolve(
        state: _state(visibility: MerchantVisibilityState.suppressed),
        surface: MerchantSurface.detail,
      );
      expect(hidden.primary, isNull);
      expect(suppressed.primary, isNull);
    });

    test('claim status no se publica en surface pública', () {
      final result = MerchantBadgeResolver.resolve(
        state: _state(claim: MerchantClaimWorkflowState.underReview),
        surface: MerchantSurface.searchCard,
      );
      expect(result.primary, isNot(MerchantBadgeKey.claimUnderReview));
    });
  });
}
