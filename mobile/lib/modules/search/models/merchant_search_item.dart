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
  final DateTime? twentyFourHourCooldownUntil;
  final int? twentyFourHourStrikeCount;
  final String? publicStatusLabel;
  final String openStatusLabel;
  final bool hasOperationalSignal;
  final String operationalSignalType;
  final String? operationalSignalMessage;
  final String? operationalStatusLabel;
  final String manualOverrideMode;
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
    this.twentyFourHourCooldownUntil,
    this.twentyFourHourStrikeCount,
    this.publicStatusLabel,
    required this.openStatusLabel,
    this.hasOperationalSignal = false,
    this.operationalSignalType = 'none',
    this.operationalSignalMessage,
    this.operationalStatusLabel,
    this.manualOverrideMode = 'none',
    required this.sortBoost,
    required this.searchKeywords,
    this.distanceMeters,
  });

  MerchantSearchItem copyWith({
    double? distanceMeters,
    bool clearDistance = false,
    bool? isOnDutyToday,
    bool? is24h,
    DateTime? twentyFourHourCooldownUntil,
    int? twentyFourHourStrikeCount,
    String? publicStatusLabel,
    bool? hasOperationalSignal,
    String? operationalSignalType,
    String? operationalSignalMessage,
    String? operationalStatusLabel,
    String? manualOverrideMode,
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
      twentyFourHourCooldownUntil:
          twentyFourHourCooldownUntil ?? this.twentyFourHourCooldownUntil,
      twentyFourHourStrikeCount:
          twentyFourHourStrikeCount ?? this.twentyFourHourStrikeCount,
      publicStatusLabel: publicStatusLabel ?? this.publicStatusLabel,
      openStatusLabel: openStatusLabel,
      hasOperationalSignal: hasOperationalSignal ?? this.hasOperationalSignal,
      operationalSignalType:
          operationalSignalType ?? this.operationalSignalType,
      operationalSignalMessage:
          operationalSignalMessage ?? this.operationalSignalMessage,
      operationalStatusLabel:
          operationalStatusLabel ?? this.operationalStatusLabel,
      manualOverrideMode: manualOverrideMode ?? this.manualOverrideMode,
      sortBoost: sortBoost,
      searchKeywords: searchKeywords,
      distanceMeters:
          clearDistance ? null : (distanceMeters ?? this.distanceMeters),
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
      twentyFourHourCooldownUntil: _dateTimeValue(
        data['twentyFourHourCooldownUntil'],
      ),
      twentyFourHourStrikeCount:
          (data['twentyFourHourStrikeCount'] as num?)?.toInt(),
      publicStatusLabel: data['publicStatusLabel'] as String?,
      openStatusLabel: (data['openStatusLabel'] as String?) ??
          (data['todayScheduleLabel'] as String?) ??
          '',
      hasOperationalSignal: data['hasOperationalSignal'] == true,
      operationalSignalType:
          (data['operationalSignalType'] as String?) ?? 'none',
      operationalSignalMessage: data['operationalSignalMessage'] as String?,
      operationalStatusLabel: data['operationalStatusLabel'] as String?,
      manualOverrideMode: (data['manualOverrideMode'] as String?) ?? 'none',
      sortBoost: (data['sortBoost'] as num?)?.toDouble() ?? 0,
      searchKeywords: rawKeywords.map((e) => e.toString()).toList(),
    );
  }

  static DateTime? _dateTimeValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
