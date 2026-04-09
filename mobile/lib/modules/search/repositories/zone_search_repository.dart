import 'package:cloud_firestore/cloud_firestore.dart';

export '../models/search_zone_item.dart';
import '../models/search_zone_item.dart';

abstract interface class ZoneSearchDataSource {
  Future<List<SearchZoneItem>> fetchAvailableZones();
}

class ZoneSearchRepository implements ZoneSearchDataSource {
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

  ZoneSearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const Duration _queryTimeout = Duration(seconds: 6);
  static const int _maxZonesPerQuery = 300;

  @override
  Future<List<SearchZoneItem>> fetchAvailableZones() async {
    final docs = await _fetchActiveZoneDocs();
    return docs.map(SearchZoneItem.fromFirestore).toList(growable: false);
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
    final data = doc.data();
    final status = SearchZoneItem.readText(
      data,
      const ['status', 'estado'],
    )?.toLowerCase();
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
    final nameCompare = (SearchZoneItem.readText(
              a.data(),
              const ['name', 'nombre'],
            ) ??
            a.id)
        .toLowerCase()
        .compareTo(
          (SearchZoneItem.readText(
                    b.data(),
                    const ['name', 'nombre'],
                  ) ??
                  b.id)
              .toLowerCase(),
        );
    if (nameCompare != 0) return nameCompare;
    return a.id.compareTo(b.id);
  }

  static int _zonePriority(Map<String, dynamic> data) {
    final rawPriority =
        data['priorityLevel'] ?? data['priority'] ?? data['prioridad'];
    return rawPriority is num ? rawPriority.toInt() : 1 << 30;
  }
}
