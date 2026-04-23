import '../../../core/analytics/analytics_service.dart';

abstract interface class SearchAnalyticsSink {
  Future<void> logSearchPerformed({
    required String surface,
    required String activeZoneId,
    required int queryLength,
    required int resultsCount,
    required bool usedCategoryFilter,
    required bool usedOpenNowFilter,
    required bool usedDistanceSort,
    required bool resolvedLocally,
  });

  Future<void> logCategoryFiltered({
    required String surface,
    required String categoryId,
    required String activeZoneId,
    required int resultCount,
    required bool usedOpenNowFilter,
    required bool usedDistanceSort,
  });

  Future<void> logMapViewed({
    required String surface,
    required String activeZoneId,
    required int resultCount,
  });

  Future<void> logMapPinSelected({
    required String surface,
    required String activeZoneId,
    required String entityZoneId,
    required String distanceBucket,
  });

  Future<void> logMapRecenterTapped({
    required String surface,
    required String activeZoneId,
  });

  Future<void> logMapSearchThisAreaTapped({
    required String surface,
    required String activeZoneId,
  });
}

class AnalyticsServiceSearchAnalytics implements SearchAnalyticsSink {
  AnalyticsServiceSearchAnalytics(this._analyticsService);

  final AnalyticsService _analyticsService;

  @override
  Future<void> logSearchPerformed({
    required String surface,
    required String activeZoneId,
    required int queryLength,
    required int resultsCount,
    required bool usedCategoryFilter,
    required bool usedOpenNowFilter,
    required bool usedDistanceSort,
    required bool resolvedLocally,
  }) {
    return _analyticsService.track(
      event: 'search_performed',
      parameters: {
        'surface': surface,
        'search_mode': 'explicit',
        'query_length_bucket': _analyticsService.queryLengthBucket(queryLength),
        'result_count_bucket':
            _analyticsService.resultCountBucket(resultsCount),
        'used_category_filter': usedCategoryFilter,
        'used_open_now_filter': usedOpenNowFilter,
        'used_distance_sort': usedDistanceSort,
        'active_zone_id': activeZoneId,
        'resolved_locally': resolvedLocally,
      },
    );
  }

  @override
  Future<void> logCategoryFiltered({
    required String surface,
    required String categoryId,
    required String activeZoneId,
    required int resultCount,
    required bool usedOpenNowFilter,
    required bool usedDistanceSort,
  }) {
    return _analyticsService.track(
      event: 'category_filtered',
      parameters: {
        'surface': surface,
        'category_id': categoryId,
        'active_zone_id': activeZoneId,
        'result_count_bucket': _analyticsService.resultCountBucket(resultCount),
        'used_open_now_filter': usedOpenNowFilter,
        'used_distance_sort': usedDistanceSort,
      },
    );
  }

  @override
  Future<void> logMapViewed({
    required String surface,
    required String activeZoneId,
    required int resultCount,
  }) {
    return _analyticsService.track(
      event: 'map_viewed',
      parameters: {
        'surface': surface,
        'active_zone_id': activeZoneId,
        'result_count_bucket': _analyticsService.resultCountBucket(resultCount),
      },
      dedupeWindow: const Duration(seconds: 4),
    );
  }

  @override
  Future<void> logMapPinSelected({
    required String surface,
    required String activeZoneId,
    required String entityZoneId,
    required String distanceBucket,
  }) {
    return _analyticsService.track(
      event: 'map_pin_selected',
      parameters: {
        'surface': surface,
        'active_zone_id': activeZoneId,
        'entity_zone_id': entityZoneId,
        'distance_bucket': distanceBucket,
      },
    );
  }

  @override
  Future<void> logMapRecenterTapped({
    required String surface,
    required String activeZoneId,
  }) {
    return _analyticsService.track(
      event: 'map_recenter_tapped',
      parameters: {
        'surface': surface,
        'active_zone_id': activeZoneId,
      },
    );
  }

  @override
  Future<void> logMapSearchThisAreaTapped({
    required String surface,
    required String activeZoneId,
  }) {
    return _analyticsService.track(
      event: 'map_search_this_area_tapped',
      parameters: {
        'surface': surface,
        'active_zone_id': activeZoneId,
      },
    );
  }
}

class NoopSearchAnalytics implements SearchAnalyticsSink {
  @override
  Future<void> logCategoryFiltered({
    required String surface,
    required String categoryId,
    required String activeZoneId,
    required int resultCount,
    required bool usedOpenNowFilter,
    required bool usedDistanceSort,
  }) async {}

  @override
  Future<void> logMapPinSelected({
    required String surface,
    required String activeZoneId,
    required String entityZoneId,
    required String distanceBucket,
  }) async {}

  @override
  Future<void> logMapRecenterTapped({
    required String surface,
    required String activeZoneId,
  }) async {}

  @override
  Future<void> logMapSearchThisAreaTapped({
    required String surface,
    required String activeZoneId,
  }) async {}

  @override
  Future<void> logMapViewed({
    required String surface,
    required String activeZoneId,
    required int resultCount,
  }) async {}

  @override
  Future<void> logSearchPerformed({
    required String surface,
    required String activeZoneId,
    required int queryLength,
    required int resultsCount,
    required bool usedCategoryFilter,
    required bool usedOpenNowFilter,
    required bool usedDistanceSort,
    required bool resolvedLocally,
  }) async {}
}
