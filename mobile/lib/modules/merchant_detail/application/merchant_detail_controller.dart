import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pharmacy/services/distance_calculator.dart';
import '../analytics/merchant_detail_analytics.dart';
import '../data/mappers/merchant_detail_mappers.dart';
import '../data/merchant_detail_repository.dart';
import '../domain/merchant_maps.dart';
import '../domain/merchant_detail_view_data.dart';
import 'merchant_detail_state.dart';
import 'merchant_location_reader.dart';

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

  @override
  Future<MerchantDetailState> build(String merchantId) async {
    _merchantId = merchantId;

    final coreDto = await _repository.fetchCore(merchantId);
    if (coreDto == null) throw const MerchantDetailNotFoundException();

    final core = mapCoreDtoToViewData(coreDto);
    final initial = MerchantDetailState.initial(
      merchantId: merchantId,
      core: core,
    );

    unawaited(
      _analytics.logDetailOpened(
        merchantId: merchantId,
        verificationStatus: core.verificationStatus,
      ),
    );

    unawaited(_loadProducts(merchantId));
    unawaited(_loadSchedule(merchantId));
    unawaited(
        _loadSignals(merchantId, fallbackSignals: core.operationalSignals));
    unawaited(_loadDistance(core));

    return initial;
  }

  Future<void> retry() async {
    state = const AsyncValue<MerchantDetailState>.loading();
    state = await AsyncValue.guard(() => build(_merchantId));
  }

  Future<void> onDirectionsTap() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final intent = buildMerchantMapsIntent(
      address: current.core.address,
      lat: current.core.lat,
      lng: current.core.lng,
    );

    final opened = await ref.read(merchantMapsLauncherProvider).open(intent);
    unawaited(
      _analytics.logDirectionsTapped(
        merchantId: current.merchantId,
        usedCoordinates: intent.usedCoordinates,
        launchSucceeded: opened,
      ),
    );
  }

  void onProductTap(String productId) {
    final current = state.valueOrNull;
    if (current == null) return;
    unawaited(
      _analytics.logProductTapped(
        merchantId: current.merchantId,
        productId: productId,
      ),
    );
  }

  void onScheduleExpandedChanged(bool expanded) {
    _updateLoadedState(
      (current) => current.copyWith(isScheduleExpanded: expanded),
    );

    unawaited(
      _analytics.logScheduleExpanded(
        merchantId: _merchantId,
        expanded: expanded,
      ),
    );
  }

  Future<void> _loadProducts(String merchantId) async {
    final repository = _repository;
    final analytics = _analytics;
    try {
      final productDtos = await repository.fetchProducts(
        merchantId,
        limit: 6,
      );
      final products =
          productDtos.map(mapProductDtoToViewData).toList(growable: false);
      _updateLoadedState(
        (current) => current.copyWith(
          products: AsyncValue<List<MerchantProductViewData>>.data(products),
        ),
      );
    } catch (error, stackTrace) {
      _updateLoadedState(
        (current) => current.copyWith(
          products: AsyncValue<List<MerchantProductViewData>>.error(
            error,
            stackTrace,
          ),
        ),
      );
      unawaited(
        analytics.logSecondaryLoadFailed(
          merchantId: merchantId,
          section: 'products',
        ),
      );
    }
  }

  Future<void> _loadSchedule(String merchantId) async {
    final repository = _repository;
    final analytics = _analytics;
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
      unawaited(
        analytics.logSecondaryLoadFailed(
          merchantId: merchantId,
          section: 'schedule',
        ),
      );
    }
  }

  Future<void> _loadSignals(
    String merchantId, {
    required List<MerchantOperationalSignalViewData> fallbackSignals,
  }) async {
    final repository = _repository;
    final analytics = _analytics;
    try {
      final dto = await repository.fetchSignals(merchantId);
      final signals =
          dto == null ? fallbackSignals : mapSignalsDtoToViewData(dto);
      final resolvedSignals = signals.isEmpty ? fallbackSignals : signals;
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
      unawaited(
        analytics.logSecondaryLoadFailed(
          merchantId: merchantId,
          section: 'signals',
        ),
      );
    }
  }

  Future<void> _loadDistance(MerchantCoreViewData core) async {
    if (core.lat == null || core.lng == null) return;

    final locationReader = ref.read(merchantLocationReaderProvider);
    final location = await locationReader.getCurrentLocationIfPermitted();
    if (location == null) return;

    // Calculo local, sin bloquear el render critico del hero.
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

  void _updateLoadedState(
    MerchantDetailState Function(MerchantDetailState current) transform,
  ) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<MerchantDetailState>.data(transform(current));
  }
}
