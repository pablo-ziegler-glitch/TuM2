import 'package:firebase_analytics/firebase_analytics.dart';

import '../models/operational_signals.dart';

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
  }) async {
    await _safeLog(
      'owner_operational_signal_saved',
      parameters: {
        'merchant_id': merchantId,
        'signal_type': payload.signalType.firestoreValue,
        'is_active': payload.isActive,
        'force_closed': payload.forceClosed,
        'save_result': 'success',
        'source_screen': 'owner_signals',
      },
    );
    await _safeLog(
      'senal_creada',
      parameters: {
        'merchant_id': merchantId,
        'signal_type': payload.signalType.firestoreValue,
      },
    );
  }

  static Future<void> logDisabled({
    required String merchantId,
  }) async {
    await _safeLog(
      'owner_operational_signal_disabled',
      parameters: {
        'merchant_id': merchantId,
        'source_screen': 'owner_signals',
      },
    );
    await _safeLog(
      'senal_desactivada',
      parameters: {
        'merchant_id': merchantId,
      },
    );
  }

  static Future<void> logSaveFailed({
    required String merchantId,
    required String reason,
    required OperationalSignalsAnalyticsPayload payload,
  }) =>
      _safeLog(
        'owner_operational_signal_save_failed',
        parameters: {
          'merchant_id': merchantId,
          'signal_type': payload.signalType.firestoreValue,
          'is_active': payload.isActive,
          'force_closed': payload.forceClosed,
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
    required this.signalType,
    required this.isActive,
    required this.forceClosed,
  });

  final OperationalSignalType signalType;
  final bool isActive;
  final bool forceClosed;
}
