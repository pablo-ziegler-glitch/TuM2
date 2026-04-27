import '../models/operational_signals.dart';
import '../../../core/analytics/analytics_runtime.dart';

abstract class OwnerOperationalSignalsAnalytics {
  static Future<void> logOpened({
    required String merchantId,
  }) =>
      _safeLog(
        'owner_signal_viewed',
        parameters: {
          'merchantId': merchantId,
          'source_screen': 'owner_signals',
        },
      );

  static Future<void> logCreateStarted({
    required String merchantId,
    required OperationalSignalType signalType,
  }) =>
      _safeLog(
        'owner_signal_create_started',
        parameters: {
          'merchantId': merchantId,
          'signal_type': signalType.firestoreValue,
          'source_screen': 'owner_signals',
        },
      );

  static Future<void> logSaved({
    required String merchantId,
    required OperationalSignalsAnalyticsPayload payload,
  }) async {
    await _safeLog(
      'owner_signal_activated',
      parameters: {
        'merchantId': merchantId,
        'signal_type': payload.signalType.firestoreValue,
        'has_message': payload.hasMessage,
        'has_end_date': payload.hasEndDate,
        'source_screen': 'owner_signals',
      },
    );
  }

  static Future<void> logDisabled({
    required String merchantId,
  }) async {
    await _safeLog(
      'owner_signal_deactivated',
      parameters: {
        'merchantId': merchantId,
        'source_screen': 'owner_signals',
      },
    );
  }

  static Future<void> logOperationalPreviewViewed({
    required String merchantId,
    required OperationalSignalType signalType,
  }) =>
      _safeLog(
        'owner_operational_preview_viewed',
        parameters: {
          'merchantId': merchantId,
          'signal_type': signalType.firestoreValue,
          'source_screen': 'owner_signals',
        },
      );

  static Future<void> logSaveFailed({
    required String merchantId,
    required String reason,
    required OperationalSignalsAnalyticsPayload payload,
  }) =>
      _safeLog(
        'owner_signal_save_failed',
        parameters: {
          'merchantId': merchantId,
          'signal_type': payload.signalType.firestoreValue,
          'has_message': payload.hasMessage,
          'has_end_date': payload.hasEndDate,
          'source_screen': 'owner_signals',
          'reason': reason,
        },
      );

  static Future<void> _safeLog(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await AnalyticsRuntime.service.track(
        event: name,
        parameters: parameters ?? const <String, Object?>{},
      );
    } catch (_) {
      // Analytics no debe romper el flujo principal.
    }
  }
}

class OperationalSignalsAnalyticsPayload {
  const OperationalSignalsAnalyticsPayload({
    required this.signalType,
    required this.hasMessage,
    required this.hasEndDate,
  });

  final OperationalSignalType signalType;
  final bool hasMessage;
  final bool hasEndDate;
}
