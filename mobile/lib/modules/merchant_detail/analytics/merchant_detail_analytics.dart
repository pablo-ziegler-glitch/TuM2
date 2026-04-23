import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/analytics_provider.dart';
import '../../../core/analytics/analytics_service.dart';

abstract interface class MerchantDetailAnalyticsSink {
  Future<void> logDetailView({
    required String categoryId,
    required bool hasPharmacyDutyToday,
  });

  Future<void> logCallClick({
    required String entityZoneId,
    required bool launchSucceeded,
  });

  Future<void> logDirectionsClick({
    required String entityZoneId,
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
  Future<void> logDetailView({
    required String categoryId,
    required bool hasPharmacyDutyToday,
  }) {
    return _analyticsService.track(
      event: 'merchant_detail_view',
      parameters: {
        'surface': 'merchant_detail',
        'category_id': categoryId,
        'has_pharmacy_duty_today': hasPharmacyDutyToday,
      },
    );
  }

  @override
  Future<void> logCallClick({
    required String entityZoneId,
    required bool launchSucceeded,
  }) {
    return _analyticsService.track(
      event: 'operator_call_click',
      parameters: {
        'surface': 'merchant_detail',
        'entity_type': 'merchant',
        'active_zone_id': entityZoneId,
        'entity_zone_id': entityZoneId,
        'distance_bucket': 'unknown',
        'launch_succeeded': launchSucceeded,
      },
    );
  }

  @override
  Future<void> logDirectionsClick({
    required String entityZoneId,
    required bool launchSucceeded,
  }) {
    return _analyticsService.track(
      event: 'directions_opened',
      parameters: {
        'surface': 'merchant_detail',
        'entity_type': 'merchant',
        'active_zone_id': entityZoneId,
        'entity_zone_id': entityZoneId,
        'distance_bucket': 'unknown',
        'launch_succeeded': launchSucceeded,
      },
    );
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
