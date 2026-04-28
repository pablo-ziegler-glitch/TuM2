import '../../../core/analytics/analytics_runtime.dart';

abstract class OwnerScheduleAnalytics {
  static Future<void> logScreenView({
    required String merchantId,
  }) =>
      _safeLog(
        'owner_schedule_viewed',
        parameters: {
          'merchantId': merchantId,
          'source_screen': 'owner_schedule',
        },
      );

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

  static Future<void> logEditStarted({
    required String merchantId,
  }) =>
      _safeLog(
        'owner_schedule_edit_started',
        parameters: {
          'merchantId': merchantId,
          'source_screen': 'owner_schedule',
        },
      );

  static Future<void> logAddException({
    required String merchantId,
    required String exceptionKind,
  }) =>
      _safeLog(
        'owner_schedule_exception_created',
        parameters: {
          'merchantId': merchantId,
          'exception_kind': exceptionKind,
          'source_screen': 'owner_schedule',
        },
      );

  static Future<void> logDeleteException({
    required String merchantId,
    required String exceptionKind,
  }) =>
      _safeLog(
        'owner_schedule_exception_deleted',
        parameters: {
          'merchantId': merchantId,
          'exception_kind': exceptionKind,
          'source_screen': 'owner_schedule',
        },
      );

  static Future<void> logSaveSuccess({
    required String merchantId,
  }) =>
      _safeLog(
        'owner_schedule_saved',
        parameters: {
          'merchantId': merchantId,
          'source_screen': 'owner_schedule',
        },
      );

  static Future<void> logSaveError({
    required String merchantId,
    required String reason,
  }) =>
      _safeLog(
        'owner_schedule_save_failed',
        parameters: {
          'merchantId': merchantId,
          'reason': reason,
          'source_screen': 'owner_schedule',
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
    try {
      await AnalyticsRuntime.service.track(
        event: name,
        parameters: parameters ?? const <String, Object?>{},
      );
    } catch (_) {
      // Analytics nunca debe romper el flujo.
    }
  }
}
