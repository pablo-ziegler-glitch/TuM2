import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/pharmacy_duty_analytics.dart';
import '../models/pharmacy_duty_item.dart';
import '../models/pharmacy_zone.dart';
import '../repositories/pharmacy_duty_repository.dart';
import '../repositories/zones_repository.dart';
import '../services/business_date.dart';
import '../services/distance_calculator.dart';
import '../services/geo_location_service.dart';

enum PharmacyDutyErrorType { none, technical }

class PharmacyDutyState {
  const PharmacyDutyState({
    required this.selectedZoneId,
    required this.selectedDate,
    required this.items,
    required this.zones,
    required this.isLoadingInitial,
    required this.isRefreshing,
    required this.errorType,
    required this.hasLocationPermission,
    required this.userPosition,
    required this.lastSuccessfulFetchAt,
    required this.isUsingCachedData,
  });

  final String selectedZoneId;
  final DateTime selectedDate;
  final List<PharmacyDutyItem> items;
  final List<PharmacyZone> zones;
  final bool isLoadingInitial;
  final bool isRefreshing;
  final PharmacyDutyErrorType errorType;
  final bool hasLocationPermission;
  final ({double lat, double lng})? userPosition;
  final DateTime? lastSuccessfulFetchAt;
  final bool isUsingCachedData;

  String get selectedDateKey => businessDateKey(selectedDate);

  PharmacyDutyState copyWith({
    String? selectedZoneId,
    DateTime? selectedDate,
    List<PharmacyDutyItem>? items,
    List<PharmacyZone>? zones,
    bool? isLoadingInitial,
    bool? isRefreshing,
    PharmacyDutyErrorType? errorType,
    bool? hasLocationPermission,
    ({double lat, double lng})? userPosition,
    bool clearUserPosition = false,
    DateTime? lastSuccessfulFetchAt,
    bool clearLastSuccessfulFetch = false,
    bool? isUsingCachedData,
  }) {
    return PharmacyDutyState(
      selectedZoneId: selectedZoneId ?? this.selectedZoneId,
      selectedDate: selectedDate ?? this.selectedDate,
      items: items ?? this.items,
      zones: zones ?? this.zones,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorType: errorType ?? this.errorType,
      hasLocationPermission:
          hasLocationPermission ?? this.hasLocationPermission,
      userPosition:
          clearUserPosition ? null : (userPosition ?? this.userPosition),
      lastSuccessfulFetchAt: clearLastSuccessfulFetch
          ? null
          : (lastSuccessfulFetchAt ?? this.lastSuccessfulFetchAt),
      isUsingCachedData: isUsingCachedData ?? this.isUsingCachedData,
    );
  }

  factory PharmacyDutyState.initial() {
    return PharmacyDutyState(
      selectedZoneId: '',
      selectedDate: businessTodayUtcMinus3(),
      items: const [],
      zones: const [],
      isLoadingInitial: true,
      isRefreshing: false,
      errorType: PharmacyDutyErrorType.none,
      hasLocationPermission: false,
      userPosition: null,
      lastSuccessfulFetchAt: null,
      isUsingCachedData: false,
    );
  }
}

class PharmacyDutyNotifier extends StateNotifier<PharmacyDutyState> {
  PharmacyDutyNotifier({
    PharmacyDutySource? dutyRepository,
    ZonesSource? zonesRepository,
    GeoLocationService? geoLocationService,
    PharmacyDutyAnalyticsSink? analytics,
  })  : _dutyRepository = dutyRepository ?? PharmacyDutyRepository(),
        _zonesRepository = zonesRepository ?? ZonesRepository(),
        _geoLocationService = geoLocationService ?? GeoLocationService(),
        _analytics = analytics ?? FirebasePharmacyDutyAnalytics(),
        super(PharmacyDutyState.initial());

  final PharmacyDutySource _dutyRepository;
  final ZonesSource _zonesRepository;
  final GeoLocationService _geoLocationService;
  final PharmacyDutyAnalyticsSink _analytics;

  final Map<String, List<PharmacyDutyItem>> _cache = {};
  int _requestSerial = 0;
  bool _hasLoggedOpenedEvent = false;

