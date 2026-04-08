import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pharmacy_zone.dart';

abstract interface class ZonesSource {
  Future<List<PharmacyZone>> getActiveZones();
}

/// Repositorio de zonas geográficas para el selector manual.
///
/// Solo retorna zonas activas (pilot_enabled o public_enabled).
class ZonesRepository implements ZonesSource {
  final FirebaseFirestore _firestore;

  static const Duration _queryTimeout = Duration(seconds: 5);

  ZonesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Retorna todas las zonas con status 'pilot_enabled' o 'public_enabled',
  /// ordenadas por [priorityLevel] ascendente.
  @override
  Future<List<PharmacyZone>> getActiveZones() async {
    final snap = await _firestore
        .collection('zones')
        .where('status', whereIn: ['pilot_enabled', 'public_enabled'])
        .orderBy('priorityLevel')
        .get()
        .timeout(_queryTimeout);

    return snap.docs.map(PharmacyZone.fromFirestore).toList();
  }
}
