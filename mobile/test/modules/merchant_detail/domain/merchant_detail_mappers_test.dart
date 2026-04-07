import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_detail/data/mappers/merchant_detail_mappers.dart';
import 'package:tum2/modules/merchant_detail/domain/merchant_detail_view_data.dart';

void main() {
  group('mapOperationalBadge', () {
    test('prioriza Farmacia de turno por encima de isOpenNow', () {
      final badge = mapOperationalBadge(
        isOnDutyToday: true,
        isOpenNow: false,
      );

      expect(badge.type, MerchantOperationalBadgeType.onDuty);
      expect(badge.label, 'Farmacia de turno');
    });

    test('mapea Abierto ahora cuando isOpenNow es true', () {
      final badge = mapOperationalBadge(
        isOnDutyToday: false,
        isOpenNow: true,
      );

      expect(badge.type, MerchantOperationalBadgeType.openNow);
      expect(badge.label, 'Abierto ahora');
    });

    test('mapea Cerrado cuando isOpenNow es false', () {
      final badge = mapOperationalBadge(
        isOnDutyToday: false,
        isOpenNow: false,
      );

      expect(badge.type, MerchantOperationalBadgeType.closed);
      expect(badge.label, 'Cerrado');
    });

    test('mapea Horario referencial cuando isOpenNow es null', () {
      final badge = mapOperationalBadge(
        isOnDutyToday: false,
        isOpenNow: null,
      );

      expect(badge.type, MerchantOperationalBadgeType.referential);
      expect(badge.label, 'Horario referencial');
    });
  });

  group('mapTrustBadgeFromVerificationStatus', () {
    test('verified -> Verificado', () {
      final badge = mapTrustBadgeFromVerificationStatus('verified');
      expect(badge?.label, 'Verificado');
    });

    test('validated -> Reclamado', () {
      final badge = mapTrustBadgeFromVerificationStatus('validated');
      expect(badge?.label, 'Reclamado');
    });

    test('claimed -> Reclamado', () {
      final badge = mapTrustBadgeFromVerificationStatus('claimed');
      expect(badge?.label, 'Reclamado');
    });

    test('referential -> Dato referencial', () {
      final badge = mapTrustBadgeFromVerificationStatus('referential');
      expect(badge?.label, 'Dato referencial');
    });

    test('community_submitted -> Información de la comunidad', () {
      final badge = mapTrustBadgeFromVerificationStatus(
        'community_submitted',
      );
      expect(badge?.label, 'Información de la comunidad');
    });

    test('unverified -> null', () {
      final badge = mapTrustBadgeFromVerificationStatus('unverified');
      expect(badge, isNull);
    });
  });
}
