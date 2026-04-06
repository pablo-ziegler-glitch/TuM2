import 'package:flutter/material.dart';

@immutable
class MerchantCoreViewData {
  const MerchantCoreViewData({
    required this.merchantId,
    required this.name,
    required this.categoryLabel,
    required this.zoneId,
    required this.address,
    required this.lat,
    required this.lng,
    required this.isOpenNow,
    required this.isOnDutyToday,
    required this.openStatusLabel,
    required this.verificationStatus,
    required this.operationalBadge,
    required this.trustBadges,
    required this.operationalSignals,
  });

  final String merchantId;
  final String name;
  final String categoryLabel;
  final String zoneId;
  final String address;
  final double? lat;
  final double? lng;
  final bool? isOpenNow;
  final bool isOnDutyToday;
  final String openStatusLabel;
  final String verificationStatus;
  final MerchantOperationalBadgeViewData operationalBadge;
  final List<MerchantTrustBadgeViewData> trustBadges;
  final List<MerchantOperationalSignalViewData> operationalSignals;
}

@immutable
class MerchantProductViewData {
  const MerchantProductViewData({
    required this.productId,
    required this.merchantId,
    required this.name,
    required this.priceLabel,
    required this.imageUrl,
  });

  final String productId;
  final String merchantId;
  final String name;
  final String priceLabel;
  final String? imageUrl;
}

@immutable
class MerchantScheduleViewData {
  const MerchantScheduleViewData({
    required this.timezone,
    required this.days,
  });

  final String? timezone;
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

enum MerchantOperationalBadgeType {
  onDuty,
  openNow,
  closed,
  referential,
}

@immutable
class MerchantOperationalBadgeViewData {
  const MerchantOperationalBadgeViewData({
    required this.type,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final MerchantOperationalBadgeType type;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
}

enum MerchantTrustBadgeType {
  verified,
  claimed,
  referential,
  community,
}

@immutable
class MerchantTrustBadgeViewData {
  const MerchantTrustBadgeViewData({
    required this.type,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final MerchantTrustBadgeType type;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
}
