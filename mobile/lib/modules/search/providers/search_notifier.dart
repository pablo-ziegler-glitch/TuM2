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
import '../analytics/search_analytics.dart';
import '../models/merchant_search_item.dart';
import '../models/search_filters.dart';
import '../repositories/merchant_search_repository.dart';
import '../repositories/zone_search_repository.dart';
import 'search_history_provider.dart';

enum SearchViewMode { list, map }

class SearchState {
  final List<MerchantSearchItem> corpus;
  final List<MerchantSearchItem> suggestions;
  final List<MerchantSearchItem> results;
  final String query;
  final SearchFilters filters;
  final String activeZoneId;
  final bool isLoading;
  final Object? error;
  final ({double lat, double lng})? userPosition;
  final bool hasInitialized;
  final SearchViewMode viewMode;
  final String? selectedMerchantId;
  final String? lastEmptyStateSignature;

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
    required this.corpus,
    required this.suggestions,
    required this.results,
    required this.query,
    required this.filters,
    required this.activeZoneId,
    required this.isLoading,
    required this.error,
    required this.userPosition,
    required this.hasInitialized,
    required this.viewMode,
    required this.selectedMerchantId,
    required this.lastEmptyStateSignature,
  });

  factory SearchState.initial() => const SearchState(
        corpus: [],
        suggestions: [],
        results: [],
        query: '',
        filters: SearchFilters.empty,
        activeZoneId: '',
        isLoading: false,
        error: null,
        userPosition: null,
        hasInitialized: false,
        viewMode: SearchViewMode.list,
        selectedMerchantId: null,
        lastEmptyStateSignature: null,
      );

  bool get showMap => viewMode == SearchViewMode.map;

  SearchState copyWith({
    List<MerchantSearchItem>? corpus,
    List<MerchantSearchItem>? suggestions,
    List<MerchantSearchItem>? results,
    String? query,
    SearchFilters? filters,
    String? activeZoneId,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    ({double lat, double lng})? userPosition,
    bool clearUserPosition = false,
    bool? hasInitialized,
    SearchViewMode? viewMode,
    String? selectedMerchantId,
    bool clearSelectedMerchant = false,
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
          : selectedMerchantId ?? this.selectedMerchantId,
      hasLocationPermission:
          hasLocationPermission ?? this.hasLocationPermission,
      userLatitude:
          clearUserLocation ? null : userLatitude ?? this.userLatitude,
      userLongitude:
          clearUserLocation ? null : userLongitude ?? this.userLongitude,
      corpus: corpus ?? this.corpus,
      suggestions: suggestions ?? this.suggestions,
      results: results ?? this.results,
      query: query ?? this.query,
      filters: filters ?? this.filters,
      activeZoneId: activeZoneId ?? this.activeZoneId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      userPosition:
          clearUserPosition ? null : (userPosition ?? this.userPosition),
      hasInitialized: hasInitialized ?? this.hasInitialized,
      viewMode: viewMode ?? this.viewMode,
      selectedMerchantId: clearSelectedMerchant
          ? null
          : (selectedMerchantId ?? this.selectedMerchantId),
      lastEmptyStateSignature:
          lastEmptyStateSignature ?? this.lastEmptyStateSignature,
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
  SearchNotifier(
    this._ref, {
    MerchantSearchDataSource? repository,
    ZoneSearchDataSource? zoneRepository,
    SearchAnalyticsSink? analytics,
  })  : _repository = repository ?? MerchantSearchRepository(),
        _zoneRepository = zoneRepository ?? ZoneSearchRepository(),
        _analytics = analytics ?? FirebaseSearchAnalytics(),
        super(SearchState.initial());

  final Ref _ref;
  final MerchantSearchDataSource _repository;
  final ZoneSearchDataSource _zoneRepository;
  final SearchAnalyticsSink _analytics;
  Timer? _debounce;

  static const _debounceDuration = Duration(milliseconds: 250);

  Future<void> ensureInitialized() async {
    if (state.hasInitialized) return;
    await _ref.read(searchHistoryProvider.notifier).load();
    if (state.activeZoneId.isEmpty) {
      try {
        final zones = await _zoneRepository.fetchAvailableZones();
        if (zones.isNotEmpty) {
          state = state.copyWith(activeZoneId: zones.first.zoneId);
        }
      } catch (_) {}
    }
    await _bestEffortLoadPosition();
    await loadCorpus();
    state = state.copyWith(hasInitialized: true);
  }

  Future<void> _bestEffortLoadPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      state = state.copyWith(
        userPosition: (lat: position.latitude, lng: position.longitude),
      );
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> loadCorpus() async {
    if (state.activeZoneId.isEmpty) return;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSelectedMerchant: true,
    );
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
      final items = await _repository.fetchZoneCorpus(state.activeZoneId);
      state = state.copyWith(corpus: items, isLoading: false);
      _applySearch();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _applySearch);
  }

  Future<void> submitQuery([String? value]) async {
    final query = (value ?? state.query).trim();
    if (query.isEmpty) return;
    state = state.copyWith(query: query);
    await _ref.read(searchHistoryProvider.notifier).add(query);
    _applySearch();
    unawaited(_analytics.logQuerySubmitted(
      queryLength: _normalize(query).length,
      zoneId: state.activeZoneId,
      hasFilters: _hasAnyFilter(state.filters),
      resultsCount: state.results.length,
    ));
  }

  Future<void> clearHistory() async {
    await _ref.read(searchHistoryProvider.notifier).clear();
  }

  void setFilters(SearchFilters filters) {
    state = state.copyWith(filters: filters);
    _applySearch();
    unawaited(_analytics.logFilterApplied(
      isOpenNow: filters.isOpenNow,
      hasCategory: (filters.categoryId ?? '').isNotEmpty,
      hasMinVerification: (filters.minVerificationStatus ?? '').isNotEmpty,
      sortBy: filters.sortBy.name,
    ));
  }

  Future<void> setZone(String zoneId) async {
    if (zoneId == state.activeZoneId) return;
    final previousZoneId = state.activeZoneId;
    state = state.copyWith(activeZoneId: zoneId, corpus: const []);
    await loadCorpus();
    unawaited(_analytics.logZoneChanged(
      fromZoneId: previousZoneId,
      toZoneId: zoneId,
    ));
  }

  void setViewMode(SearchViewMode viewMode) {
    if (state.viewMode == viewMode) return;
    state = state.copyWith(viewMode: viewMode);
    unawaited(_analytics.logMapToggled(
      mapEnabled: viewMode == SearchViewMode.map,
      resultsCount: state.results.length,
    ));
  }

  void toggleMap() {
    setViewMode(state.showMap ? SearchViewMode.list : SearchViewMode.map);
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
    final index =
        state.results.indexWhere((item) => item.merchantId == merchantId);
    final rank = index < 0 ? -1 : index + 1;
    unawaited(_analytics.logResultOpened(
      merchantId: merchantId,
      fromMap: fromMap,
      rank: rank,
    ));
  }

  void _applySearch() {
    final normalizedQuery = _normalize(state.query);
    var filtered = List<MerchantSearchItem>.from(state.corpus);

    final categoryId = state.filters.categoryId;
    if (categoryId != null && categoryId.isNotEmpty) {
      filtered =
          filtered.where((item) => item.categoryId == categoryId).toList();
    }
    if (state.filters.isOpenNow) {
      filtered = filtered.where((item) => item.isOpenNow == true).toList();
    }
    final minVerification = state.filters.minVerificationStatus;
    if (minVerification != null && minVerification.isNotEmpty) {
      final minRank = _verificationRank(minVerification);
      filtered = filtered
          .where(
              (item) => _verificationRank(item.verificationStatus) >= minRank)
          .toList();
    }

    if (normalizedQuery.length >= 3) {
      filtered = filtered
          .where((item) => _matchesQuery(item, normalizedQuery))
          .toList();
    }

    final withDistance = filtered.map(_hydrateDistance).toList();
    _sortResults(withDistance, state.filters.sortBy);

    final suggestions = _buildSuggestions(withDistance, normalizedQuery);
    final selectedMerchantId = state.selectedMerchantId;
    final selectedStillExists = selectedMerchantId != null &&
        withDistance.any((item) => item.merchantId == selectedMerchantId);
    final fallbackSelectedId =
        withDistance.isEmpty ? null : withDistance.first.merchantId;
    final nextSelectedId =
        selectedStillExists ? selectedMerchantId : fallbackSelectedId;

    state = state.copyWith(
      results: withDistance,
      suggestions: suggestions,
      clearError: true,
      selectedMerchantId: nextSelectedId,
    );

    _trackEmptyState();
  }

  MerchantSearchItem _hydrateDistance(MerchantSearchItem item) {
    final pos = state.userPosition;
    if (pos == null || item.lat == null || item.lng == null) return item;
    final meters = Geolocator.distanceBetween(
      pos.lat,
      pos.lng,
      item.lat!,
      item.lng!,
    );
    return item.copyWith(distanceMeters: meters);
  }

  bool _matchesQuery(MerchantSearchItem item, String normalizedQuery) {
    final normalizedName = _normalize(item.name);
    if (normalizedName.contains(normalizedQuery)) return true;
    for (final keyword in item.searchKeywords) {
      final normalizedKeyword = _normalize(keyword);
      if (normalizedKeyword.startsWith(normalizedQuery) ||
          normalizedKeyword.contains(normalizedQuery)) {
        return true;
      }
    }
    return false;
  }

  List<MerchantSearchItem> _buildSuggestions(
    List<MerchantSearchItem> items,
    String query,
  ) {
    if (query.length < 3) return const [];
    final sorted = List<MerchantSearchItem>.from(items)
      ..sort((a, b) => _verificationRank(b.verificationStatus)
          .compareTo(_verificationRank(a.verificationStatus)));
    return sorted.take(5).toList();
  }

  void _sortResults(List<MerchantSearchItem> items, SearchSortBy sortBy) {
    int compare(MerchantSearchItem a, MerchantSearchItem b) {
      final boost = b.sortBoost.compareTo(a.sortBoost);
      if (boost != 0) return boost;

      final open = _boolRank(b.isOpenNow).compareTo(_boolRank(a.isOpenNow));
      if (open != 0) return open;

      final distanceA = a.distanceMeters ?? 999999999;
      final distanceB = b.distanceMeters ?? 999999999;
      final distance = distanceA.compareTo(distanceB);
      if (distance != 0) return distance;

      final communityA = a.verificationStatus == 'community_submitted' ? 1 : 0;
      final communityB = b.verificationStatus == 'community_submitted' ? 1 : 0;
      final community = communityA.compareTo(communityB);
      if (community != 0) return community;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }

    switch (sortBy) {
      case SearchSortBy.name:
        items.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SearchSortBy.sortBoost:
        items.sort((a, b) => compare(a, b));
        break;
      case SearchSortBy.distance:
        items.sort((a, b) {
          final da = a.distanceMeters ?? 999999999;
          final db = b.distanceMeters ?? 999999999;
          final distance = da.compareTo(db);
          if (distance != 0) return distance;
          return compare(a, b);
        });
        break;
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
  int _boolRank(bool? value) => value == true ? 1 : 0;

  int _verificationRank(String status) {
    switch (status) {
      case 'verified':
        return 5;
      case 'validated':
        return 4;
      case 'claimed':
        return 3;
      case 'referential':
        return 2;
      case 'community_submitted':
        return 1;
      default:
        return 0;
    }
  }

  bool _hasAnyFilter(SearchFilters filters) {
    return filters.isOpenNow ||
        (filters.categoryId ?? '').isNotEmpty ||
        (filters.minVerificationStatus ?? '').isNotEmpty ||
        filters.sortBy != SearchSortBy.distance;
  }

  void _trackEmptyState() {
    if (state.isLoading || state.error != null || state.results.isNotEmpty)
      return;
    final reason = _emptyReason();
    final signature =
        '${state.activeZoneId}|${state.query.trim().isNotEmpty}|$reason';
    if (signature == state.lastEmptyStateSignature) return;

    state = state.copyWith(lastEmptyStateSignature: signature);
    unawaited(_analytics.logEmptyStateSeen(
      reason: reason,
      zoneId: state.activeZoneId,
      hasQuery: state.query.trim().isNotEmpty,
    ));
  }

  String _emptyReason() {
    if (state.corpus.isEmpty) return 'zone_without_data';
    if (state.filters.isOpenNow) return 'open_now_filter';
    if (state.query.trim().isEmpty) return 'cold_start';
    return 'no_results';
  }

  String _normalize(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.isEmpty) return '';
    const accents = {
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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final merchantSearchRepositoryProvider = Provider<MerchantSearchDataSource>(
  (ref) => MerchantSearchRepository(),
);

final zoneSearchRepositoryProvider = Provider<ZoneSearchDataSource>(
  (ref) => ZoneSearchRepository(),
);

final searchAnalyticsProvider = Provider<SearchAnalyticsSink>(
  (ref) => FirebaseSearchAnalytics(),
);

final searchNotifierProvider =
    StateNotifierProvider.autoDispose<SearchNotifier, SearchState>(
  (ref) => SearchNotifier(
    ref,
    repository: ref.watch(merchantSearchRepositoryProvider),
    zoneRepository: ref.watch(zoneSearchRepositoryProvider),
    analytics: ref.watch(searchAnalyticsProvider),
  ),
);
