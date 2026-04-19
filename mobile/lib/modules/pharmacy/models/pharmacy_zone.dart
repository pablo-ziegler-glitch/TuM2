import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de zona geográfica para el selector manual.
/// Mapeado desde la colección zones/{zoneId}.
class PharmacyZone {
  /// ID del documento en Firestore.
  final String zoneId;

  /// Nombre del barrio/zona para mostrar en UI.
  final String name;

  /// Ciudad padre (ej: "Buenos Aires").
  final String cityId;

  /// Latitud del centroide de la zona.
  final double? centroidLat;

  /// Longitud del centroide de la zona.
  final double? centroidLng;

  const PharmacyZone({
    required this.zoneId,
    required this.name,
    required this.cityId,
    this.centroidLat,
    this.centroidLng,
  });

  factory PharmacyZone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PharmacyZone.fromMap(doc.id, data);
  }

  factory PharmacyZone.fromMap(
    String zoneId,
    Map<String, dynamic> data,
  ) {
    final centroid = _readMap(data, const ['centroid', 'centroide']);
    return PharmacyZone(
      zoneId: zoneId,
      name: _readText(data, const ['name', 'nombre']) ?? zoneId,
      cityId: _readText(data, const ['cityId', 'ciudadId', 'city_id']) ?? '',
      centroidLat: _readNum(centroid, const ['lat']) ??
          _readNum(data, const ['lat', 'latitude']),
      centroidLng: _readNum(centroid, const ['lng']) ??
          _readNum(data, const ['lng', 'longitude']),
    );
  }

  static String? _readText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static Map<String, dynamic>? _readMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static double? _readNum(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }
}
