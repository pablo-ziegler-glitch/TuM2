import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/providers/analytics_provider.dart';
import '../../pharmacy/services/distance_calculator.dart';
import '../analytics/open_now_analytics.dart';
import '../models/open_now_models.dart';
import '../repositories/open_now_repository.dart';

typedef OpenNowUserPosition = ({double lat, double lng});

enum OpenNowLocationStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  error,
  unavailable,
}

class OpenNowLocationReadResult {
  const OpenNowLocationReadResult({
    required this.status,
    this.position,
  });

  final OpenNowLocationStatus status;
  final OpenNowUserPosition? position;
}

abstract interface class OpenNowLocationReader {
  Future<OpenNowLocationReadResult> tryGetCurrentPosition();
}

class GeolocatorOpenNowLocationReader implements OpenNowLocationReader {
  const GeolocatorOpenNowLocationReader();

  static const _timeout = Duration(seconds: 4);

  @override
  Future<OpenNowLocationReadResult> tryGetCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const OpenNowLocationReadResult(
          status: OpenNowLocationStatus.serviceDisabled,
        );
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        return const OpenNowLocationReadResult(
          status: OpenNowLocationStatus.denied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const OpenNowLocationReadResult(
          status: OpenNowLocationStatus.deniedForever,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: _timeout,
      );
      return OpenNowLocationReadResult(
        status: OpenNowLocationStatus.granted,
        position: (lat: position.latitude, lng: position.longitude),
      );
    } on TimeoutException {
      return const OpenNowLocationReadResult(
        status: OpenNowLocationStatus.timeout,
      );
    } catch (_) {
      return const OpenNowLocationReadResult(
        status: OpenNowLocationStatus.error,
      );
    }
  }
}

class OpenNowState {
  const OpenNowState({
    this.hasInitialized = false,
    this.isLoading = false,
    this.error,
    this.zones = const [],
    this.activeZoneId = '',
    this.merchants = const [],
    this.fallbackMerchants = const [],
    this.userPosition,
    this.locationStatus = OpenNowLocationStatus.unavailable,
  });

  final bool hasInitialized;
  final bool isLoading;
  final Object? error;
  final List<OpenNowZone> zones;
  final String activeZoneId;
  final List<OpenNowMerchant> merchants;
  final List<OpenNowMerchant> fallbackMerchants;
  final OpenNowUserPosition? userPosition;
  final OpenNowLocationStatus locationStatus;

  String get activeZoneName {
    for (final zone in zones) {
      if (zone.zoneId == activeZoneId) return zone.name;
    }
    return 'Tu zona';
  }

  bool get hasLocation => userPosition != null;
  bool get hasOpenResults => merchants.isNotEmpty;
  bool get hasFallback => fallbackMerchants.isNotEmpty;
  bool get isEmpty => !isLoading && error == null && !hasOpenResults;

  OpenNowState copyWith({
    bool? hasInitialized,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    List<OpenNowZone>? zones,
    String? activeZoneId,
    List<OpenNowMerchant>? merchants,
    List<OpenNowMerchant>? fallbackMerchants,
    OpenNowUserPosition? userPosition,
    bool clearUserPosition = false,
    OpenNowLocationStatus? locationStatus,
  }) {
    return OpenNowState(
      hasInitialized: hasInitialized ?? this.hasInitialized,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      zones: zones ?? this.zones,
      activeZoneId: activeZoneId ?? this.activeZoneId,
      merchants: merchants ?? this.merchants,
      fallbackMerchants: fallbackMerchants ?? this.fallbackMerchants,
      userPosition:
          clearUserPosition ? null : (userPosition ?? this.userPosition),
      locationStatus: locationStatus ?? this.locationStatus,
    );
  }
}

class OpenNowNotifier extends StateNotifier<OpenNowState> {
  OpenNowNotifier({
    Ref? ref,
    required OpenNowDataSource repository,
    required OpenNowAnalyticsSink analytics,
    required OpenNowLocationReader locationReader,
  })  : _ref = ref,
        _repository = repository,
        _analytics = analytics,
        _locationReader = locationReader,
        super(const OpenNowState());

  final Ref? _ref;
  final OpenNowDataSource _repository;
  final OpenNowAnalyticsSink _analytics;
  final OpenNowLocationReader _locationReader;

  static const _verificationRank = <String, int>{
    'verified': 6,
    'validated': 5,
    'claimed': 4,
    'referential': 3,
    'community_submitted': 2,
    'unverified': 1,
  };

