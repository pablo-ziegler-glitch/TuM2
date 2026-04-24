import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/analytics_provider.dart';
import '../../../core/analytics/analytics_service.dart';

abstract interface class MerchantDetailAnalyticsSink {
  Future<void> logDetailOpened({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required bool hasPharmacyDutyToday,
    required String source,
  });

  Future<void> logCallClick({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required String source,
    required bool launchSucceeded,
  });

  Future<void> logDirectionsClick({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required String source,
    required bool launchSucceeded,
  });

  Future<void> logWhatsAppClick({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required String source,
    required bool launchSucceeded,
  });

  Future<void> logShareClick({required bool launchSucceeded});

  Future<void> logDutyBannerView({required bool hasEndsAt});

  Future<void> logError({
    required String stage,
    required String errorType,
  });
}

class AnalyticsServiceMerchantDetailAnalytics
    implements MerchantDetailAnalyticsSink {
  AnalyticsServiceMerchantDetailAnalytics(this._analyticsService);

  final AnalyticsService _analyticsService;

  @override
  Future<void> logDetailOpened({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required bool hasPharmacyDutyToday,
    required String source,
  }) {
    return _analyticsService.track(
      event: 'merchant_detail_opened',
      parameters: {
        'surface': 'merchant_detail',
        'merchantId': merchantId,
        'zoneId': zoneId,
        'categoryId': categoryId,
        'is_on_duty_shown': hasPharmacyDutyToday,
        'source': source,
      },
    );
  }

  @override
  Future<void> logCallClick({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required String source,
    required bool launchSucceeded,
  }) async {
    await _analyticsService.track(
      event: 'useful_action_clicked',
      parameters: {
        'surface': 'merchant_detail',
        'merchantId': merchantId,
        'zoneId': zoneId,
        'categoryId': categoryId,
        'action_type': 'call',
        'source': source,
        'elapsed_time_bucket': _analyticsService.elapsedTimeBucketNow(),
      },
    );
    if (source == 'open_now' || source == 'open_now_fallback') {
      await _analyticsService.track(
        event: 'open_now_useful_action_clicked',
        parameters: {
          'surface': 'open_now',
          'merchantId': merchantId,
          'zoneId': zoneId,
          'categoryId': categoryId,
          'action_type': 'call',
          'source': source,
          'elapsed_time_bucket': _analyticsService.elapsedTimeBucketNow(),
        },
      );
    }
  }

  @override
  Future<void> logDirectionsClick({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required String source,
    required bool launchSucceeded,
  }) async {
    await _analyticsService.track(
      event: 'useful_action_clicked',
      parameters: {
        'surface': 'merchant_detail',
        'merchantId': merchantId,
        'zoneId': zoneId,
        'categoryId': categoryId,
        'action_type': 'directions',
        'source': source,
        'elapsed_time_bucket': _analyticsService.elapsedTimeBucketNow(),
      },
    );
    if (source == 'open_now' || source == 'open_now_fallback') {
      await _analyticsService.track(
        event: 'open_now_useful_action_clicked',
        parameters: {
          'surface': 'open_now',
          'merchantId': merchantId,
          'zoneId': zoneId,
          'categoryId': categoryId,
          'action_type': 'directions',
          'source': source,
          'elapsed_time_bucket': _analyticsService.elapsedTimeBucketNow(),
        },
      );
    }
  }

  @override
  Future<void> logWhatsAppClick({
    required String merchantId,
    required String zoneId,
    required String categoryId,
    required String source,
    required bool launchSucceeded,
  }) async {
    await _analyticsService.track(
      event: 'useful_action_clicked',
      parameters: {
        'surface': 'merchant_detail',
        'merchantId': merchantId,
        'zoneId': zoneId,
        'categoryId': categoryId,
        'action_type': 'whatsapp',
        'source': source,
        'elapsed_time_bucket': _analyticsService.elapsedTimeBucketNow(),
      },
    );
    if (source == 'open_now' || source == 'open_now_fallback') {
      await _analyticsService.track(
        event: 'open_now_useful_action_clicked',
        parameters: {
          'surface': 'open_now',
          'merchantId': merchantId,
          'zoneId': zoneId,
          'categoryId': categoryId,
          'action_type': 'whatsapp',
          'source': source,
          'elapsed_time_bucket': _analyticsService.elapsedTimeBucketNow(),
        },
      );
    }
  }

  @override
  Future<void> logShareClick({required bool launchSucceeded}) {
    return _analyticsService.track(
      event: 'merchant_detail_share_click',
      parameters: {
        'surface': 'merchant_detail',
        'launch_succeeded': launchSucceeded,
      },
    );
  }

  @override
  Future<void> logDutyBannerView({required bool hasEndsAt}) {
    return _analyticsService.track(
      event: 'merchant_detail_duty_banner_view',
      parameters: {
        'surface': 'merchant_detail',
        'has_ends_at': hasEndsAt,
      },
    );
  }

  @override
  Future<void> logError({
    required String stage,
    required String errorType,
  }) {
    return _analyticsService.track(
      event: 'merchant_detail_error',
      parameters: {
        'surface': 'merchant_detail',
        'stage': stage,
        'error_type': errorType,
      },
    );
  }
}

final merchantDetailAnalyticsProvider = Provider<MerchantDetailAnalyticsSink>(
  (ref) => AnalyticsServiceMerchantDetailAnalytics(
    ref.watch(analyticsServiceProvider),
  ),
);
