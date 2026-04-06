import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_detail/domain/merchant_maps.dart';

void main() {
  group('buildMerchantMapsIntent', () {
    test('usa coordenadas cuando estan disponibles', () {
      final intent = buildMerchantMapsIntent(
        address: 'Av. Corrientes 1234',
        lat: -34.6037,
        lng: -58.3816,
      );

      expect(intent.usedCoordinates, isTrue);
      expect(intent.uri.toString(), contains('-34.603700%2C-58.381600'));
    });

    test('usa direccion textual cuando faltan coordenadas', () {
      final intent = buildMerchantMapsIntent(
        address: 'Av. Corrientes 1234',
      );

      expect(intent.usedCoordinates, isFalse);
      expect(
        intent.uri.toString(),
        contains('Av.%20Corrientes%201234'),
      );
    });
  });
}
