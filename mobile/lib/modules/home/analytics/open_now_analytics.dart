import '../../../core/analytics/analytics_runtime.dart';

abstract interface class OpenNowAnalyticsSink {
  Future<void> logViewOpened({
    required String zoneId,
  });

  Future<void> logResultsLoaded({
    required String zoneId,
    required int resultsCount,
    required int fallbackCount,
    required bool hasLocation,
    required String dataFreshnessBucket,
    required String topResultVerificationStatus,
  });

  Future<void> logEmptyStateShown({
    required String zoneId,
  });

  Future<void> logFallbackShown({
    required String zoneId,
    required int fallbackCount,
  });

  Future<void> logPullToRefresh({
    required String zoneId,
  });

  Future<void> logCardClicked({
    required String zoneId,
    required String merchantId,
    required bool isFallback,
    required int rank,
  });

  Future<void> logDistancePermissionDenied({
    required String status,
  });

  Future<void> logLocationUnavailable({
    required String reason,
  });
}

class FirebaseOpenNowAnalytics implements OpenNowAnalyticsSink {
  FirebaseOpenNowAnalytics();

  @override
  Future<void> logViewOpened({
    required String zoneId,
  }) =>
      _safeLog('open_now_view_opened', {
        'zone_id': zoneId,
      });

  @override
  Future<void> logResultsLoaded({
    required String zoneId,
    required int resultsCount,
    required int fallbackCount,
    required bool hasLocation,
    required String dataFreshnessBucket,
    required String topResultVerificationStatus,
  }) =>
      _safeLog('open_now_results_loaded', {
        'zone_id': zoneId,
        'results_count': resultsCount,
        'fallback_count': fallbackCount,
        'has_location': hasLocation,
        'data_freshness_bucket': dataFreshnessBucket,
        'top_result_verification_status': topResultVerificationStatus,
      });

  @override
  Future<void> logEmptyStateShown({
    required String zoneId,
  }) =>
      _safeLog('open_now_empty_state_shown', {
        'zone_id': zoneId,
      });

  @override
  Future<void> logFallbackShown({
    required String zoneId,
    required int fallbackCount,
  }) =>
      _safeLog('open_now_fallback_shown', {
        'zone_id': zoneId,
        'fallback_count': fallbackCount,
      });

  @override
  Future<void> logPullToRefresh({
    required String zoneId,
  }) =>
      _safeLog('open_now_pull_to_refresh', {
        'zone_id': zoneId,
      });

  @override
  Future<void> logCardClicked({
    required String zoneId,
    required String merchantId,
    required bool isFallback,
    required int rank,
  }) =>
      _safeLog('open_now_card_clicked', {
        'zone_id': zoneId,
        'merchant_id': merchantId,
        'is_fallback': isFallback,
        'rank': rank,
      });

  @override
  Future<void> logDistancePermissionDenied({
    required String status,
  }) =>
      _safeLog('open_now_distance_permission_denied', {
        'status': status,
      });

  @override
  Future<void> logLocationUnavailable({
    required String reason,
  }) =>
      _safeLog('open_now_location_unavailable', {
        'reason': reason,
      });

  Future<void> _safeLog(String name, Map<String, Object?> parameters) async {
    try {
      await AnalyticsRuntime.service.track(
        event: name,
        parameters: parameters,
      );
    } catch (_) {
      // Analytics nunca debe romper el flujo de la pantalla.
    }
  }
}

class NoopOpenNowAnalytics implements OpenNowAnalyticsSink {
  const NoopOpenNowAnalytics();

  @override
  Future<void> logCardClicked({
    required String zoneId,
    required String merchantId,
    required bool isFallback,
    required int rank,
  }) async {}

  @override
  Future<void> logDistancePermissionDenied({
    required String status,
  }) async {}

  @override
  Future<void> logEmptyStateShown({
    required String zoneId,
  }) async {}

  @override
  Future<void> logFallbackShown({
    required String zoneId,
    required int fallbackCount,
  }) async {}

  @override
  Future<void> logLocationUnavailable({
    required String reason,
  }) async {}

  @override
  Future<void> logPullToRefresh({
    required String zoneId,
  }) async {}

  @override
  Future<void> logResultsLoaded({
    required String zoneId,
    required int resultsCount,
    required int fallbackCount,
    required bool hasLocation,
    required String dataFreshnessBucket,
    required String topResultVerificationStatus,
  }) async {}

  @override
  Future<void> logViewOpened({
    required String zoneId,
  }) async {}
}
