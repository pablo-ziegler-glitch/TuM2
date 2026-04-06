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
    final centroid = data['centroid'] as Map<String, dynamic>?;
    return SearchZoneItem(
      zoneId: doc.id,
      name: (data['name'] as String?) ?? doc.id,
      cityId: (data['cityId'] as String?) ?? '',
      centroidLat: (centroid?['lat'] as num?)?.toDouble(),
      centroidLng: (centroid?['lng'] as num?)?.toDouble(),
    );
  }
}

class ZoneSearchRepository implements ZoneSearchDataSource {
  ZoneSearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const Duration _queryTimeout = Duration(seconds: 6);

  @override
  Future<List<SearchZoneItem>> fetchAvailableZones() async {
    final snap = await _firestore
        .collection('zones')
        .where('status', whereIn: ['pilot_enabled', 'public_enabled'])
        .orderBy('priorityLevel')
        .get()
        .timeout(_queryTimeout);

    return snap.docs.map(SearchZoneItem.fromFirestore).toList();
  }
}
