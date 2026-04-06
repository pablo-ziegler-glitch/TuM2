import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
  }

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
