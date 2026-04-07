import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/analytics/search_analytics.dart';
import '../models/merchant_search_item.dart';
import '../models/search_filters.dart';
import '../models/search_zone_item.dart';
import '../repositories/merchant_search_repository.dart';
import '../repositories/zone_search_repository.dart';
import 'search_history_provider.dart';

const _kSearchRealDataEnabled =
    bool.fromEnvironment('SEARCH_REAL_DATA_ENABLED', defaultValue: true);

const _kExcludedCategoryTokens = {
  'panaderia',
  'panadería',
  'confiteria',
  'confitería',
  'bakery',
};

const _kVerificationRank = {
  'verified': 6,
  'validated': 5,
  'claimed': 4,
  'referential': 3,
  'community_submitted': 2,
  'unverified': 1,
};

final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(
    ref: ref,
    merchantRepository: MerchantSearchRepository(),
    zoneRepository: ZoneSearchRepository(),
  );
});

class SearchState {
  const SearchState({
    this.initialized = false,
    this.isLoading = false,
    this.activeZoneId = '',
    this.zones = const [],
    this.query = '',
    this.filters = SearchFilters.empty,
    this.corpus = const [],
    this.results = const [],
    this.suggestions = const [],
    this.showMap = false,
    this.selectedMerchantId,
    this.hasLocationPermission = false,
    this.userLatitude,
    this.userLongitude,
    this.error,
  });

  final bool initialized;
  final bool isLoading;
  final String activeZoneId;
  final List<SearchZoneItem> zones;
  final String query;
  final SearchFilters filters;
  final List<MerchantSearchItem> corpus;
  final List<MerchantSearchItem> results;
  final List<MerchantSearchItem> suggestions;
  final bool showMap;
  final String? selectedMerchantId;
  final bool hasLocationPermission;
  final double? userLatitude;
  final double? userLongitude;
  final Object? error;

