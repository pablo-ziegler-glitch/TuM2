import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/open_now_models.dart';

abstract interface class OpenNowDataSource {
  Future<List<OpenNowZone>> fetchZones();

  Future<List<OpenNowMerchant>> fetchOpenNow({
    required String zoneId,
    int limit,
  });

  Future<List<OpenNowMerchant>> fetchFallback({
    required String zoneId,
    int limit,
  });
}

class OpenNowRepository implements OpenNowDataSource {
  static const List<String> _zoneCollectionCandidates = <String>[
    'zones',
    'zonas',
    'ZONAS',
  ];
  static const Set<String> _inactiveZoneStatuses = <String>{
    'draft',
    'internal_test',
    'paused',
    'borrador',
    'pausado',
    'pausada',
  };

  OpenNowRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const Duration _queryTimeout = Duration(seconds: 6);
  static const int _openNowLimit = 200;
  static const int _fallbackLimit = 40;

  @override
  Future<List<OpenNowZone>> fetchZones() async {
    final docs = await _fetchActiveZoneDocs();
    return docs.map(OpenNowZone.fromFirestore).toList(growable: false);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchActiveZoneDocs() async {
    for (final collectionName in _zoneCollectionCandidates) {
      final snapshot = await _firestore
          .collection(collectionName)
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

  @override
  Future<List<OpenNowMerchant>> fetchOpenNow({
    required String zoneId,
    int limit = _openNowLimit,
  }) async {
    if (zoneId.trim().isEmpty) return const [];
    final snapshot = await _firestore
        .collection('merchant_public')
        .where('zoneId', isEqualTo: zoneId)
        .where('visibilityStatus', isEqualTo: 'visible')
        .where('isOpenNow', isEqualTo: true)
        .limit(limit)
        .get()
        .timeout(_queryTimeout);

    return snapshot.docs
        .map(OpenNowMerchant.fromFirestore)
        .toList(growable: false);
  }

  @override
  Future<List<OpenNowMerchant>> fetchFallback({
    required String zoneId,
    int limit = _fallbackLimit,
  }) async {
    if (zoneId.trim().isEmpty) return const [];
    final snapshot = await _firestore
        .collection('merchant_public')
        .where('zoneId', isEqualTo: zoneId)
        .where('visibilityStatus', isEqualTo: 'visible')
        .where('isOpenNow', isEqualTo: false)
        .limit(limit)
        .get()
        .timeout(_queryTimeout);

    final items =
        snapshot.docs.map(OpenNowMerchant.fromFirestore).where((merchant) {
      final label = merchant.effectiveScheduleLabel.trim();
      return label.isNotEmpty;
    });

    return items.toList(growable: false);
  }
}
