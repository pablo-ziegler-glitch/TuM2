import 'package:firebase_analytics/firebase_analytics.dart';

abstract class OwnerScheduleAnalytics {
  static FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logScreenView() => _safeLog('owner_schedule_screen_view');

  static Future<void> logModeSelected({
    required String dayKey,
    required String mode,
  }) =>
      _safeLog(
        'owner_schedule_mode_selected',
        parameters: {
          'day_key': dayKey,
          'mode': mode,
        },
      );

  static Future<void> logApplyWeekdaysTemplate() =>
      _safeLog('owner_schedule_apply_weekdays_template');

  static Future<void> logAddException({
    required String exceptionKind,
  }) =>
      _safeLog(
        'owner_schedule_add_exception',
        parameters: {
          'exception_kind': exceptionKind,
        },
      );

  static Future<void> logSaveSuccess() =>
      _safeLog('owner_schedule_save_success');

  static Future<void> logSaveError({
    required String reason,
  }) =>
      _safeLog(
        'owner_schedule_save_error',
        parameters: {
          'reason': reason,
        },
      );

  static Future<void> logValidationError({
    required int weeklyErrors,
    required int exceptionErrors,
    required int closureErrors,
  }) =>
      _safeLog(
        'owner_schedule_validation_error',
        parameters: {
          'weekly_errors': weeklyErrors,
          'exception_errors': exceptionErrors,
          'closure_errors': closureErrors,
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
      // Analytics nunca debe romper el flujo.
    }
  }
}
