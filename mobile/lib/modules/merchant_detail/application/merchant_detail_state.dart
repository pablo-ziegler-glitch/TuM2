import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/merchant_detail_view_data.dart';

class MerchantDetailState {
  const MerchantDetailState({
    required this.merchantId,
    required this.merchant,
    required this.badge,
    required this.pharmacyDuty,
    required this.featuredProducts,
    required this.schedule,
    required this.signals,
    required this.distanceLabel,
  });

  final String merchantId;
  final MerchantPublicViewData merchant;
  final MerchantStatusBadgeViewData badge;
  final AsyncValue<PharmacyDutyViewData?> pharmacyDuty;
  final AsyncValue<List<MerchantFeaturedProductViewData>> featuredProducts;
  final AsyncValue<MerchantScheduleViewData?> schedule;
  final AsyncValue<List<MerchantOperationalSignalViewData>> signals;
  final String? distanceLabel;

  factory MerchantDetailState.initial({
    required String merchantId,
    required MerchantPublicViewData merchant,
    required MerchantStatusBadgeViewData badge,
  }) {
    return MerchantDetailState(
      merchantId: merchantId,
      merchant: merchant,
      badge: badge,
      pharmacyDuty: merchant.hasPharmacyDutyToday
          ? const AsyncValue<PharmacyDutyViewData?>.loading()
          : const AsyncValue<PharmacyDutyViewData?>.data(null),
      featuredProducts:
          const AsyncValue<List<MerchantFeaturedProductViewData>>.loading(),
      schedule: const AsyncValue<MerchantScheduleViewData?>.loading(),
      signals:
          const AsyncValue<List<MerchantOperationalSignalViewData>>.loading(),
      distanceLabel: null,
    );
  }

  MerchantDetailState copyWith({
    AsyncValue<PharmacyDutyViewData?>? pharmacyDuty,
    AsyncValue<List<MerchantFeaturedProductViewData>>? featuredProducts,
    AsyncValue<MerchantScheduleViewData?>? schedule,
    AsyncValue<List<MerchantOperationalSignalViewData>>? signals,
    String? distanceLabel,
    bool clearDistanceLabel = false,
  }) {
    return MerchantDetailState(
      merchantId: merchantId,
      merchant: merchant,
      badge: badge,
      pharmacyDuty: pharmacyDuty ?? this.pharmacyDuty,
      featuredProducts: featuredProducts ?? this.featuredProducts,
      schedule: schedule ?? this.schedule,
      signals: signals ?? this.signals,
      distanceLabel:
          clearDistanceLabel ? null : (distanceLabel ?? this.distanceLabel),
    );
  }
}

class MerchantDetailNotFoundException implements Exception {
  const MerchantDetailNotFoundException();
}
