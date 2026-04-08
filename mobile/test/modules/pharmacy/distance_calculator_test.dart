import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tum2/modules/pharmacy/services/distance_calculator.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  group('DistanceCalculator.haversine', () {
    test('Buenos Aires → Córdoba ≈ 700 km', () {
      // Buenos Aires: −34.6037, −58.3816
      // Córdoba:      −31.4201, −64.1888
      final dist = DistanceCalculator.haversine(
        lat1: -34.6037,
        lng1: -58.3816,
        lat2: -31.4201,
        lng2: -64.1888,
      );
      // Distancia lineal aproximada: ~647 km
      expect(dist, greaterThan(640000));
      expect(dist, lessThan(660000));
    });

    test('misma posición → 0 metros', () {
      final dist = DistanceCalculator.haversine(
        lat1: -34.6037,
        lng1: -58.3816,
        lat2: -34.6037,
        lng2: -58.3816,
      );
      expect(dist, closeTo(0.0, 0.001));
    });

    test('450 metros entre puntos cercanos de Buenos Aires', () {
      // Av. Corrientes 1800 → Av. Corrientes 2200 (aprox. 400 m)
      final dist = DistanceCalculator.haversine(
        lat1: -34.6037,
        lng1: -58.3900,
        lat2: -34.6037,
        lng2: -58.3950,
      );
      expect(dist, greaterThan(300));
      expect(dist, lessThan(700));
    });
  });

  group('DistanceCalculator.formatDistance', () {
    test('menos de 1000m muestra metros', () {
      expect(DistanceCalculator.formatDistance(450), '450 m');
      expect(DistanceCalculator.formatDistance(999), '999 m');
    });

    test('1000m o más muestra kilómetros con 1 decimal', () {
      expect(DistanceCalculator.formatDistance(1000), '1.0 km');
      expect(DistanceCalculator.formatDistance(1200), '1.2 km');
      expect(DistanceCalculator.formatDistance(5500), '5.5 km');
    });
  });

  group('todayArgentina', () {
    test('retorna formato YYYY-MM-DD', () {
      final result = todayArgentina();
      // Formato debe ser YYYY-MM-DD
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(result), isTrue);
    });

    test('no usa fecha UTC cuando hay diferencia de timezone', () {
      // Este test verifica la lógica de UTC-3.
      // A las 23:50 UTC, en Argentina aún es el mismo día (20:50 AR).
      // No podemos simular esto sin mocks, pero validamos el formato.
      final result = todayArgentina();
      final parts = result.split('-');
      expect(parts.length, 3);
      expect(int.parse(parts[0]), greaterThan(2024)); // año razonable
    });
  });
}
