import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pharmacy/services/distance_calculator.dart';
import '../analytics/merchant_detail_analytics.dart';
import 'merchant_detail_actions.dart';
import '../data/dtos/merchant_detail_dto.dart';
import '../data/mappers/merchant_detail_mappers.dart';
import '../data/merchant_detail_repository.dart';
import '../domain/merchant_detail_view_data.dart';
import 'merchant_detail_state.dart';
import 'merchant_location_reader.dart';
import 'merchant_detail_error_mapper.dart';

final merchantDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<MerchantDetailController, MerchantDetailState, String>(
  MerchantDetailController.new,
);

class MerchantDetailController
    extends AutoDisposeFamilyAsyncNotifier<MerchantDetailState, String> {
  late String _merchantId;

  MerchantDetailDataSource get _repository =>
      ref.read(merchantDetailRepositoryProvider);
  MerchantDetailAnalyticsSink get _analytics =>
      ref.read(merchantDetailAnalyticsProvider);
  MerchantDetailActions get _actions => ref.read(merchantDetailActionsProvider);

  @override
  Future<MerchantDetailState> build(String merchantId) async {
    _merchantId = merchantId;
    MerchantCoreDto? coreDto;
    try {
      coreDto = await _repository.fetchMerchantPublic(merchantId);
    } catch (error) {
      _logError('core', error);
      rethrow;
    }
    if (coreDto == null) throw const MerchantDetailNotFoundException();

    final core = mapCoreDtoToViewData(coreDto);
    final badge = mapStatusBadge(core);
    final initial = MerchantDetailState.initial(
      merchantId: merchantId,
      merchant: core,
      badge: badge,
    );

    unawaited(
      _analytics.logDetailView(
        merchantId: merchantId,
        categoryId: core.categoryId,
        hasPharmacyDutyToday: core.hasPharmacyDutyToday,
      ),
    );

    unawaited(_loadFeaturedProducts(merchantId, core.featuredProductIds));
    unawaited(_loadSchedule(merchantId));
    unawaited(_loadSignals(merchantId));
    unawaited(_loadDistance(core));
    if (core.hasPharmacyDutyToday) {
      unawaited(_loadPharmacyDuty(merchantId));
    }

    return initial;
  }

  Future<void> retry() async {
    state = const AsyncValue<MerchantDetailState>.loading();
    state = await AsyncValue.guard(() => build(_merchantId));
  }

  Future<void> onCallTap() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final phone = current.merchant.phonePrimary;
    if (phone == null || phone.trim().isEmpty) return;

    final opened = await _actions.openCall(phone);
    unawaited(
      _analytics.logCallClick(
        merchantId: current.merchantId,
        launchSucceeded: opened,
      ),
    );
  }

  Future<void> onDirectionsTap() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final opened = await _actions.openDirections(
      address: current.merchant.address,
      lat: current.merchant.lat,
      lng: current.merchant.lng,
      mapsUrl: current.merchant.mapsUrl,
    );

    unawaited(
      _analytics.logDirectionsClick(
        merchantId: current.merchantId,
        launchSucceeded: opened,
      ),
    );
  }

  Future<void> onShareTap() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final success = await _actions.shareMerchant(
      merchantId: current.merchantId,
      merchantName: current.merchant.name,
    );

    unawaited(
      _analytics.logShareClick(
        merchantId: current.merchantId,
        launchSucceeded: success,
      ),
    );
  }

  Future<void> _loadFeaturedProducts(
    String merchantId,
    List<String> featuredProductIds,
  ) async {
    final repository = _repository;
    try {
      final productDtos = await repository.fetchFeaturedProducts(
        merchantId,
        preferredProductIds: featuredProductIds,
        limit: 6,
      );
      final featured =
          productDtos.map(mapProductDtoToViewData).toList(growable: false);
      _updateLoadedState(
        (current) => current.copyWith(
          featuredProducts:
              AsyncValue<List<MerchantFeaturedProductViewData>>.data(
            featured,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _updateLoadedState(
        (current) => current.copyWith(
          featuredProducts:
              AsyncValue<List<MerchantFeaturedProductViewData>>.error(
            error,
            stackTrace,
          ),
        ),
      );
      _logError('products', error);
    }
  }

  Future<void> _loadSchedule(String merchantId) async {
    final repository = _repository;
    try {
      final scheduleDto = await repository.fetchSchedule(merchantId);
      final schedule =
          scheduleDto == null ? null : mapScheduleDtoToViewData(scheduleDto);
      _updateLoadedState(
        (current) => current.copyWith(
          schedule: AsyncValue<MerchantScheduleViewData?>.data(schedule),
        ),
      );
    } catch (error, stackTrace) {
      _updateLoadedState(
        (current) => current.copyWith(
          schedule: AsyncValue<MerchantScheduleViewData?>.error(
            error,
            stackTrace,
          ),
        ),
      );
      _logError('schedule', error);
    }
  }

  Future<void> _loadSignals(String merchantId) async {
    final repository = _repository;
    try {
      final dto = await repository.fetchSignals(merchantId);
      final resolvedSignals = dto == null
          ? const <MerchantOperationalSignalViewData>[]
          : mapSignalsDtoToViewData(dto);
      _updateLoadedState(
        (current) => current.copyWith(
          signals: AsyncValue<List<MerchantOperationalSignalViewData>>.data(
            resolvedSignals,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _updateLoadedState(
        (current) => current.copyWith(
          signals: AsyncValue<List<MerchantOperationalSignalViewData>>.error(
            error,
            stackTrace,
          ),
        ),
      );
      _logError('signals', error);
    }
  }

  Future<void> _loadPharmacyDuty(String merchantId) async {
    final repository = _repository;
    try {
      final dutyDto = await repository.fetchActivePharmacyDuty(merchantId);
      final duty = dutyDto == null
          ? const PharmacyDutyViewData(endsAt: null)
          : mapDutyDtoToViewData(dutyDto);
      _updateLoadedState(
        (current) => current.copyWith(
          pharmacyDuty: AsyncValue<PharmacyDutyViewData?>.data(duty),
        ),
      );
      unawaited(
        _analytics.logDutyBannerView(
          merchantId: merchantId,
          hasEndsAt: duty.endsAt != null,
        ),
      );
    } catch (error) {
      _updateLoadedState(
        (current) => current.copyWith(
          pharmacyDuty: const AsyncValue<PharmacyDutyViewData?>.data(
            PharmacyDutyViewData(endsAt: null),
          ),
        ),
      );
      unawaited(
        _analytics.logDutyBannerView(
          merchantId: merchantId,
          hasEndsAt: false,
        ),
      );
      _logError('pharmacy_duties', error);
    }
  }

  Future<void> _loadDistance(MerchantPublicViewData core) async {
    if (core.lat == null || core.lng == null) return;

    final locationReader = ref.read(merchantLocationReaderProvider);
    final location = await locationReader.getCurrentLocationIfPermitted();
    if (location == null) return;

    // Calculo local, sin bloquear el render critico del shell.
    final meters = DistanceCalculator.haversine(
      lat1: location.lat,
      lng1: location.lng,
      lat2: core.lat!,
      lng2: core.lng!,
    ).round();

    _updateLoadedState(
      (current) => current.copyWith(
        distanceLabel: DistanceCalculator.formatDistance(meters),
      ),
    );
  }

  void _logError(String stage, Object error) {
    final mappedType = classifyMerchantDetailError(error);
    final errorType = mappedType == MerchantDetailErrorType.connection
        ? 'connection'
        : 'generic';
    unawaited(
      _analytics.logError(
        merchantId: _merchantId,
        stage: stage,
        errorType: errorType,
      ),
    );
  }

  void _updateLoadedState(
    MerchantDetailState Function(MerchantDetailState current) transform,
  ) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<MerchantDetailState>.data(transform(current));
  }
}
