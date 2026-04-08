import 'package:cloud_firestore/cloud_firestore.dart';

abstract interface class ZoneSearchDataSource {
  Future<List<SearchZoneItem>> fetchAvailableZones();
}

class SearchZoneItem {
  final String zoneId;
  final String name;
  final String cityId;
  final double? centroidLat;
  final double? centroidLng;

  const SearchZoneItem({
    required this.zoneId,
    required this.name,
    required this.cityId,
    this.centroidLat,
    this.centroidLng,
  });

  factory SearchZoneItem.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final centroid = _readMap(data, const ['centroid', 'centroide']);
    return SearchZoneItem(
      zoneId: doc.id,
      name: _readText(data, const ['name', 'nombre']) ?? doc.id,
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

class ZoneSearchRepository implements ZoneSearchDataSource {
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

  ZoneSearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const Duration _queryTimeout = Duration(seconds: 6);

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
    final status = SearchZoneItem._readText(
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
    final nameCompare = (SearchZoneItem._readText(
              a.data(),
              const ['name', 'nombre'],
            ) ??
            a.id)
        .toLowerCase()
        .compareTo(
          (SearchZoneItem._readText(
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
