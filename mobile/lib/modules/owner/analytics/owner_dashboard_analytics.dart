import 'package:firebase_analytics/firebase_analytics.dart';

abstract class OwnerDashboardAnalytics {
  static FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logViewed({
    required String merchantId,
  }) =>
      _safeLog(
        'owner_dashboard_viewed',
        parameters: {'merchant_id': merchantId},
      );

  static Future<void> logQuickActionTapped({
    required String merchantId,
    required String actionId,
  }) =>
      _safeLog(
        'owner_dashboard_quick_action_tapped',
        parameters: {
          'merchant_id': merchantId,
          'action_id': actionId,
        },
      );

  static Future<void> logAlertTapped({
    required String merchantId,
    required String alertId,
  }) =>
      _safeLog(
        'owner_dashboard_alert_tapped',
        parameters: {
          'merchant_id': merchantId,
          'alert_id': alertId,
        },
      );

  static Future<void> logEmptyStateViewed() =>
      _safeLog('owner_dashboard_empty_state_viewed');

  static Future<void> logErrorViewed() =>
      _safeLog('owner_dashboard_error_viewed');

  static Future<void> _safeLog(
    String eventName, {
    Map<String, Object>? parameters,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logEvent(name: eventName, parameters: parameters);
    } catch (_) {
      // Analytics nunca debe romper el flujo OWNER.
    }
  }
}
