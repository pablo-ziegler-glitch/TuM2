import '../../../core/analytics/analytics_service.dart';

abstract interface class SearchAnalyticsSink {
  Future<void> logSearchExecuted({
    required String surface,
    required String zoneId,
    required int queryLength,
    required int resultsCount,
  });

  Future<void> logSearchResultsViewed({
    required String surface,
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  });

  Future<void> logSearchFilterApplied({
    required String surface,
    required String zoneId,
    required String categoryId,
    required int resultCount,
  });

  Future<void> logMapViewed({
    required String zoneId,
    required int resultCount,
  });

  Future<void> logMerchantCardImpression({
    required String surface,
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
    required String source,
  });

  Future<void> logMerchantDetailOpened({
    required String surface,
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required String distanceBucket,
    required String source,
  });

  Future<void> logMapRecenterTapped({
    required String surface,
    required String zoneId,
  });

  Future<void> logMapSearchThisAreaTapped({
    required String surface,
    required String zoneId,
  });
}

class AnalyticsServiceSearchAnalytics implements SearchAnalyticsSink {
  AnalyticsServiceSearchAnalytics(this._analyticsService);

  final AnalyticsService _analyticsService;

  @override
  Future<void> logSearchExecuted({
    required String surface,
    required String zoneId,
    required int queryLength,
    required int resultsCount,
  }) {
    return _analyticsService.track(
      event: 'search_executed',
      parameters: {
        'surface': surface,
        'zoneId': zoneId,
        'query_length_bucket': _analyticsService.queryLengthBucket(queryLength),
        'results_count_bucket':
            _analyticsService.resultCountBucket(resultsCount),
      },
    );
  }

  @override
  Future<void> logSearchResultsViewed({
    required String surface,
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  }) {
    return _analyticsService.track(
      event: 'search_results_viewed',
      parameters: {
        'surface': surface,
        'zoneId': zoneId,
        'results_count_bucket':
            _analyticsService.resultCountBucket(resultsCount),
        'is_open_now_shown': isOpenNowShown,
        'is_on_duty_shown': isOnDutyShown,
      },
      dedupeWindow: const Duration(seconds: 4),
    );
  }

  @override
  Future<void> logSearchFilterApplied({
    required String surface,
    required String zoneId,
    required String categoryId,
    required int resultCount,
  }) {
    return _analyticsService.track(
      event: 'search_filter_applied',
      parameters: {
        'surface': surface,
        'zoneId': zoneId,
        'categoryId': categoryId,
        'results_count_bucket':
            _analyticsService.resultCountBucket(resultCount),
      },
    );
  }

  @override
  Future<void> logMapViewed({
    required String zoneId,
    required int resultCount,
  }) {
    return _analyticsService.track(
      event: 'surface_viewed',
      parameters: {
        'surface': 'search_map',
        'zoneId': zoneId,
        'results_count_bucket':
            _analyticsService.resultCountBucket(resultCount),
      },
      dedupeWindow: const Duration(seconds: 4),
    );
  }

  @override
  Future<void> logMerchantCardImpression({
    required String surface,
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
    required String source,
  }) {
    return _analyticsService.track(
      event: 'merchant_card_impression',
      parameters: {
        'surface': surface,
        'zoneId': zoneId,
        'merchantId': merchantId,
        'categoryId': categoryId,
        'is_open_now_shown': isOpenNowShown,
        'is_on_duty_shown': isOnDutyShown,
        'source': source,
      },
      dedupeWindow: const Duration(seconds: 30),
    );
  }

  @override
  Future<void> logMerchantDetailOpened({
    required String surface,
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required String distanceBucket,
    required String source,
  }) {
    return _analyticsService.track(
      event: 'merchant_detail_opened',
      parameters: {
        'surface': surface,
        'zoneId': zoneId,
        'merchantId': merchantId,
        'categoryId': categoryId,
        'distance_bucket': distanceBucket,
        'source': source,
      },
    );
  }

  @override
  Future<void> logMapRecenterTapped({
    required String surface,
    required String zoneId,
  }) {
    return Future<void>.value();
  }

  @override
  Future<void> logMapSearchThisAreaTapped({
    required String surface,
    required String zoneId,
  }) {
    return Future<void>.value();
  }
}

class NoopSearchAnalytics implements SearchAnalyticsSink {
  @override
  Future<void> logMapRecenterTapped({
    required String surface,
    required String zoneId,
  }) async {}

  @override
  Future<void> logMapSearchThisAreaTapped({
    required String surface,
    required String zoneId,
  }) async {}

  @override
  Future<void> logMapViewed({
    required String zoneId,
    required int resultCount,
  }) async {}

  @override
  Future<void> logMerchantCardImpression({
    required String surface,
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
    required String source,
  }) async {}

  @override
  Future<void> logMerchantDetailOpened({
    required String surface,
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required String distanceBucket,
    required String source,
  }) async {}

  @override
  Future<void> logSearchExecuted({
    required String surface,
    required String zoneId,
    required int queryLength,
    required int resultsCount,
  }) async {}

  @override
  Future<void> logSearchFilterApplied({
    required String surface,
    required String zoneId,
    required String categoryId,
    required int resultCount,
  }) async {}

  @override
  Future<void> logSearchResultsViewed({
    required String surface,
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  }) async {}
}
