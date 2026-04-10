import 'package:cloud_firestore/cloud_firestore.dart';

class SearchZoneItem {
  const SearchZoneItem({
    required this.zoneId,
    required this.name,
    required this.cityId,
    this.centroidLat,
    this.centroidLng,
  });

  final String zoneId;
  final String name;
  final String cityId;
  final double? centroidLat;
  final double? centroidLng;

  factory SearchZoneItem.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SearchZoneItem.fromMap(doc.id, doc.data());
  }

  factory SearchZoneItem.fromMap(
    String zoneId,
    Map<String, dynamic> data,
  ) {
    final centroid = readMap(data, const ['centroid', 'centroide']);
    return SearchZoneItem(
      zoneId: zoneId,
      name: readText(data, const ['name', 'nombre']) ?? zoneId,
      cityId: readText(data, const ['cityId', 'ciudadId', 'city_id']) ?? '',
      centroidLat: readNum(centroid, const ['lat']) ??
          readNum(data, const ['lat', 'latitude']),
      centroidLng: readNum(centroid, const ['lng']) ??
          readNum(data, const ['lng', 'longitude']),
    );
  }

  static String? readText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static Map<String, dynamic>? readMap(
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

  static double? readNum(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }
}
