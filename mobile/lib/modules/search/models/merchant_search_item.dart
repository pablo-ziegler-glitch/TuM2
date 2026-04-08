import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantSearchItem {
  final String merchantId;
  final String name;
  final String categoryId;
  final String categoryLabel;
  final String zoneId;
  final String address;
  final double? lat;
  final double? lng;
  final String verificationStatus;
  final String visibilityStatus;
  final bool? isOpenNow;
  final bool? isOnDutyToday;
  final bool? is24h;
  final String openStatusLabel;
  final double sortBoost;
  final List<String> searchKeywords;
  final double? distanceMeters;

  const MerchantSearchItem({
    required this.merchantId,
    required this.name,
    required this.categoryId,
    required this.categoryLabel,
    required this.zoneId,
    required this.address,
    required this.lat,
    required this.lng,
    required this.verificationStatus,
    required this.visibilityStatus,
    required this.isOpenNow,
    this.isOnDutyToday,
    this.is24h,
    required this.openStatusLabel,
    required this.sortBoost,
    required this.searchKeywords,
    this.distanceMeters,
  });

  MerchantSearchItem copyWith({
    double? distanceMeters,
    bool? isOnDutyToday,
    bool? is24h,
  }) {
    return MerchantSearchItem(
      merchantId: merchantId,
      name: name,
      categoryId: categoryId,
      categoryLabel: categoryLabel,
      zoneId: zoneId,
      address: address,
      lat: lat,
      lng: lng,
      verificationStatus: verificationStatus,
      visibilityStatus: visibilityStatus,
      isOpenNow: isOpenNow,
      isOnDutyToday: isOnDutyToday ?? this.isOnDutyToday,
      is24h: is24h ?? this.is24h,
      openStatusLabel: openStatusLabel,
      sortBoost: sortBoost,
      searchKeywords: searchKeywords,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  factory MerchantSearchItem.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawKeywords = (data['searchKeywords'] as List<dynamic>? ?? const []);
    return MerchantSearchItem(
      merchantId: (data['merchantId'] as String?) ?? doc.id,
      name: (data['name'] as String?) ?? '',
      categoryId: (data['categoryId'] as String?) ??
          (data['category'] as String?) ??
          '',
      categoryLabel: (data['categoryLabel'] as String?) ??
          (data['category'] as String?) ??
          '',
      zoneId: (data['zoneId'] as String?) ?? (data['zone'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      verificationStatus:
          (data['verificationStatus'] as String?) ?? 'unverified',
      visibilityStatus: (data['visibilityStatus'] as String?) ?? 'visible',
      isOpenNow: data['isOpenNow'] as bool?,
      isOnDutyToday: (data['isOnDutyToday'] as bool?) ??
          (data['hasPharmacyDutyToday'] as bool?),
      is24h: data['is24h'] as bool?,
      openStatusLabel: (data['openStatusLabel'] as String?) ??
          (data['todayScheduleLabel'] as String?) ??
          '',
      sortBoost: (data['sortBoost'] as num?)?.toDouble() ?? 0,
      searchKeywords: rawKeywords.map((e) => e.toString()).toList(),
    );
  }
}
