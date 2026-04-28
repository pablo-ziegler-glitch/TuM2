import 'package:flutter/material.dart';

import '../../merchant_badges/domain/trust_badges.dart';
import '../../merchant_badges/domain/merchant_visual_models.dart';

@immutable
class MerchantPublicViewData {
  const MerchantPublicViewData({
    required this.merchantId,
    required this.zoneId,
    required this.name,
    required this.categoryId,
    required this.categoryLabel,
    required this.coverImageUrl,
    required this.logoUrl,
    required this.address,
    required this.phonePrimary,
    required this.lat,
    required this.lng,
    required this.mapsUrl,
    required this.isOpenNow,
    required this.hasPharmacyDutyToday,
    required this.openStatusLabel,
    required this.lastDataRefreshAt,
    required this.featuredProductIds,
    required this.verificationStatus,
    required this.visibilityStatus,
    required this.lifecycleStatus,
    required this.operationalSignalType,
    required this.manualOverrideMode,
    required this.publicStatusLabel,
    required this.is24h,
    required this.badges,
    required this.primaryTrustBadge,
    required this.scheduleSummary,
    required this.nextOpenAt,
    required this.nextCloseAt,
    required this.nextTransitionAt,
    required this.isOpenNowSnapshot,
    required this.snapshotComputedAt,
  });

  final String merchantId;
  final String zoneId;
  final String name;
  final String categoryId;
  final String categoryLabel;
  final String? coverImageUrl;
  final String? logoUrl;
  final String address;
  final String? phonePrimary;
  final double? lat;
  final double? lng;
  final String? mapsUrl;
  final bool? isOpenNow;
  final bool hasPharmacyDutyToday;
  final String openStatusLabel;
  final DateTime? lastDataRefreshAt;
  final List<String> featuredProductIds;
  final String verificationStatus;
  final String visibilityStatus;
  final String lifecycleStatus;
  final String operationalSignalType;
  final String manualOverrideMode;
  final String? publicStatusLabel;
  final bool? is24h;
  final List<TrustBadgeId> badges;
  final TrustBadgeId? primaryTrustBadge;
  final MerchantScheduleSummary? scheduleSummary;
  final DateTime? nextOpenAt;
  final DateTime? nextCloseAt;
  final DateTime? nextTransitionAt;
  final bool? isOpenNowSnapshot;
  final DateTime? snapshotComputedAt;

  bool get hasPhone => (phonePrimary ?? '').trim().isNotEmpty;
  bool get isPharmacyCategory {
    final normalized = categoryId.trim().toLowerCase();
    return normalized == 'farmacia';
  }
}

enum MerchantStatusBadgeType {
  duty,
  open,
  closed,
  referential,
}

@immutable
class MerchantStatusBadgeViewData {
  const MerchantStatusBadgeViewData({
    required this.type,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.primaryKey,
    this.secondary = const <MerchantBadgeKey>[],
    this.confidence,
  });

  final MerchantStatusBadgeType type;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final MerchantBadgeKey primaryKey;
  final List<MerchantBadgeKey> secondary;
  final MerchantBadgeKey? confidence;
}

@immutable
class MerchantFeaturedProductViewData {
  const MerchantFeaturedProductViewData({
    required this.productId,
    required this.name,
    required this.priceLabel,
    required this.imageUrl,
  });

  final String productId;
  final String name;
  final String priceLabel;
  final String? imageUrl;
}

@immutable
class MerchantScheduleViewData {
  const MerchantScheduleViewData({
    required this.days,
  });

  final List<MerchantScheduleDayViewData> days;
}

@immutable
class MerchantScheduleDayViewData {
  const MerchantScheduleDayViewData({
    required this.dayKey,
    required this.dayLabel,
    required this.slotsLabel,
    required this.isToday,
  });

  final String dayKey;
  final String dayLabel;
  final String slotsLabel;
  final bool isToday;
}

@immutable
class MerchantOperationalSignalViewData {
  const MerchantOperationalSignalViewData({
    required this.id,
    required this.label,
    required this.isAlert,
  });

  final String id;
  final String label;
  final bool isAlert;
}

@immutable
class PharmacyDutyViewData {
  const PharmacyDutyViewData({
    required this.endsAt,
  });

  final DateTime? endsAt;
}
