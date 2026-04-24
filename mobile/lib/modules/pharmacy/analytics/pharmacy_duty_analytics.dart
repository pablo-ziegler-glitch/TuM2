import '../../../core/analytics/analytics_service.dart';

abstract interface class PharmacyDutyAnalyticsSink {
  Future<void> logPharmacyDutyListViewed({
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  });

  Future<void> logPharmacyDutyDetailOpened({
    required String zoneId,
    required String merchantId,
    required String source,
  });

  Future<void> logPharmacyDutyUsefulActionClicked({
    required String zoneId,
    required String merchantId,
    required String actionType,
    required String distanceBucket,
    required String source,
  });

  Future<void> logOutdatedInfoTapped({
    required String zoneId,
    required String merchantId,
    required String source,
  });

  Future<void> logOutdatedInfoConfirmed({
    required String zoneId,
    required String merchantId,
    required String source,
    required String reasonCode,
  });

  Future<void> logOutdatedInfoReportSubmitted({
    required String zoneId,
    required String merchantId,
    required String source,
    required String reasonCode,
  });
}

class AnalyticsServicePharmacyDutyAnalytics
    implements PharmacyDutyAnalyticsSink {
  AnalyticsServicePharmacyDutyAnalytics(this._analyticsService);

  final AnalyticsService _analyticsService;

  @override
  Future<void> logPharmacyDutyListViewed({
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  }) {
    return _analyticsService.track(
      event: 'pharmacy_duty_list_viewed',
      parameters: {
        'surface': 'pharmacy_duty',
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
  Future<void> logPharmacyDutyDetailOpened({
    required String zoneId,
    required String merchantId,
    required String source,
  }) {
    return _analyticsService.track(
      event: 'pharmacy_duty_detail_opened',
      parameters: {
        'surface': 'pharmacy_duty_detail',
        'zoneId': zoneId,
        'merchantId': merchantId,
        'source': source,
      },
    );
  }

  @override
  Future<void> logPharmacyDutyUsefulActionClicked({
    required String zoneId,
    required String merchantId,
    required String actionType,
    required String distanceBucket,
    required String source,
  }) async {
    await _analyticsService.track(
      event: 'pharmacy_duty_useful_action_clicked',
      parameters: {
        'surface': 'pharmacy_duty',
        'zoneId': zoneId,
        'merchantId': merchantId,
        'action_type': actionType,
        'distance_bucket': distanceBucket,
        'source': source,
        'elapsed_time_bucket': _analyticsService.elapsedTimeBucketNow(),
      },
    );
    await _analyticsService.track(
      event: 'useful_action_clicked',
      parameters: {
        'surface': 'pharmacy_duty',
        'zoneId': zoneId,
        'merchantId': merchantId,
        'action_type': actionType,
        'distance_bucket': distanceBucket,
        'source': source,
        'elapsed_time_bucket': _analyticsService.elapsedTimeBucketNow(),
      },
    );
  }

  @override
  Future<void> logOutdatedInfoTapped({
    required String zoneId,
    required String merchantId,
    required String source,
  }) {
    return _analyticsService.track(
      event: 'outdated_info_tapped',
      parameters: {
        'surface': 'pharmacy_duty',
        'zoneId': zoneId,
        'merchantId': merchantId,
        'source': source,
      },
    );
  }

  @override
  Future<void> logOutdatedInfoConfirmed({
    required String zoneId,
    required String merchantId,
    required String source,
    required String reasonCode,
  }) {
    return _analyticsService.track(
      event: 'outdated_info_confirmed',
      parameters: {
        'surface': 'pharmacy_duty',
        'zoneId': zoneId,
        'merchantId': merchantId,
        'source': source,
        'reason_code': reasonCode,
      },
    );
  }

  @override
  Future<void> logOutdatedInfoReportSubmitted({
    required String zoneId,
    required String merchantId,
    required String source,
    required String reasonCode,
  }) {
    return _analyticsService.track(
      event: 'outdated_info_report_submitted',
      parameters: {
        'surface': 'pharmacy_duty',
        'zoneId': zoneId,
        'merchantId': merchantId,
        'source': source,
        'reason_code': reasonCode,
      },
    );
  }
}

class NoopPharmacyDutyAnalytics implements PharmacyDutyAnalyticsSink {
  @override
  Future<void> logOutdatedInfoConfirmed({
    required String zoneId,
    required String merchantId,
    required String source,
    required String reasonCode,
  }) async {}

  @override
  Future<void> logOutdatedInfoReportSubmitted({
    required String zoneId,
    required String merchantId,
    required String source,
    required String reasonCode,
  }) async {}

  @override
  Future<void> logOutdatedInfoTapped({
    required String zoneId,
    required String merchantId,
    required String source,
  }) async {}

  @override
  Future<void> logPharmacyDutyDetailOpened({
    required String zoneId,
    required String merchantId,
    required String source,
  }) async {}

  @override
  Future<void> logPharmacyDutyListViewed({
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  }) async {}

  @override
  Future<void> logPharmacyDutyUsefulActionClicked({
    required String zoneId,
    required String merchantId,
    required String actionType,
    required String distanceBucket,
    required String source,
  }) async {}
}