  Future<void> initialize() async {
    if (state.zones.isNotEmpty || !state.isLoadingInitial) return;

    final positionResult = await _geoLocationService.getPosition();
    if (positionResult is GeoPositionOk) {
      state = state.copyWith(
        hasLocationPermission: true,
        userPosition: (lat: positionResult.lat, lng: positionResult.lng),
      );
    } else {
      state = state.copyWith(hasLocationPermission: false);
    }

    try {
      final zones = await _zonesRepository.getActiveZones();
      final resolvedZone = _resolveInitialZone(
        zones: zones,
        userPosition: state.userPosition,
      );
      state = state.copyWith(
        zones: zones,
        selectedZoneId: resolvedZone?.zoneId ?? '',
      );
      if (state.selectedZoneId.isNotEmpty) {
        await _loadForCurrentSelection(forceRefresh: true, isInitial: true);
      } else {
        state = state.copyWith(isLoadingInitial: false);
      }
    } catch (_) {
      state = state.copyWith(
        isLoadingInitial: false,
        errorType: PharmacyDutyErrorType.technical,
      );
    }
  }

  Future<void> setZone(String zoneId) async {
    if (zoneId.isEmpty || zoneId == state.selectedZoneId) return;
    state = state.copyWith(selectedZoneId: zoneId);
    await _loadForCurrentSelection(forceRefresh: true);
  }

  Future<void> setDate(DateTime date) async {
    final normalized = normalizeBusinessDate(date);
    if (normalized == state.selectedDate) return;
    final fromDate = state.selectedDateKey;
    state = state.copyWith(selectedDate: normalized);
    unawaited(
      _analytics.logDateChanged(
        fromDate: fromDate,
        toDate: state.selectedDateKey,
        zoneId: state.selectedZoneId,
      ),
    );
    await _loadForCurrentSelection(forceRefresh: true);
  }

  Future<void> retry() async {
    await _loadForCurrentSelection(forceRefresh: true);
  }

  Future<void> refresh() async {
    await _loadForCurrentSelection(forceRefresh: true, asRefresh: true);
  }