  SearchState copyWith({
    bool? initialized,
    bool? isLoading,
    String? activeZoneId,
    List<SearchZoneItem>? zones,
    String? query,
    SearchFilters? filters,
    List<MerchantSearchItem>? corpus,
    List<MerchantSearchItem>? results,
    List<MerchantSearchItem>? suggestions,
    bool? showMap,
    String? selectedMerchantId,
    bool clearSelectedMerchant = false,
    bool? hasLocationPermission,
    double? userLatitude,
    double? userLongitude,
    bool clearUserLocation = false,
    Object? error,
    bool clearError = false,
  }) {
    return SearchState(
      initialized: initialized ?? this.initialized,
      isLoading: isLoading ?? this.isLoading,
      activeZoneId: activeZoneId ?? this.activeZoneId,
      zones: zones ?? this.zones,
      query: query ?? this.query,
      filters: filters ?? this.filters,
      corpus: corpus ?? this.corpus,
      results: results ?? this.results,
      suggestions: suggestions ?? this.suggestions,
      showMap: showMap ?? this.showMap,
      selectedMerchantId: clearSelectedMerchant
          ? null
          : selectedMerchantId ?? this.selectedMerchantId,
      hasLocationPermission:
          hasLocationPermission ?? this.hasLocationPermission,
      userLatitude:
          clearUserLocation ? null : userLatitude ?? this.userLatitude,
      userLongitude:
          clearUserLocation ? null : userLongitude ?? this.userLongitude,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier({
    required this.ref,
    required MerchantSearchSource merchantRepository,
    required ZoneSearchSource zoneRepository,
    Future<_SearchPosition?> Function()? userPositionResolver,
  })  : _merchantRepository = merchantRepository,
        _zoneRepository = zoneRepository,
        _userPositionResolver = userPositionResolver ?? _resolveUserPosition,
        super(const SearchState());

  final Ref ref;
  final MerchantSearchSource _merchantRepository;
  final ZoneSearchSource _zoneRepository;
  final Future<_SearchPosition?> Function() _userPositionResolver;

  final Map<String, List<MerchantSearchItem>> _zoneCache = {};
  DateTime? _queryStartedAt;

  Future<void> ensureInitialized() async {
    if (state.initialized) return;
    state = state.copyWith(isLoading: true, clearError: true);
    SearchAnalytics.logScreenView().ignore();

    try {
      final position = await _userPositionResolver();
      if (position != null) {
        state = state.copyWith(
          hasLocationPermission: true,
          userLatitude: position.latitude,
          userLongitude: position.longitude,
        );
      }

      final zones = await _zoneRepository.fetchAvailableZones();
      if (zones.isEmpty) {
        throw StateError('No hay zonas disponibles.');
      }

      final firstZone = zones.first.zoneId;
      state = state.copyWith(
        zones: zones,
        activeZoneId: firstZone,
      );

      await _loadZoneCorpus(zoneId: firstZone, forceRefresh: false);
      state = state.copyWith(initialized: true, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
      SearchAnalytics.logError(
        zoneId: state.activeZoneId,
        code: 'init_failed',
      ).ignore();
    }
  }

  Future<void> setZone(String zoneId) async {
    if (zoneId.trim().isEmpty || zoneId == state.activeZoneId) return;
    state = state.copyWith(
      activeZoneId: zoneId,
      clearError: true,
      clearSelectedMerchant: true,
    );
    SearchAnalytics.logZoneSelected(zoneId: zoneId).ignore();
    await _loadZoneCorpus(zoneId: zoneId, forceRefresh: false);
  }

  Future<void> loadCorpus() async {
    if (state.activeZoneId.isEmpty) return;
    await _loadZoneCorpus(zoneId: state.activeZoneId, forceRefresh: true);
  }

  Future<void> _loadZoneCorpus({
    required String zoneId,
    required bool forceRefresh,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final fromCache = _zoneCache[zoneId];
      final rawCorpus = !forceRefresh && fromCache != null
          ? fromCache
          : await _fetchRawCorpus(zoneId: zoneId);

      final cleanedCorpus = _removeExcludedCategories(rawCorpus);
      _zoneCache[zoneId] = cleanedCorpus;
      _queryStartedAt = DateTime.now();

      _applyDerivedState(
        state.copyWith(
          isLoading: false,
          corpus: cleanedCorpus,
          clearError: true,
        ),
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
      SearchAnalytics.logError(
        zoneId: zoneId,
        code: 'load_corpus_failed',
      ).ignore();
    }
  }

  Future<List<MerchantSearchItem>> _fetchRawCorpus({
    required String zoneId,
  }) async {
    if (!_kSearchRealDataEnabled) {
      return _fallbackCorpus(zoneId);
    }
    return _merchantRepository.fetchZoneCorpus(zoneId: zoneId);
  }

  void setQuery(String value) {
    final query = value.trim();
    state = state.copyWith(query: query, clearError: true);
    SearchAnalytics.logQueryChanged(
      zoneId: state.activeZoneId,
      queryLength: query.length,
    ).ignore();
    _applyDerivedState(state);
  }

  Future<void> submitQuery(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    setQuery(query);
    ref.read(searchHistoryProvider.notifier).addTerm(query);
    _queryStartedAt ??= DateTime.now();
    _logResultsState();
  }

  void setFilters(SearchFilters filters) {
    state = state.copyWith(filters: filters, clearError: true);
    if (filters.categoryId != null && filters.categoryId!.isNotEmpty) {
      SearchAnalytics.logCategoryFilter(categoryId: filters.categoryId!)
          .ignore();
    }
    SearchAnalytics.logOpenNowFilter(openNowOnly: filters.isOpenNow).ignore();
    _applyDerivedState(state);
    _logResultsState();
  }

  void toggleMap() {
    final nextValue = !state.showMap;
    state = state.copyWith(showMap: nextValue);
    if (nextValue) {
      SearchAnalytics.logSwitchedToMap(zoneId: state.activeZoneId).ignore();
    }
  }

  void setShowMap(bool value) {
    state = state.copyWith(showMap: value);
  }

  void selectMerchant(String merchantId) {
    state = state.copyWith(selectedMerchantId: merchantId);
  }

  void clearHistory() {
    ref.read(searchHistoryProvider.notifier).clear();
  }

  void logResultOpened({
    required String merchantId,
    required bool fromMap,
  }) {
    SearchAnalytics.logResultClicked(
      zoneId: state.activeZoneId,
      merchantId: merchantId,
      viewMode: fromMap ? 'map' : 'list',
    ).ignore();
  }

  void _applyDerivedState(SearchState snapshot) {
    final resultSet = _filterAndRankResults(
      corpus: snapshot.corpus,
      query: snapshot.query,
      filters: snapshot.filters,
      userLatitude: snapshot.userLatitude,
      userLongitude: snapshot.userLongitude,
    );

    final suggestions = snapshot.query.isEmpty
        ? const <MerchantSearchItem>[]
        : resultSet.take(8).toList(growable: false);
    final selected = resultSet
            .where((item) => item.merchantId == snapshot.selectedMerchantId)
            .isNotEmpty
        ? snapshot.selectedMerchantId
        : (resultSet.isNotEmpty ? resultSet.first.merchantId : null);

    state = snapshot.copyWith(
      results: resultSet,
      suggestions: suggestions,
      selectedMerchantId: selected,
      clearSelectedMerchant: selected == null,
    );
  }

  List<MerchantSearchItem> _filterAndRankResults({
    required List<MerchantSearchItem> corpus,
    required String query,
    required SearchFilters filters,
    required double? userLatitude,
    required double? userLongitude,
  }) {
    final queryTokens = _normalizeAndTokenize(query);
    final minVerificationRank =
        _verificationRank(filters.minVerificationStatus);

    final filtered = <MerchantSearchItem>[];
    for (final item in corpus) {
      if (!item.isVisible) continue;
      if (filters.categoryId != null && filters.categoryId != item.categoryId) {
        continue;
      }
      if (filters.isOpenNow && item.isOpenNow != true) {
        continue;
      }
      if (_verificationRank(item.verificationStatus) < minVerificationRank) {
        continue;
      }
      if (queryTokens.isNotEmpty && !_matchesQuery(item, queryTokens)) {
        continue;
      }

      filtered.add(_withDistance(
        item,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      ));
    }

    filtered.sort((a, b) {
      final verification = _verificationRank(b.verificationStatus)
          .compareTo(_verificationRank(a.verificationStatus));
      if (verification != 0) return verification;

      final byOpenNow = (b.isOpenNow == true ? 1 : 0).compareTo(
        a.isOpenNow == true ? 1 : 0,
      );
      if (byOpenNow != 0) return byOpenNow;

      switch (filters.sortBy) {
        case SearchSortBy.distance:
          final byDistance = (a.distanceMeters ?? 999999)
              .compareTo(b.distanceMeters ?? 999999);
          if (byDistance != 0) return byDistance;
          break;
        case SearchSortBy.sortBoost:
          final byBoost = b.sortBoost.compareTo(a.sortBoost);
          if (byBoost != 0) return byBoost;
          break;
        case SearchSortBy.name:
          break;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  bool _matchesQuery(MerchantSearchItem item, List<String> queryTokens) {
    final keywordTokens = <String>{
      ...item.searchKeywords.expand(_normalizeAndTokenize),
      ..._normalizeAndTokenize(item.name),
      ..._normalizeAndTokenize(item.categoryLabel),
      ..._normalizeAndTokenize(item.addressSummary),
    };
    for (final queryToken in queryTokens) {
      final matches = keywordTokens.any(
        (token) => token.startsWith(queryToken) || token.contains(queryToken),
      );
      if (!matches) return false;
    }
    return true;
  }

  int _verificationRank(String? status) {
    if (status == null) return 0;
    return _kVerificationRank[status] ?? 0;
  }

  MerchantSearchItem _withDistance(
    MerchantSearchItem item, {
    required double? userLatitude,
    required double? userLongitude,
  }) {
    if (userLatitude == null ||
        userLongitude == null ||
        item.latitude == null ||
        item.longitude == null) {
      return item.copyWith(clearDistance: true);
    }

    final meters = Geolocator.distanceBetween(
      userLatitude,
      userLongitude,
      item.latitude!,
      item.longitude!,
    );
    return item.copyWith(distanceMeters: meters.round());
  }

  List<MerchantSearchItem> _removeExcludedCategories(
    List<MerchantSearchItem> corpus,
  ) {
    return corpus.where((item) {
      final categoryTokens = _normalizeAndTokenize(
        '${item.categoryId} ${item.categoryLabel}',
      ).toSet();
      return !_kExcludedCategoryTokens.any(categoryTokens.contains);
    }).toList(growable: false);
  }

  List<MerchantSearchItem> _fallbackCorpus(String zoneId) {
    return [
      MerchantSearchItem(
        merchantId: 'fallback-farmacia-1',
        name: 'Farmacia Central',
        categoryId: 'pharmacy',
        categoryLabel: 'Farmacia',
        zoneId: zoneId,
        visibilityStatus: 'visible',
        verificationStatus: 'validated',
        sortBoost: 30,
        searchKeywords: const ['farmacia', 'medicamentos', 'central'],
        addressSummary: 'Av. Principal 123',
        isOpenNow: true,
      ),
      MerchantSearchItem(
        merchantId: 'fallback-kiosco-1',
        name: 'Kiosco 24',
        categoryId: 'kiosk',
        categoryLabel: 'Kiosco',
        zoneId: zoneId,
        visibilityStatus: 'visible',
        verificationStatus: 'claimed',
        sortBoost: 20,
        searchKeywords: const ['kiosco', 'bebidas', 'snacks'],
        addressSummary: 'Calle 9 456',
        isOpenNow: false,
      ),
    ];
  }

  void _logResultsState() {
    final queryStart = _queryStartedAt ?? DateTime.now();
    final ttfr = DateTime.now().difference(queryStart).inMilliseconds;
    SearchAnalytics.logResultsLoaded(
      zoneId: state.activeZoneId,
      resultsCount: state.results.length,
      ttfrMs: ttfr,
      hasLocationPermission: state.hasLocationPermission,
      viewMode: state.showMap ? 'map' : 'list',
    ).ignore();
    if (state.results.isEmpty) {
      SearchAnalytics.logNoResults(zoneId: state.activeZoneId).ignore();
    }
  }

  static Future<_SearchPosition?> _resolveUserPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      var resolvedPermission = permission;
      if (permission == LocationPermission.denied) {
        resolvedPermission = await Geolocator.requestPermission();
      }
      if (resolvedPermission == LocationPermission.denied ||
          resolvedPermission == LocationPermission.deniedForever) {
        return null;
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 3));
      return _SearchPosition(
        latitude: current.latitude,
        longitude: current.longitude,
      );
    } catch (_) {
      return null;
    }
  }
}

List<String> _normalizeAndTokenize(String input) {
  if (input.trim().isEmpty) return const [];
  final normalized = input
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'\s+'), ' ');
  return normalized
      .split(' ')
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

class _SearchPosition {
  const _SearchPosition({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}
