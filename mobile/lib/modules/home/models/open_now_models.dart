import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/catalog/zones_catalog_models.dart';
import '../../merchant_badges/domain/trust_badges.dart';

class OpenNowZone {
  const OpenNowZone({
    required this.zoneId,
    required this.name,
    required this.cityId,
    this.priorityLevel,
  });

  final String zoneId;
  final String name;
  final String cityId;
  final int? priorityLevel;

  factory OpenNowZone.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return OpenNowZone.fromMap(doc.id, doc.data());
  }

  factory OpenNowZone.fromMap(
    String zoneId,
    Map<String, dynamic> data,
  ) {
    return OpenNowZone(
      zoneId: zoneId,
      name: _readText(data, const ['name', 'nombre']) ?? zoneId,
      cityId: _readText(data, const ['cityId', 'ciudadId', 'city_id']) ?? '',
      priorityLevel: _readPriority(data),
    );
  }

  factory OpenNowZone.fromCatalogEntry(ZonesCatalogEntry entry) {
    return OpenNowZone(
      zoneId: entry.zoneId,
      name: entry.name,
      cityId: entry.cityId,
      priorityLevel: entry.priorityLevel,
    );
  }

  static String? _readText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static int? _readPriority(Map<String, dynamic> data) {
    final value =
        data['priorityLevel'] ?? data['priority'] ?? data['prioridad'];
    return value is num ? value.toInt() : null;
  }
}

class OpenNowMerchant {
  const OpenNowMerchant({
    required this.merchantId,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.zoneId,
    required this.addressShort,
    required this.verificationStatus,
    required this.visibilityStatus,
    required this.isOpenNow,
    required this.openStatusLabel,
    required this.todayScheduleLabel,
    this.hasOperationalSignal = false,
    this.operationalSignalType = 'none',
    this.operationalSignalMessage,
    this.operationalStatusLabel,
    this.manualOverrideMode = 'none',
    this.badges = const [],
    this.primaryTrustBadge,
    this.scheduleSummary,
    this.nextOpenAt,
    this.nextCloseAt,
    this.nextTransitionAt,
    this.isOpenNowSnapshot,
    this.snapshotComputedAt,
    this.publicStatusLabel,
    this.is24h,
    this.twentyFourHourCooldownUntil,
    this.twentyFourHourStrikeCount,
    required this.lastDataRefreshAt,
    required this.sortBoost,
    required this.lat,
    required this.lng,
    required this.isOnDutyToday,
    this.distanceMeters,
  });

  final String merchantId;
  final String name;
  final String categoryId;
  final String categoryName;
  final String zoneId;
  final String addressShort;
  final String verificationStatus;
  final String visibilityStatus;
  final bool isOpenNow;
  final String openStatusLabel;
  final String todayScheduleLabel;
  final bool hasOperationalSignal;
  final String operationalSignalType;
  final String? operationalSignalMessage;
  final String? operationalStatusLabel;
  final String manualOverrideMode;
  final List<TrustBadgeId> badges;
  final TrustBadgeId? primaryTrustBadge;
  final MerchantScheduleSummary? scheduleSummary;
  final DateTime? nextOpenAt;
  final DateTime? nextCloseAt;
  final DateTime? nextTransitionAt;
  final bool? isOpenNowSnapshot;
  final DateTime? snapshotComputedAt;
  final String? publicStatusLabel;
  final bool? is24h;
  final DateTime? twentyFourHourCooldownUntil;
  final int? twentyFourHourStrikeCount;
  final DateTime? lastDataRefreshAt;
  final double sortBoost;
  final double? lat;
  final double? lng;
  final bool isOnDutyToday;
  final double? distanceMeters;

  static const Set<String> _healthCategoryTokens = {
    'pharmacy',
    'farmacia',
    'veterinaria',
    'veterinary',
    'clinica',
    'clinic',
    'hospital',
    'salud',
    'health',
    'odont',
    'dental',
    'medic',
    'laboratorio',
    'laboratory',
  };

  String get effectiveScheduleLabel {
    final schedule = todayScheduleLabel.trim();
    if (schedule.isNotEmpty) return schedule;
    return openStatusLabel.trim();
  }

  bool get isHealthRelatedCategory {
    final normalized = _normalizeText('$categoryId $categoryName');
    for (final token in _healthCategoryTokens) {
      if (normalized.contains(token)) return true;
    }
    return false;
  }

  bool get isSpecialOnDutyHealth => isOnDutyToday && isHealthRelatedCategory;

