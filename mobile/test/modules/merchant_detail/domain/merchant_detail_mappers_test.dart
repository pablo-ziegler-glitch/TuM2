import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_detail/data/mappers/merchant_detail_mappers.dart';
import 'package:tum2/modules/merchant_detail/domain/merchant_detail_view_data.dart';

import '../test_fakes.dart';

void main() {
  group('merchant detail mappers', () {
    test('mapStatusBadge prioriza Farmacia de turno', () {
      final merchant = mapCoreDtoToViewData(
        buildCoreDto(
          hasPharmacyDutyToday: true,
          isOpenNow: false,
        ),
      );

      final badge = mapStatusBadge(merchant);
      expect(badge.type, MerchantStatusBadgeType.duty);
      expect(badge.label, 'Farmacia de turno');
    });

    test('mapStatusBadge abierto/cerrado/referencial', () {
      final open = mapStatusBadge(
        mapCoreDtoToViewData(buildCoreDto(isOpenNow: true)),
      );
      final closed = mapStatusBadge(
        mapCoreDtoToViewData(buildCoreDto(isOpenNow: false)),
      );
      final referential = mapStatusBadge(
        mapCoreDtoToViewData(buildCoreDto(isOpenNow: null)),
      );

      expect(open.type, MerchantStatusBadgeType.open);
      expect(closed.type, MerchantStatusBadgeType.closed);
      expect(referential.type, MerchantStatusBadgeType.referential);
    });

    test('mapDutyDtoToViewData soporta endsAt faltante', () {
      final duty = mapDutyDtoToViewData(buildDutyDto());
      expect(duty.endsAt, isNull);
    });
  });
}