  Future<void> ensureInitialized() async {
    if (state.hasInitialized) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final locationFuture = _locationReader.tryGetCurrentPosition();
      final zones = await _repository.fetchZones();
      if (zones.isEmpty) {
        throw StateError('No hay zonas activas disponibles.');
      }

      final selectedZoneId = zones.first.zoneId;
      unawaited(
          _logZoneResolved(zoneId: selectedZoneId, source: 'open_now_init'));
      final locationResult = await locationFuture;
      final userPosition = _handleLocationResult(locationResult);

      state = state.copyWith(
        zones: zones,
        activeZoneId: selectedZoneId,
        userPosition: userPosition,
        clearUserPosition: userPosition == null,
        locationStatus: locationResult.status,
        hasInitialized: true,
        isLoading: true,
        clearError: true,
      );

      await _loadForZone(zoneId: selectedZoneId);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        merchants: const [],
        fallbackMerchants: const [],
      );
    }
  }

  Future<void> setZone(String zoneId) async {
    if (zoneId.trim().isEmpty || zoneId == state.activeZoneId) return;
    state = state.copyWith(
      activeZoneId: zoneId,
      isLoading: true,
      clearError: true,
    );
    unawaited(_logZoneResolved(zoneId: zoneId, source: 'open_now_zone_switch'));
    await _loadForZone(zoneId: zoneId);
  }

  Future<void> refresh() async {
    final zoneId = state.activeZoneId;
    if (zoneId.isEmpty) return;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );
    await _loadForZone(zoneId: zoneId);
  }

  void logCardClicked({
    required OpenNowMerchant merchant,
    required bool isFallback,
    required int rank,
  }) {
    unawaited(_analytics.logOpenNowMerchantOpened(
      zoneId: state.activeZoneId,
      merchantId: merchant.merchantId,
      categoryId: merchant.categoryId,
      isOpenNowShown: merchant.isOpenNow,
      isOnDutyShown: merchant.isOnDutyToday,
      source: isFallback ? 'open_now_fallback' : 'open_now_results',
    ));
  }

  Future<void> _loadForZone({
    required String zoneId,
  }) async {
    try {
      final openNow = await _repository.fetchOpenNow(zoneId: zoneId);
      final rankedOpenNow = _rankMerchants(
        openNow,
        userPosition: state.userPosition,
      );

      List<OpenNowMerchant> fallback = const [];
      if (rankedOpenNow.isEmpty) {
        final fallbackRaw = await _repository.fetchFallback(zoneId: zoneId);
        fallback = _rankMerchants(
          fallbackRaw,
          userPosition: state.userPosition,
        ).take(6).toList(growable: false);

        // El fallback se refleja en open_now_viewed con is_open_now_shown=false.
      }

      state = state.copyWith(
        isLoading: false,
        clearError: true,
        merchants: rankedOpenNow,
        fallbackMerchants: fallback,
      );

      final corpus = rankedOpenNow.isNotEmpty ? rankedOpenNow : fallback;
      unawaited(_analytics.logOpenNowViewed(
        zoneId: zoneId,
        resultsCount: rankedOpenNow.length,
        isOpenNowShown: rankedOpenNow.isNotEmpty,
        isOnDutyShown: corpus.any((item) => item.isOnDutyToday),
      ));
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        merchants: const [],
        fallbackMerchants: const [],
      );
    }
  }

  OpenNowUserPosition? _handleLocationResult(OpenNowLocationReadResult result) {
    switch (result.status) {
      case OpenNowLocationStatus.granted:
        return result.position;
      case OpenNowLocationStatus.denied:
      case OpenNowLocationStatus.deniedForever:
        return null;
      case OpenNowLocationStatus.serviceDisabled:
      case OpenNowLocationStatus.timeout:
      case OpenNowLocationStatus.error:
      case OpenNowLocationStatus.unavailable:
        return null;
    }
  }

  List<OpenNowMerchant> _rankMerchants(
    List<OpenNowMerchant> merchants, {
    required OpenNowUserPosition? userPosition,
  }) {
    final enriched = merchants.map((merchant) {
      if (userPosition == null ||
          merchant.lat == null ||
          merchant.lng == null) {
        return merchant.copyWith(clearDistance: true);
      }
      final distanceMeters = DistanceCalculator.haversine(
        lat1: userPosition.lat,
        lng1: userPosition.lng,
        lat2: merchant.lat!,
        lng2: merchant.lng!,
      );
      return merchant.copyWith(distanceMeters: distanceMeters);
    }).toList(growable: false);

    final ranked = List<OpenNowMerchant>.from(enriched)
      ..sort((a, b) {
        final byVerification = _verificationScore(b.verificationStatus)
            .compareTo(_verificationScore(a.verificationStatus));
        if (byVerification != 0) return byVerification;

        final byBoost = b.sortBoost.compareTo(a.sortBoost);
        if (byBoost != 0) return byBoost;

        if (userPosition != null) {
          final byDistance = (a.distanceMeters ?? double.maxFinite)
              .compareTo(b.distanceMeters ?? double.maxFinite);
          if (byDistance != 0) return byDistance;
        }

        final byCategory = a.categoryName
            .toLowerCase()
            .compareTo(b.categoryName.toLowerCase());
        if (byCategory != 0) return byCategory;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return ranked;
  }

  int _verificationScore(String status) =>
      _verificationRank[status.trim().toLowerCase()] ?? 0;

  Future<void> _logZoneResolved({
    required String zoneId,
    required String source,
  }) {
    final ref = _ref;
    if (ref == null) return Future<void>.value();
    return ref.read(analyticsServiceProvider).track(
          event: 'zone_resolved',
          parameters: {
            'surface': 'open_now',
            'zoneId': zoneId,
            'source': source,
          },
          dedupeWindow: const Duration(seconds: 10),
        );
  }
}

final openNowRepositoryProvider = Provider<OpenNowDataSource>(
  (ref) => OpenNowRepository(),
);

final openNowAnalyticsProvider = Provider<OpenNowAnalyticsSink>(
  (ref) => FirebaseOpenNowAnalytics(),
);

final openNowLocationReaderProvider = Provider<OpenNowLocationReader>(
  (ref) => const GeolocatorOpenNowLocationReader(),
);

final openNowNotifierProvider =
    StateNotifierProvider.autoDispose<OpenNowNotifier, OpenNowState>(
  (ref) {
    final link = ref.keepAlive();
    Timer? disposeTimer;
    const keepAliveTtl = Duration(minutes: 5);

    ref.onCancel(() {
      disposeTimer?.cancel();
      disposeTimer = Timer(keepAliveTtl, link.close);
    });
    ref.onResume(() {
      disposeTimer?.cancel();
      disposeTimer = null;
    });
    ref.onDispose(() {
      disposeTimer?.cancel();
    });

    return OpenNowNotifier(
      ref: ref,
      repository: ref.watch(openNowRepositoryProvider),
      analytics: ref.watch(openNowAnalyticsProvider),
      locationReader: ref.watch(openNowLocationReaderProvider),
    );
  },
);
