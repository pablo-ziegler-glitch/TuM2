import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/providers/analytics_provider.dart';
import '../analytics/search_analytics.dart';
import '../models/merchant_search_item.dart';
import '../models/search_filters.dart';
import '../models/search_zone_item.dart';
import '../repositories/merchant_search_repository.dart';
import '../repositories/zone_search_repository.dart';
import 'search_history_provider.dart';

const _kSearchRealDataEnabled =
    bool.fromEnvironment('SEARCH_REAL_DATA_ENABLED', defaultValue: true);
const _kProviderKeepAliveTtl = Duration(minutes: 5);

const _kExcludedCategoryTokens = <String>{
  'panaderia',
  'panadería',
  'confiteria',
  'confitería',
  'bakery',
};

const _kVerificationRank = <String, int>{
  'verified': 6,
  'validated': 5,
  'claimed': 4,
  'referential': 3,
  'community_submitted': 2,
  'unverified': 1,
};

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
    this.userPosition,
    this.error,
    this.lastEmptyStateSignature,
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
  final ({double lat, double lng})? userPosition;
  final Object? error;
  final String? lastEmptyStateSignature;

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
    ({double lat, double lng})? userPosition,
    bool clearUserPosition = false,
    Object? error,
    bool clearError = false,
    String? lastEmptyStateSignature,
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
          : (selectedMerchantId ?? this.selectedMerchantId),
      userPosition:
          clearUserPosition ? null : (userPosition ?? this.userPosition),
      error: clearError ? null : (error ?? this.error),
      lastEmptyStateSignature:
          lastEmptyStateSignature ?? this.lastEmptyStateSignature,
    );
  }

  factory SearchState.initial() => const SearchState();
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(
    this._ref, {
    MerchantSearchDataSource? repository,
    ZoneSearchDataSource? zoneRepository,
    SearchAnalyticsSink? analytics,
    Future<({double lat, double lng})?> Function()? userPositionResolver,
    Duration debounceDuration = const Duration(milliseconds: 250),
  })  : _repository = repository ?? MerchantSearchRepository(),
        _zoneRepository = zoneRepository ?? ZoneSearchRepository(),
        _analytics = analytics ?? NoopSearchAnalytics(),
        _userPositionResolver = userPositionResolver ?? _resolveUserPosition,
        _debounceDuration = debounceDuration,
        super(SearchState.initial());

  final Ref _ref;
  final MerchantSearchDataSource _repository;
  final ZoneSearchDataSource _zoneRepository;
  final SearchAnalyticsSink _analytics;
  final Future<({double lat, double lng})?> Function() _userPositionResolver;
  final Duration _debounceDuration;

  final Map<String, List<MerchantSearchItem>> _zoneCache =
      <String, List<MerchantSearchItem>>{};
  Timer? _debounce;

  Future<void> ensureInitialized() async {
    if (state.initialized) return;

    state = state.copyWith(isLoading: true, clearError: true);
    await _ref.read(searchHistoryProvider.notifier).load();

    try {
      final zones = await _zoneRepository.fetchAvailableZones();
      final activeZoneId = state.activeZoneId.isNotEmpty
          ? state.activeZoneId
          : (zones.isEmpty ? '' : zones.first.zoneId);
      state = state.copyWith(
        zones: zones,
        activeZoneId: activeZoneId,
      );

      await _bestEffortLoadPosition();
      if (activeZoneId.isNotEmpty) {
        await _loadZoneCorpus(zoneId: activeZoneId, forceRefresh: false);
        unawaited(_setActiveZonePropertyBestEffort(activeZoneId));
      } else {
        _applyDerivedState(
          state.copyWith(
            isLoading: false,
            corpus: const [],
            clearError: true,
          ),
        );
      }

      state = state.copyWith(initialized: true, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> setZone(String zoneId) async {
    final nextZoneId = zoneId.trim();
    if (nextZoneId.isEmpty) return;
    if (nextZoneId == state.activeZoneId && state.corpus.isNotEmpty) return;

    if (state.zones.isEmpty) {
      await _refreshZonesBestEffort();
    }

    state = state.copyWith(
      activeZoneId: nextZoneId,
      clearError: true,
      clearSelectedMerchant: true,
    );
    await _loadZoneCorpus(zoneId: nextZoneId, forceRefresh: false);
    unawaited(_setActiveZonePropertyBestEffort(nextZoneId));
  }

  Future<void> loadCorpus() async {
    if (state.activeZoneId.isEmpty) return;
    await _loadZoneCorpus(
      zoneId: state.activeZoneId,
      forceRefresh: true,
    );
  }

  void setQuery(String query) {
    final normalized = query.trim();
    state = state.copyWith(query: normalized, clearError: true);
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _applySearch);
  }

  Future<void> submitQuery([String? value]) async {
    final query = (value ?? state.query).trim();
    if (query.isEmpty) return;

    _debounce?.cancel();
    if (query != state.query) {
      state = state.copyWith(query: query, clearError: true);
    }
    _applySearch();

    await _ref.read(searchHistoryProvider.notifier).add(query);
    unawaited(_analytics.logSearchPerformed(
      surface: state.showMap ? 'search_map' : 'search_results',
      activeZoneId: state.activeZoneId,
      queryLength: _normalize(query).length,
      resultsCount: state.results.length,
      usedCategoryFilter: (state.filters.categoryId ?? '').isNotEmpty,
      usedOpenNowFilter: state.filters.isOpenNow,
      usedDistanceSort: state.filters.sortBy == SearchSortBy.distance,
      resolvedLocally: state.results.isNotEmpty,
    ));
  }

  Future<void> clearHistory() async {
    await _ref.read(searchHistoryProvider.notifier).clear();
  }

  void setFilters(SearchFilters filters) {
    final previousCategoryId = state.filters.categoryId;
    state = state.copyWith(filters: filters, clearError: true);
    _applySearch();
    final categoryId = (filters.categoryId ?? '').trim();
    if (categoryId.isNotEmpty &&
        categoryId != (previousCategoryId ?? '').trim()) {
      unawaited(
        _analytics.logCategoryFiltered(
          surface: state.showMap ? 'search_map' : 'search_results',
          categoryId: categoryId,
          activeZoneId: state.activeZoneId,
          resultCount: state.results.length,
          usedOpenNowFilter: filters.isOpenNow,
          usedDistanceSort: filters.sortBy == SearchSortBy.distance,
        ),
      );
    }
  }

  void setShowMap(bool value) {
    if (state.showMap == value) return;
    state = state.copyWith(showMap: value);
  }

  void toggleMap() {
    setShowMap(!state.showMap);
  }

  void selectMerchant(String merchantId) {
    state = state.copyWith(selectedMerchantId: merchantId);
  }

  void clearSelectedMerchant() {
    state = state.copyWith(clearSelectedMerchant: true);
  }

  void logResultOpened({
    required String merchantId,
    required bool fromMap,
  }) {
    if (!fromMap) return;
    final item = state.results
        .where((candidate) => candidate.merchantId == merchantId)
        .cast<MerchantSearchItem?>()
        .firstWhere((candidate) => candidate != null, orElse: () => null);
    if (item == null) return;
    unawaited(
      _analytics.logMapPinSelected(
        surface: 'search_map',
        activeZoneId: state.activeZoneId,
        entityZoneId: item.zoneId,
        distanceBucket: _ref
            .read(analyticsServiceProvider)
            .distanceBucket(item.distanceMeters),
      ),
    );
  }

  void logMapViewed() {
    unawaited(
      _analytics.logMapViewed(
        surface: 'search_map',
        activeZoneId: state.activeZoneId,
        resultCount: state.results.length,
      ),
    );
  }

  void logMapRecenterTapped() {
    unawaited(
      _analytics.logMapRecenterTapped(
        surface: 'search_map',
        activeZoneId: state.activeZoneId,
      ),
    );
  }

  void logMapSearchThisAreaTapped() {
    unawaited(
      _analytics.logMapSearchThisAreaTapped(
        surface: 'search_map',
        activeZoneId: state.activeZoneId,
      ),
    );
  }

  Future<void> _refreshZonesBestEffort() async {
    try {
      final zones = await _zoneRepository.fetchAvailableZones();
      if (zones.isNotEmpty) {
        state = state.copyWith(zones: zones);
      }
    } catch (_) {
      // Best effort: los errores de zona no deben bloquear interacción local.
    }
  }

  Future<void> _bestEffortLoadPosition() async {
    try {
      final resolved = await _userPositionResolver();
      if (resolved == null) return;
      state = state.copyWith(userPosition: resolved);
    } catch (_) {
      // Best effort: búsqueda debe funcionar sin ubicación.
    }
  }

  Future<void> _loadZoneCorpus({
    required String zoneId,
    required bool forceRefresh,
  }) async {
    if (zoneId.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final fromCache = _zoneCache[zoneId];
      final rawCorpus = !forceRefresh && fromCache != null
          ? fromCache
          : await _fetchRawCorpus(zoneId: zoneId);

      final cleanedCorpus = _removeExcludedCategories(rawCorpus);
      _zoneCache[zoneId] = cleanedCorpus;

      _applyDerivedState(
        state.copyWith(
          isLoading: false,
          corpus: cleanedCorpus,
          clearError: true,
        ),
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<List<MerchantSearchItem>> _fetchRawCorpus({
    required String zoneId,
  }) async {
    if (!_kSearchRealDataEnabled) {
      return _fallbackCorpus(zoneId);
    }
    return _repository.fetchZoneCorpus(zoneId);
  }

  void _applySearch() {
    _applyDerivedState(state);
  }

  void _applyDerivedState(SearchState snapshot) {
    final resultSet = _filterAndRankResults(
      corpus: snapshot.corpus,
      query: snapshot.query,
      filters: snapshot.filters,
      userPosition: snapshot.userPosition,
    );

    final normalizedQuery = _normalize(snapshot.query);
    final suggestions = _buildSuggestions(resultSet, normalizedQuery);
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
    required ({double lat, double lng})? userPosition,
  }) {
    final normalizedQuery = _normalize(query);
    final queryTokens = _normalizeAndTokenize(query);
    final minVerificationRank =
        _verificationRank(filters.minVerificationStatus);

    final filtered = <MerchantSearchItem>[];
    for (final item in corpus) {
      if (!_isVisibleStatus(item.visibilityStatus)) continue;

      if (filters.categoryId != null && filters.categoryId != item.categoryId) {
        continue;
      }
      if (filters.isOpenNow && item.isOpenNow != true) {
        continue;
      }
      if (_verificationRank(item.verificationStatus) < minVerificationRank) {
        continue;
      }
      if (normalizedQuery.length >= 3 && !_matchesQuery(item, queryTokens)) {
        continue;
      }

      filtered.add(_withDistance(item, userPosition: userPosition));
    }

    _sortResults(filtered, filters.sortBy);
    return filtered;
  }

  bool _matchesQuery(MerchantSearchItem item, List<String> queryTokens) {
    if (queryTokens.isEmpty) return true;

    final keywordTokens = <String>{
      ..._normalizeAndTokenize(item.name),
      ..._normalizeAndTokenize(item.categoryLabel),
      ..._normalizeAndTokenize(item.address),
      for (final keyword in item.searchKeywords)
        ..._normalizeAndTokenize(keyword),
    };

    for (final queryToken in queryTokens) {
      final matches = keywordTokens.any(
        (token) => token.startsWith(queryToken) || token.contains(queryToken),
      );
      if (!matches) return false;
    }
    return true;
  }

  List<MerchantSearchItem> _buildSuggestions(
    List<MerchantSearchItem> items,
    String normalizedQuery,
  ) {
    if (normalizedQuery.length < 3) return const <MerchantSearchItem>[];
    return items.take(8).toList(growable: false);
  }

  void _sortResults(List<MerchantSearchItem> items, SearchSortBy sortBy) {
    int byRelevance(MerchantSearchItem a, MerchantSearchItem b) {
      final byBoost = b.sortBoost.compareTo(a.sortBoost);
      if (byBoost != 0) return byBoost;

      final byVerification = _verificationRank(b.verificationStatus)
          .compareTo(_verificationRank(a.verificationStatus));
      if (byVerification != 0) return byVerification;

      final byOpen = _boolRank(b.isOpenNow).compareTo(_boolRank(a.isOpenNow));
      if (byOpen != 0) return byOpen;

      final byDistance = (a.distanceMeters ?? double.infinity)
          .compareTo(b.distanceMeters ?? double.infinity);
      if (byDistance != 0) return byDistance;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }

    switch (sortBy) {
      case SearchSortBy.name:
        items.sort((a, b) {
          final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (byName != 0) return byName;
          return byRelevance(a, b);
        });
        break;
      case SearchSortBy.distance:
        items.sort((a, b) {
          final byDistance = (a.distanceMeters ?? double.infinity)
              .compareTo(b.distanceMeters ?? double.infinity);
          if (byDistance != 0) return byDistance;
          return byRelevance(a, b);
        });
        break;
      case SearchSortBy.sortBoost:
        items.sort(byRelevance);
        break;
    }
  }

  int _boolRank(bool? value) => value == true ? 1 : 0;

  int _verificationRank(String? status) {
    if (status == null || status.trim().isEmpty) return 0;
    return _kVerificationRank[status] ?? 0;
  }

  MerchantSearchItem _withDistance(
    MerchantSearchItem item, {
    required ({double lat, double lng})? userPosition,
  }) {
    if (userPosition == null || item.lat == null || item.lng == null) {
      return item;
    }
    final meters = Geolocator.distanceBetween(
      userPosition.lat,
      userPosition.lng,
      item.lat!,
      item.lng!,
    );
    return item.copyWith(distanceMeters: meters);
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

  bool _isVisibleStatus(String visibilityStatus) {
    return visibilityStatus == 'visible' ||
        visibilityStatus == 'review_pending';
  }

  Future<void> _setActiveZonePropertyBestEffort(String zoneId) async {
    try {
      await _ref.read(analyticsServiceProvider).setActiveZoneId(zoneId);
    } catch (_) {
      // En tests/sandbox sin Firebase inicializado no bloqueamos búsqueda.
    }
  }

  List<MerchantSearchItem> _fallbackCorpus(String zoneId) {
    return <MerchantSearchItem>[
      MerchantSearchItem(
        merchantId: 'fallback-farmacia-1',
        name: 'Farmacia Central',
        categoryId: 'pharmacy',
        categoryLabel: 'Farmacia',
        zoneId: zoneId,
        address: 'Av. Principal 123',
        lat: -34.603722,
        lng: -58.381592,
        verificationStatus: 'validated',
        visibilityStatus: 'visible',
        isOpenNow: true,
        openStatusLabel: 'Abierto',
        sortBoost: 30,
        searchKeywords: const <String>[
          'farmacia',
          'medicamentos',
          'central',
        ],
      ),
      MerchantSearchItem(
        merchantId: 'fallback-kiosco-1',
        name: 'Kiosco 24',
        categoryId: 'kiosk',
        categoryLabel: 'Kiosco',
        zoneId: zoneId,
        address: 'Calle 9 456',
        lat: -34.602722,
        lng: -58.380592,
        verificationStatus: 'claimed',
        visibilityStatus: 'visible',
        isOpenNow: false,
        openStatusLabel: 'Cerrado',
        sortBoost: 20,
        searchKeywords: const <String>[
          'kiosco',
          'bebidas',
          'snacks',
        ],
      ),
    ];
  }

  static Future<({double lat, double lng})?> _resolveUserPosition() async {
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
      return (
        lat: current.latitude,
        lng: current.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

List<String> _normalizeAndTokenize(String input) {
  if (input.trim().isEmpty) return const <String>[];
  return _normalize(input)
      .split(' ')
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

String _normalize(String input) {
  final lower = input.toLowerCase().trim();
  if (lower.isEmpty) return '';

  const accents = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  final buffer = StringBuffer();
  for (final codePoint in lower.runes) {
    final char = String.fromCharCode(codePoint);
    buffer.write(accents[char] ?? char);
  }

  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

final merchantSearchRepositoryProvider = Provider<MerchantSearchDataSource>(
  (ref) => MerchantSearchRepository(),
);

final zoneSearchRepositoryProvider = Provider<ZoneSearchDataSource>(
  (ref) => ZoneSearchRepository(),
);

final searchAnalyticsProvider = Provider<SearchAnalyticsSink>(
  (ref) => AnalyticsServiceSearchAnalytics(ref.watch(analyticsServiceProvider)),
);

final searchNotifierProvider =
    StateNotifierProvider.autoDispose<SearchNotifier, SearchState>((ref) {
  final link = ref.keepAlive();
  Timer? disposeTimer;

  void scheduleDispose() {
    disposeTimer?.cancel();
    disposeTimer = Timer(_kProviderKeepAliveTtl, link.close);
  }

  ref.onCancel(scheduleDispose);
  ref.onResume(() {
    disposeTimer?.cancel();
  });
  ref.onDispose(() {
    disposeTimer?.cancel();
  });

  return SearchNotifier(
    ref,
    repository: ref.watch(merchantSearchRepositoryProvider),
    zoneRepository: ref.watch(zoneSearchRepositoryProvider),
    analytics: ref.watch(searchAnalyticsProvider),
  );
});