  Future<void> _loadForCurrentSelection({
    required bool forceRefresh,
    bool isInitial = false,
    bool asRefresh = false,
  }) async {
    if (state.selectedZoneId.isEmpty) {
      state = state.copyWith(isLoadingInitial: false);
      return;
    }

    final requestId = ++_requestSerial;
    final cacheKey = '${state.selectedZoneId}|${state.selectedDateKey}';
    final cached = _cache[cacheKey];

    if (isInitial) {
      state = state.copyWith(
        isLoadingInitial: true,
        errorType: PharmacyDutyErrorType.none,
      );
    } else if (asRefresh) {
      state = state.copyWith(
        isRefreshing: true,
        errorType: PharmacyDutyErrorType.none,
      );
    } else {
      state = state.copyWith(
        isLoadingInitial: true,
        errorType: PharmacyDutyErrorType.none,
      );
    }

    if (cached != null && !forceRefresh) {
      state = state.copyWith(
        isLoadingInitial: false,
        isRefreshing: false,
        items: cached,
        isUsingCachedData: true,
      );
      return;
    }

    if (!_hasLoggedOpenedEvent) {
      _hasLoggedOpenedEvent = true;
      unawaited(
        _analytics.logViewOpened(
          zoneId: state.selectedZoneId,
          date: state.selectedDateKey,
          hasLocationPermission: state.hasLocationPermission,
        ),
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final fetched = await _dutyRepository.getPublishedDuties(
        zoneId: state.selectedZoneId,
        dateKey: state.selectedDateKey,
      );
      if (requestId != _requestSerial) return;
      final sorted = _sortItems(fetched);
      _cache[cacheKey] = sorted;
      stopwatch.stop();
      state = state.copyWith(
        items: sorted,
        isLoadingInitial: false,
        isRefreshing: false,
        errorType: PharmacyDutyErrorType.none,
        lastSuccessfulFetchAt: DateTime.now(),
        isUsingCachedData: false,
      );
      unawaited(
        _analytics.logResultsLoaded(
          zoneId: state.selectedZoneId,
          date: state.selectedDateKey,
          resultsCount: sorted.length,
          loadMs: stopwatch.elapsedMilliseconds,
        ),
      );
      if (sorted.isEmpty) {
        unawaited(
          _analytics.logEmptyStateShown(
            zoneId: state.selectedZoneId,
            date: state.selectedDateKey,
          ),
        );
      }
    } catch (_) {
      if (requestId != _requestSerial) return;
      final cachedFallback = _cache[cacheKey];
      if (cachedFallback != null && cachedFallback.isNotEmpty) {
        state = state.copyWith(
          items: cachedFallback,
          isLoadingInitial: false,
          isRefreshing: false,
          errorType: PharmacyDutyErrorType.none,
          isUsingCachedData: true,
        );
      } else {
        state = state.copyWith(
          items: const [],
          isLoadingInitial: false,
          isRefreshing: false,
          errorType: PharmacyDutyErrorType.technical,
          isUsingCachedData: false,
        );
      }
    }
  }

  List<PharmacyDutyItem> _sortItems(List<PharmacyDutyItem> input) {
    final pos = state.userPosition;
    final withDistance = input.map((item) {
      if (pos == null || item.latitude == null || item.longitude == null) {
        return item.copyWith(distanceMeters: null);
      }
      final distance = DistanceCalculator.haversine(
        lat1: pos.lat,
        lng1: pos.lng,
        lat2: item.latitude!,
        lng2: item.longitude!,
      ).round();
      return item.copyWith(distanceMeters: distance);
    }).toList(growable: false);

    final sorted = withDistance.toList();
    sorted.sort((a, b) {
      final aHasDistance = a.distanceMeters != null;
      final bHasDistance = b.distanceMeters != null;
      if (aHasDistance != bHasDistance) return aHasDistance ? -1 : 1;
      if (aHasDistance && bHasDistance) {
        final cmpDistance = a.distanceMeters!.compareTo(b.distanceMeters!);
        if (cmpDistance != 0) return cmpDistance;
      }
      final cmpBoost = b.sortBoost.compareTo(a.sortBoost);
      if (cmpBoost != 0) return cmpBoost;
      return a.merchantName
          .toLowerCase()
          .compareTo(b.merchantName.toLowerCase());
    });
    return sorted;
  }

  PharmacyZone? _resolveInitialZone({
    required List<PharmacyZone> zones,
    required ({double lat, double lng})? userPosition,
  }) {
    if (zones.isEmpty) return null;
    if (userPosition == null) return zones.first;
    PharmacyZone? nearest;
    var nearestDistance = double.infinity;
    for (final zone in zones) {
      if (zone.centroidLat == null || zone.centroidLng == null) continue;
      final distance = DistanceCalculator.haversine(
        lat1: userPosition.lat,
        lng1: userPosition.lng,
        lat2: zone.centroidLat!,
        lng2: zone.centroidLng!,
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = zone;
      }
    }
    return nearest ?? zones.first;
  }
}

final pharmacyDutyRepositoryProvider = Provider<PharmacyDutyRepository>((ref) {
  return PharmacyDutyRepository();
});

final pharmacyZonesRepositoryProvider = Provider<ZonesRepository>((ref) {
  return ZonesRepository();
});

final pharmacyGeoLocationServiceProvider = Provider<GeoLocationService>((ref) {
  return GeoLocationService();
});

final pharmacyDutyAnalyticsProvider =
    Provider<PharmacyDutyAnalyticsSink>((ref) {
  return FirebasePharmacyDutyAnalytics();
});

final pharmacyDutyProvider =
    StateNotifierProvider.autoDispose<PharmacyDutyNotifier, PharmacyDutyState>(
  (ref) => PharmacyDutyNotifier(
    dutyRepository: ref.watch(pharmacyDutyRepositoryProvider),
    zonesRepository: ref.watch(pharmacyZonesRepositoryProvider),
    geoLocationService: ref.watch(pharmacyGeoLocationServiceProvider),
    analytics: ref.watch(pharmacyDutyAnalyticsProvider),
  ),
);
