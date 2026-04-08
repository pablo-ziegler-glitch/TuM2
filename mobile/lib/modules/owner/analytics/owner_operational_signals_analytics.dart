import 'package:firebase_analytics/firebase_analytics.dart';

abstract class OwnerOperationalSignalsAnalytics {
  static FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logOpened({
    required String merchantId,
  }) =>
      _safeLog(
        'owner_operational_signal_opened',
        parameters: {
          'merchant_id': merchantId,
        },
      );

  static Future<void> logSaved({
    required String merchantId,
    required OperationalSignalsAnalyticsPayload payload,
  }) =>
      _safeLog(
        'owner_operational_signal_saved',
        parameters: {
          'merchant_id': merchantId,
          'signal_temporary_closed': payload.temporaryClosed,
          'signal_has_delivery': payload.hasDelivery,
          'signal_accepts_whatsapp_orders': payload.acceptsWhatsappOrders,
          'signal_open_now_manual_override': payload.openNowManualOverride,
          'save_result': 'success',
          'source_screen': 'owner_signals',
        },
      );

  static Future<void> logSaveFailed({
    required String merchantId,
    required String reason,
    required OperationalSignalsAnalyticsPayload payload,
  }) =>
      _safeLog(
        'owner_operational_signal_save_failed',
        parameters: {
          'merchant_id': merchantId,
          'signal_temporary_closed': payload.temporaryClosed,
          'signal_has_delivery': payload.hasDelivery,
          'signal_accepts_whatsapp_orders': payload.acceptsWhatsappOrders,
          'signal_open_now_manual_override': payload.openNowManualOverride,
          'save_result': 'error',
          'source_screen': 'owner_signals',
          'reason': reason,
        },
      );

  static Future<void> _safeLog(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (_) {
      // Analytics no debe romper el flujo principal.
    }
  }
}

class OperationalSignalsAnalyticsPayload {
  const OperationalSignalsAnalyticsPayload({
    required this.temporaryClosed,
    required this.hasDelivery,
    required this.acceptsWhatsappOrders,
    required this.openNowManualOverride,
  });

  final bool temporaryClosed;
  final bool hasDelivery;
  final bool acceptsWhatsappOrders;
  final bool openNowManualOverride;
}
