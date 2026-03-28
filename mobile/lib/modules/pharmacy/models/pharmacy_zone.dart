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
    final centroid = data['centroid'] as Map<String, dynamic>?;
    return PharmacyZone(
      zoneId: doc.id,
      name: data['name'] as String? ?? doc.id,
      cityId: data['cityId'] as String? ?? '',
      centroidLat: (centroid?['lat'] as num?)?.toDouble(),
      centroidLng: (centroid?['lng'] as num?)?.toDouble(),
    );
  }
}
