import 'package:cloud_firestore/cloud_firestore.dart';

class StoreModel {
  final String id;
  final String ownerId;
  final String name;
  final String slug;
  final String category;
  final String description;
  final String imageUrl;
  final String address;
  final GeoPoint geo;
  final String geohash;
  final String neighborhood;
  final String locality;
  final String visibilityStatus; // 'draft' | 'active' | 'suspended'
  // Derived fields
  final bool isOpenNow;
  final bool isLateNightNow;
  final bool isOnDutyToday;
  final bool hasActiveSpecialSignal;
  final int operationalFreshnessHours;
  final int operationalDataCompletenessScore;
  final List<String> activeBadgeKeys;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StoreModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.address,
    required this.geo,
    required this.geohash,
    required this.neighborhood,
    required this.locality,
    required this.visibilityStatus,
    this.isOpenNow = false,
    this.isLateNightNow = false,
    this.isOnDutyToday = false,
    this.hasActiveSpecialSignal = false,
    this.operationalFreshnessHours = 9999,
    this.operationalDataCompletenessScore = 0,
    this.activeBadgeKeys = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => visibilityStatus == 'active';
  bool get isDraft => visibilityStatus == 'draft';

  factory StoreModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final geoData = data['geo'] as Map<String, dynamic>?;

    return StoreModel(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      slug: data['slug'] as String? ?? '',
      category: data['category'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      address: data['address'] as String? ?? '',
      geo: geoData != null
          ? GeoPoint(
              (geoData['lat'] as num).toDouble(),
              (geoData['lng'] as num).toDouble(),
            )
          : const GeoPoint(0, 0),
      geohash: data['geohash'] as String? ?? '',
      neighborhood: data['neighborhood'] as String? ?? '',
      locality: data['locality'] as String? ?? '',
      visibilityStatus: data['visibilityStatus'] as String? ?? 'draft',
      isOpenNow: data['isOpenNow'] as bool? ?? false,
      isLateNightNow: data['isLateNightNow'] as bool? ?? false,
      isOnDutyToday: data['isOnDutyToday'] as bool? ?? false,
      hasActiveSpecialSignal: data['hasActiveSpecialSignal'] as bool? ?? false,
      operationalFreshnessHours:
          data['operationalFreshnessHours'] as int? ?? 9999,
      operationalDataCompletenessScore:
          data['operationalDataCompletenessScore'] as int? ?? 0,
      activeBadgeKeys: (data['activeBadgeKeys'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerId': ownerId,
        'name': name,
        'slug': slug,
        'category': category,
        'description': description,
        'imageUrl': imageUrl,
        'address': address,
        'geo': {'lat': geo.latitude, 'lng': geo.longitude},
        'geohash': geohash,
        'neighborhood': neighborhood,
        'locality': locality,
        'visibilityStatus': visibilityStatus,
        'isOpenNow': isOpenNow,
        'isLateNightNow': isLateNightNow,
        'isOnDutyToday': isOnDutyToday,
        'hasActiveSpecialSignal': hasActiveSpecialSignal,
        'operationalFreshnessHours': operationalFreshnessHours,
        'operationalDataCompletenessScore': operationalDataCompletenessScore,
        'activeBadgeKeys': activeBadgeKeys,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  StoreModel copyWith({
    String? name,
    String? category,
    String? description,
    String? imageUrl,
    String? address,
    GeoPoint? geo,
    String? geohash,
    String? neighborhood,
    String? locality,
    String? visibilityStatus,
  }) =>
      StoreModel(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        slug: slug,
        category: category ?? this.category,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        address: address ?? this.address,
        geo: geo ?? this.geo,
        geohash: geohash ?? this.geohash,
        neighborhood: neighborhood ?? this.neighborhood,
        locality: locality ?? this.locality,
        visibilityStatus: visibilityStatus ?? this.visibilityStatus,
        isOpenNow: isOpenNow,
        isLateNightNow: isLateNightNow,
        isOnDutyToday: isOnDutyToday,
        hasActiveSpecialSignal: hasActiveSpecialSignal,
        operationalFreshnessHours: operationalFreshnessHours,
        operationalDataCompletenessScore: operationalDataCompletenessScore,
        activeBadgeKeys: activeBadgeKeys,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
