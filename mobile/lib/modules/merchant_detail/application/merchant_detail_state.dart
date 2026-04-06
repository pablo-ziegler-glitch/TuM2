import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/merchant_detail_view_data.dart';

class MerchantDetailState {
  const MerchantDetailState({
    required this.merchantId,
    required this.core,
    required this.products,
    required this.schedule,
    required this.signals,
    required this.distanceLabel,
    required this.isScheduleExpanded,
  });

  final String merchantId;
  final MerchantCoreViewData core;
  final AsyncValue<List<MerchantProductViewData>> products;
  final AsyncValue<MerchantScheduleViewData?> schedule;
  final AsyncValue<List<MerchantOperationalSignalViewData>> signals;
  final String? distanceLabel;
  final bool isScheduleExpanded;

  factory MerchantDetailState.initial({
    required String merchantId,
    required MerchantCoreViewData core,
  }) {
    return MerchantDetailState(
      merchantId: merchantId,
      core: core,
      products: const AsyncValue<List<MerchantProductViewData>>.loading(),
      schedule: const AsyncValue<MerchantScheduleViewData?>.loading(),
      signals: AsyncValue<List<MerchantOperationalSignalViewData>>.data(
        core.operationalSignals,
      ),
      distanceLabel: null,
      isScheduleExpanded: false,
    );
  }

  MerchantDetailState copyWith({
    AsyncValue<List<MerchantProductViewData>>? products,
    AsyncValue<MerchantScheduleViewData?>? schedule,
    AsyncValue<List<MerchantOperationalSignalViewData>>? signals,
    String? distanceLabel,
    bool clearDistanceLabel = false,
    bool? isScheduleExpanded,
  }) {
    return MerchantDetailState(
      merchantId: merchantId,
      core: core,
      products: products ?? this.products,
      schedule: schedule ?? this.schedule,
      signals: signals ?? this.signals,
      distanceLabel:
          clearDistanceLabel ? null : (distanceLabel ?? this.distanceLabel),
      isScheduleExpanded: isScheduleExpanded ?? this.isScheduleExpanded,
    );
  }
}

class MerchantDetailNotFoundException implements Exception {
  const MerchantDetailNotFoundException();
}
