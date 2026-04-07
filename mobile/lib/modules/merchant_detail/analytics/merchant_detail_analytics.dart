import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class MerchantDetailAnalyticsSink {
  Future<void> logDetailView({
    required String merchantId,
    required String categoryId,
    required bool hasPharmacyDutyToday,
  });

  Future<void> logCallClick({
    required String merchantId,
    required bool launchSucceeded,
  });

  Future<void> logDirectionsClick({
    required String merchantId,
    required bool launchSucceeded,
  });

  Future<void> logShareClick({
    required String merchantId,
    required bool launchSucceeded,
  });

  Future<void> logDutyBannerView({
    required String merchantId,
    required bool hasEndsAt,
  });

  Future<void> logError({
    required String merchantId,
    required String stage,
    required String errorType,
  });
}

class FirebaseMerchantDetailAnalytics implements MerchantDetailAnalyticsSink {
  FirebaseMerchantDetailAnalytics({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logDetailView({
    required String merchantId,
    required String categoryId,
    required bool hasPharmacyDutyToday,
  }) {
    return _analytics.logEvent(
      name: 'merchant_detail_view',
      parameters: {
        'merchant_id': merchantId,
        'category_id': categoryId,
        'has_pharmacy_duty_today': hasPharmacyDutyToday,
      },
    );
  }

  @override
  Future<void> logCallClick({
    required String merchantId,
    required bool launchSucceeded,
  }) {
    return _analytics.logEvent(
      name: 'merchant_detail_call_click',
      parameters: {
        'merchant_id': merchantId,
        'launch_succeeded': launchSucceeded,
      },
    );
  }

  @override
  Future<void> logDirectionsClick({
    required String merchantId,
    required bool launchSucceeded,
  }) {
    return _analytics.logEvent(
      name: 'merchant_detail_directions_click',
      parameters: {
        'merchant_id': merchantId,
        'launch_succeeded': launchSucceeded,
      },
    );
  }

  @override
  Future<void> logShareClick({
    required String merchantId,
    required bool launchSucceeded,
  }) {
    return _analytics.logEvent(
      name: 'merchant_detail_share_click',
      parameters: {
        'merchant_id': merchantId,
        'launch_succeeded': launchSucceeded,
      },
    );
  }

  @override
  Future<void> logDutyBannerView({
    required String merchantId,
    required bool hasEndsAt,
  }) {
    return _analytics.logEvent(
      name: 'merchant_detail_duty_banner_view',
      parameters: {
        'merchant_id': merchantId,
        'has_ends_at': hasEndsAt,
      },
    );
  }

  @override
  Future<void> logError({
    required String merchantId,
    required String stage,
    required String errorType,
  }) {
    return _analytics.logEvent(
      name: 'merchant_detail_error',
      parameters: {
        'merchant_id': merchantId,
        'stage': stage,
        'error_type': errorType,
      },
    );
  }
}

final merchantDetailAnalyticsProvider = Provider<MerchantDetailAnalyticsSink>(
  (ref) => FirebaseMerchantDetailAnalytics(),
);
