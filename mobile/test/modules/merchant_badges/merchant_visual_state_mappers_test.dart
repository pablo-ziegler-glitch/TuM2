import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/home/models/open_now_models.dart';
import 'package:tum2/modules/merchant_badges/domain/merchant_badge_resolver.dart';
import 'package:tum2/modules/merchant_badges/domain/merchant_visual_models.dart';
import 'package:tum2/modules/merchant_badges/domain/merchant_visual_state_mappers.dart';
import 'package:tum2/modules/pharmacy/models/pharmacy_duty_item.dart';

void main() {
  test('mapper open_now respeta guardia y prioridad sobre abierto', () {
    final merchant = OpenNowMerchant(
      merchantId: 'm1',
      name: 'Farmacia Centro',
      categoryId: 'pharmacy',
      categoryName: 'Farmacia',
      zoneId: 'z1',
      addressShort: 'Av Siempreviva 123',
      verificationStatus: 'verified',
      visibilityStatus: 'visible',
      isOpenNow: true,
      isOnDutyToday: true,
      is24h: true,
      openStatusLabel: 'Abierto',
      todayScheduleLabel: '24 hs',
      lastDataRefreshAt: DateTime.now(),
      sortBoost: 1,
      lat: null,
      lng: null,
    );

    final state = MerchantVisualStateMappers.fromOpenNowMerchant(merchant);
    final resolution = MerchantBadgeResolver.resolve(
      state: state,
      surface: MerchantSurface.compactCard,
    );

    expect(resolution.primary, MerchantBadgeKey.onDuty);
  });

  test('mapper farmacia pública produce badge de turno', () {
    const item = PharmacyDutyItem(
      dutyId: 'd1',
      merchantId: 'm1',
      merchantName: 'Farmacia Test',
      addressLine: 'Dir',
      zoneId: 'z1',
      dutyDate: '2026-04-19',
      isOnDuty: true,
      isOpenNow: true,
      is24Hours: false,
      verificationStatus: 'validated',
      sortBoost: 1,
    );

    final state = MerchantVisualStateMappers.fromPharmacyDutyItem(item);
    final resolution = MerchantBadgeResolver.resolve(
      state: state,
      surface: MerchantSurface.pharmacyPublic,
    );

    expect(resolution.primary, MerchantBadgeKey.onDuty);
  });
}
