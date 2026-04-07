import 'package:flutter_test/flutter_test.dart';

import 'package:tum2/modules/home/models/open_now_models.dart';

void main() {
  group('OpenNowMerchant health duty detection', () {
    test('marca especial cuando es salud y esta de turno', () {
      final pharmacy = _merchant(
        categoryId: 'pharmacy',
        categoryName: 'Farmacia',
        isOnDutyToday: true,
      );
      final clinic = _merchant(
        categoryId: 'servicios',
        categoryName: 'Clinica medica',
        isOnDutyToday: true,
      );
      final vet = _merchant(
        categoryId: 'veterinaria',
        categoryName: 'Veterinaria',
        isOnDutyToday: true,
      );

      expect(pharmacy.isSpecialOnDutyHealth, isTrue);
      expect(clinic.isSpecialOnDutyHealth, isTrue);
      expect(vet.isSpecialOnDutyHealth, isTrue);
    });

    test('no marca especial si no es salud o no esta de turno', () {
      final groceryOnDuty = _merchant(
        categoryId: 'grocery',
        categoryName: 'Almacen',
        isOnDutyToday: true,
      );
      final pharmacyNoDuty = _merchant(
        categoryId: 'pharmacy',
        categoryName: 'Farmacia',
        isOnDutyToday: false,
      );

      expect(groceryOnDuty.isSpecialOnDutyHealth, isFalse);
      expect(pharmacyNoDuty.isSpecialOnDutyHealth, isFalse);
    });
  });
}

OpenNowMerchant _merchant({
  required String categoryId,
  required String categoryName,
  required bool isOnDutyToday,
}) {
  return OpenNowMerchant(
    merchantId: 'merchant',
    name: 'Demo',
    categoryId: categoryId,
    categoryName: categoryName,
    zoneId: 'zone',
    addressShort: 'Address',
    verificationStatus: 'verified',
    visibilityStatus: 'visible',
    isOpenNow: true,
    openStatusLabel: 'Abierto',
    todayScheduleLabel: 'Hoy hasta las 20:00',
    lastDataRefreshAt: DateTime.now(),
    sortBoost: 10,
    lat: null,
    lng: null,
    isOnDutyToday: isOnDutyToday,
  );
}
