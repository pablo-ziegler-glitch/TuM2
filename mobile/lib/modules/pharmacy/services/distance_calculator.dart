import 'dart:math';

import 'package:intl/intl.dart';

/// Calcula distancias entre dos puntos geográficos usando la fórmula de Haversine.
class DistanceCalculator {
  static const double _earthRadiusMeters = 6371000.0;

  DistanceCalculator._();

  /// Retorna la distancia en metros entre dos coordenadas geográficas.
  ///
  /// Precisión suficiente para distancias cortas (< 50 km).
  /// Caso de prueba conocido: Buenos Aires (−34.6037, −58.3816) →
  /// Córdoba (−31.4201, −64.1888) ≈ 700 km.
  static double haversine({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _toRad(double deg) => deg * pi / 180.0;

  /// Formatea una distancia en metros a texto legible en español.
  ///
  /// - Menor a 1000 m → "450 m"
  /// - Mayor o igual a 1000 m → "1.2 km"
  static String formatDistance(int meters) {
    if (meters < 1000) return '$meters m';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }
}

/// Retorna la fecha actual en timezone Argentina (UTC-3) como "YYYY-MM-DD".
///
/// Usar siempre esta función para calcular la fecha del turno, nunca
/// [DateTime.now()] directo, para evitar el off-by-one a medianoche en UTC.
String todayArgentina() {
  final now = DateTime.now().toUtc().subtract(const Duration(hours: 3));
  return DateFormat('yyyy-MM-dd').format(now);
}

/// Formatea la fecha Argentina actual con lenguaje natural en español.
/// Ej: "MIÉRCOLES 26 DE MARZO"
String todayArgentinaLabel() {
  final now = DateTime.now().toUtc().subtract(const Duration(hours: 3));
  final formatted = DateFormat('EEEE d \'de\' MMMM', 'es').format(now);
  return formatted.toUpperCase();
}
