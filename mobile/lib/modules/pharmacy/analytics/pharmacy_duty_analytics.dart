import 'package:firebase_analytics/firebase_analytics.dart';

abstract interface class PharmacyDutyAnalyticsSink {
  Future<void> logViewOpened({
    required String zoneId,
    required String date,
    required bool hasLocationPermission,
  });

  Future<void> logResultsLoaded({
    required String zoneId,
    required String date,
    required int resultsCount,
    required int loadMs,
  });

  Future<void> logEmptyStateShown({
    required String zoneId,
    required String date,
  });

  Future<void> logCallTap({
    required String merchantId,
    required String zoneId,
    required String date,
    required int positionIndex,
  });

  Future<void> logDirectionsTap({
    required String merchantId,
    required String zoneId,
    required String date,
    required int positionIndex,
  });

  Future<void> logDateChanged({
    required String fromDate,
    required String toDate,
    required String zoneId,
  });
}

class FirebasePharmacyDutyAnalytics implements PharmacyDutyAnalyticsSink {
  FirebasePharmacyDutyAnalytics({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logViewOpened({
    required String zoneId,
    required String date,
    required bool hasLocationPermission,
  }) =>
      _analytics.logEvent(
        name: 'pharmacy_duty_view_opened',
        parameters: {
          'zoneId': zoneId,
          'date': date,
          'hasLocationPermission': hasLocationPermission,
        },
      );

  @override
  Future<void> logResultsLoaded({
    required String zoneId,
    required String date,
    required int resultsCount,
    required int loadMs,
  }) =>
      _analytics.logEvent(
        name: 'pharmacy_duty_results_loaded',
        parameters: {
          'zoneId': zoneId,
          'date': date,
          'resultsCount': resultsCount,
          'loadMs': loadMs,
        },
      );

  @override
  Future<void> logEmptyStateShown({
    required String zoneId,
    required String date,
  }) =>
      _analytics.logEvent(
        name: 'pharmacy_duty_empty_state_shown',
        parameters: {
          'zoneId': zoneId,
          'date': date,
        },
      );

  @override
  Future<void> logCallTap({
    required String merchantId,
    required String zoneId,
    required String date,
    required int positionIndex,
  }) =>
      _analytics.logEvent(
        name: 'pharmacy_duty_call_tap',
        parameters: {
          'merchantId': merchantId,
          'zoneId': zoneId,
          'date': date,
          'positionIndex': positionIndex,
        },
      );

  @override
  Future<void> logDirectionsTap({
    required String merchantId,
    required String zoneId,
    required String date,
    required int positionIndex,
  }) =>
      _analytics.logEvent(
        name: 'pharmacy_duty_directions_tap',
        parameters: {
          'merchantId': merchantId,
          'zoneId': zoneId,
          'date': date,
          'positionIndex': positionIndex,
        },
      );

  @override
  Future<void> logDateChanged({
    required String fromDate,
    required String toDate,
    required String zoneId,
  }) =>
      _analytics.logEvent(
        name: 'pharmacy_duty_date_changed',
        parameters: {
          'fromDate': fromDate,
          'toDate': toDate,
          'zoneId': zoneId,
        },
      );
}
