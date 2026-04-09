import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pharmacy_zone.dart';

abstract interface class ZonesSource {
  Future<List<PharmacyZone>> getActiveZones();
}

/// Repositorio de zonas geográficas para el selector manual.
///
/// Solo retorna zonas activas (pilot_enabled o public_enabled).
class ZonesRepository implements ZonesSource {
  static const List<String> _zoneCollectionCandidates = <String>[
    'zones',
  ];
  static const Set<String> _inactiveZoneStatuses = <String>{
    'draft',
    'internal_test',
    'paused',
    'borrador',
    'pausado',
    'pausada',
  };

  final FirebaseFirestore _firestore;

  static const Duration _queryTimeout = Duration(seconds: 5);
  static const int _maxZonesPerQuery = 300;

  ZonesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Retorna todas las zonas con status 'pilot_enabled' o 'public_enabled',
  /// ordenadas por [priorityLevel] ascendente.
  @override
  Future<List<PharmacyZone>> getActiveZones() async {
    final docs = await _fetchActiveZoneDocs();
    return docs.map(PharmacyZone.fromFirestore).toList(growable: false);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchActiveZoneDocs() async {
    for (final collectionName in _zoneCollectionCandidates) {
      final snapshot = await _firestore
          .collection(collectionName)
          .limit(_maxZonesPerQuery)
          .get()
          .timeout(_queryTimeout);
      final docs = snapshot.docs.where(_isActiveZoneDoc).toList();
      if (docs.isEmpty) continue;
      docs.sort(_compareZoneDocs);
      return docs;
    }
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }

  static bool _isActiveZoneDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final status =
        _readText(doc.data(), const ['status', 'estado'])?.toLowerCase();
    if (status == null || status.isEmpty) return true;
    return !_inactiveZoneStatuses.contains(status);
  }

  static int _compareZoneDocs(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final priorityCompare =
        _zonePriority(a.data()).compareTo(_zonePriority(b.data()));
    if (priorityCompare != 0) return priorityCompare;
    final nameCompare = (_readText(a.data(), const ['name', 'nombre']) ?? a.id)
        .toLowerCase()
        .compareTo(
          (_readText(b.data(), const ['name', 'nombre']) ?? b.id).toLowerCase(),
        );
    if (nameCompare != 0) return nameCompare;
    return a.id.compareTo(b.id);
  }

  static int _zonePriority(Map<String, dynamic> data) {
    final rawPriority =
        data['priorityLevel'] ?? data['priority'] ?? data['prioridad'];
    return rawPriority is num ? rawPriority.toInt() : 1 << 30;
  }

  static String? _readText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
