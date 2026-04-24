import '../../../core/analytics/analytics_runtime.dart';

abstract interface class OpenNowAnalyticsSink {
  Future<void> logOpenNowViewed({
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  });

  Future<void> logOpenNowMerchantOpened({
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
    required String source,
  });
}

class FirebaseOpenNowAnalytics implements OpenNowAnalyticsSink {
  FirebaseOpenNowAnalytics();

  @override
  Future<void> logOpenNowViewed({
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  }) =>
      _safeLog('open_now_viewed', {
        'surface': 'open_now',
        'zoneId': zoneId,
        'results_count_bucket':
            AnalyticsRuntime.service.resultCountBucket(resultsCount),
        'is_open_now_shown': isOpenNowShown,
        'is_on_duty_shown': isOnDutyShown,
      });

  @override
  Future<void> logOpenNowMerchantOpened({
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
    required String source,
  }) =>
      _safeLog('open_now_merchant_opened', {
        'surface': 'open_now',
        'zoneId': zoneId,
        'merchantId': merchantId,
        'categoryId': categoryId,
        'is_open_now_shown': isOpenNowShown,
        'is_on_duty_shown': isOnDutyShown,
        'source': source,
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
  Future<void> logOpenNowMerchantOpened({
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
    required String source,
  }) async {}

  @override
  Future<void> logOpenNowViewed({
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  }) async {}
}
