import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class MerchantDetailAnalyticsSink {
  Future<void> logDetailOpened({
    required String merchantId,
    required String verificationStatus,
  });

  Future<void> logDirectionsTapped({
    required String merchantId,
    required bool usedCoordinates,
    required bool launchSucceeded,
  });

  Future<void> logProductTapped({
    required String merchantId,
    required String productId,
  });

  Future<void> logScheduleExpanded({
    required String merchantId,
    required bool expanded,
  });

  Future<void> logSecondaryLoadFailed({
    required String merchantId,
    required String section,
  });
}

class FirebaseMerchantDetailAnalytics implements MerchantDetailAnalyticsSink {
  FirebaseMerchantDetailAnalytics({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logDetailOpened({
    required String merchantId,
    required String verificationStatus,
  }) {
    return _analytics.logEvent(
      name: 'merchant_detail_opened',
      parameters: {
        'merchant_id': merchantId,
        'verification_status': verificationStatus,
      },
    );
  }

  @override
  Future<void> logDirectionsTapped({
    required String merchantId,
    required bool usedCoordinates,
    required bool launchSucceeded,
  }) {
    return _analytics.logEvent(
      name: 'merchant_detail_directions_tap',
      parameters: {
        'merchant_id': merchantId,
        'used_coordinates': usedCoordinates,
        'launch_succeeded': launchSucceeded,
      },
    );
  }

  @override
  Future<void> logProductTapped({
    required String merchantId,
    required String productId,
  }) {
    return _analytics.logEvent(
      name: 'merchant_detail_product_tap',
      parameters: {
        'merchant_id': merchantId,
        'product_id': productId,
      },
    );
  }

  @override
  Future<void> logScheduleExpanded({
    required String merchantId,
    required bool expanded,
  }) {
    return _analytics.logEvent(
      name: 'merchant_detail_schedule_toggle',
      parameters: {
        'merchant_id': merchantId,
        'expanded': expanded,
      },
    );
  }

  @override
  Future<void> logSecondaryLoadFailed({
    required String merchantId,
    required String section,
  }) {
    return _analytics.logEvent(
      name: 'merchant_detail_secondary_failed',
      parameters: {
        'merchant_id': merchantId,
        'section': section,
      },
    );
  }
}

final merchantDetailAnalyticsProvider = Provider<MerchantDetailAnalyticsSink>(
  (ref) => FirebaseMerchantDetailAnalytics(),
);