  OpenNowMerchant copyWith({
    double? distanceMeters,
    bool clearDistance = false,
  }) {
    return OpenNowMerchant(
      merchantId: merchantId,
      name: name,
      categoryId: categoryId,
      categoryName: categoryName,
      zoneId: zoneId,
      addressShort: addressShort,
      verificationStatus: verificationStatus,
      visibilityStatus: visibilityStatus,
      isOpenNow: isOpenNow,
      openStatusLabel: openStatusLabel,
      todayScheduleLabel: todayScheduleLabel,
      hasOperationalSignal: hasOperationalSignal,
      operationalSignalType: operationalSignalType,
      operationalSignalMessage: operationalSignalMessage,
      operationalStatusLabel: operationalStatusLabel,
      manualOverrideMode: manualOverrideMode,
      badges: badges,
      primaryTrustBadge: primaryTrustBadge,
      scheduleSummary: scheduleSummary,
      nextOpenAt: nextOpenAt,
      nextCloseAt: nextCloseAt,
      nextTransitionAt: nextTransitionAt,
      isOpenNowSnapshot: isOpenNowSnapshot,
      snapshotComputedAt: snapshotComputedAt,
      publicStatusLabel: publicStatusLabel,
      is24h: is24h,
      twentyFourHourCooldownUntil: twentyFourHourCooldownUntil,
      twentyFourHourStrikeCount: twentyFourHourStrikeCount,
      lastDataRefreshAt: lastDataRefreshAt,
      sortBoost: sortBoost,
      lat: lat,
      lng: lng,
      isOnDutyToday: isOnDutyToday,
      distanceMeters:
          clearDistance ? null : (distanceMeters ?? this.distanceMeters),
    );
  }

  factory OpenNowMerchant.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final location = data['location'];
    final merchantId = (data['merchantId'] as String?)?.trim();
    final addressShort = (data['addressShort'] as String?)?.trim();
    final address = (data['address'] as String?)?.trim();
    final categoryName = (data['categoryName'] as String?)?.trim();
    final categoryLabel = (data['categoryLabel'] as String?)?.trim();

    return OpenNowMerchant(
      merchantId:
          merchantId == null || merchantId.isEmpty ? doc.id : merchantId,
      name: (data['name'] as String?)?.trim() ?? '',
      categoryId: (data['categoryId'] as String?)?.trim() ??
          (data['category'] as String?)?.trim() ??
          '',
      categoryName: (categoryName?.isNotEmpty == true)
          ? categoryName!
          : (categoryLabel?.isNotEmpty == true ? categoryLabel! : 'Comercio'),
      zoneId: (data['zoneId'] as String?)?.trim() ?? '',
      addressShort: (addressShort?.isNotEmpty == true)
          ? addressShort!
          : (address?.isNotEmpty == true ? address! : ''),
      verificationStatus:
          (data['verificationStatus'] as String?)?.trim() ?? 'unverified',
      visibilityStatus:
          (data['visibilityStatus'] as String?)?.trim() ?? 'visible',
      isOpenNow: data['isOpenNow'] == true,
      openStatusLabel: (data['openStatusLabel'] as String?)?.trim() ?? '',
      todayScheduleLabel: (data['todayScheduleLabel'] as String?)?.trim() ?? '',
      hasOperationalSignal: data['hasOperationalSignal'] == true,
      operationalSignalType:
          (data['operationalSignalType'] as String?)?.trim() ?? 'none',
      operationalSignalMessage:
          (data['operationalSignalMessage'] as String?)?.trim(),
      operationalStatusLabel:
          (data['operationalStatusLabel'] as String?)?.trim(),
      manualOverrideMode:
          (data['manualOverrideMode'] as String?)?.trim() ?? 'none',
      badges: parseTrustBadges(data['badges']),
      primaryTrustBadge: TrustBadgeId.fromValue(
        (data['primaryTrustBadge'] as String?) ?? '',
      ),
      scheduleSummary: data['scheduleSummary'] is Map
          ? MerchantScheduleSummary.fromMap(
              Map<String, dynamic>.from(data['scheduleSummary'] as Map),
            )
          : null,
      nextOpenAt: _asDateTime(data['nextOpenAt']),
      nextCloseAt: _asDateTime(data['nextCloseAt']),
      nextTransitionAt: _asDateTime(data['nextTransitionAt']),
      isOpenNowSnapshot: data['isOpenNowSnapshot'] as bool?,
      snapshotComputedAt: _asDateTime(data['snapshotComputedAt']),
      publicStatusLabel: (data['publicStatusLabel'] as String?)?.trim(),
      is24h: data['is24h'] as bool?,
      twentyFourHourCooldownUntil:
          _asDateTime(data['twentyFourHourCooldownUntil']),
      twentyFourHourStrikeCount:
          (data['twentyFourHourStrikeCount'] as num?)?.toInt(),
      lastDataRefreshAt: _asDateTime(data['lastDataRefreshAt']),
      sortBoost: (data['sortBoost'] as num?)?.toDouble() ?? 0,
      lat: _resolveLatitude(data, location),
      lng: _resolveLongitude(data, location),
      isOnDutyToday:
          data['isOnDutyToday'] == true || data['hasPharmacyDutyToday'] == true,
    );
  }

  static DateTime? _asDateTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate().toLocal();
    if (raw is DateTime) return raw.toLocal();
    if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    return null;
  }

  static double? _resolveLatitude(Map<String, dynamic> data, dynamic location) {
    final lat = (data['lat'] as num?)?.toDouble();
    if (lat != null) return lat;
    if (location is GeoPoint) return location.latitude;
    if (location is Map<String, dynamic>) {
      return (location['lat'] as num?)?.toDouble();
    }
    return null;
  }

  static double? _resolveLongitude(
      Map<String, dynamic> data, dynamic location) {
    final lng = (data['lng'] as num?)?.toDouble();
    if (lng != null) return lng;
    if (location is GeoPoint) return location.longitude;
    if (location is Map<String, dynamic>) {
      return (location['lng'] as num?)?.toDouble();
    }
    return null;
  }

  static String _normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }
}
