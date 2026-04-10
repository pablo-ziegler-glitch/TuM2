import 'package:firebase_analytics/firebase_analytics.dart';

abstract class PharmacyDutyFlowAnalytics {
  static FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logConfirmationPromptSeen({
    required String zoneId,
    required String merchantRef,
  }) =>
      _safeLog(
        name: 'pharmacy_duty_confirmation_prompt_seen',
        parameters: {
          'zone_id': zoneId,
          'merchant_ref': merchantRef,
        },
      );

  static Future<void> logDutyConfirmed({
    required String zoneId,
    required String merchantRef,
  }) =>
      _safeLog(
        name: 'pharmacy_duty_confirmed',
        parameters: {
          'zone_id': zoneId,
          'merchant_ref': merchantRef,
        },
      );

  static Future<void> logIncidentReported({
    required String zoneId,
    required String merchantRef,
  }) =>
      _safeLog(
        name: 'pharmacy_duty_incident_reported',
        parameters: {
          'zone_id': zoneId,
          'merchant_ref': merchantRef,
        },
      );

  static Future<void> logCandidatesLoaded({
    required String zoneId,
    required String merchantRef,
    required int candidateCount,
  }) =>
      _safeLog(
        name: 'pharmacy_reassignment_candidates_loaded',
        parameters: {
          'zone_id': zoneId,
          'merchant_ref': merchantRef,
          'candidate_count': candidateCount,
        },
      );

  static Future<void> logRoundCreated({
    required String zoneId,
    required String merchantRef,
    required int candidateCount,
  }) =>
      _safeLog(
        name: 'pharmacy_reassignment_round_created',
        parameters: {
          'zone_id': zoneId,
          'merchant_ref': merchantRef,
          'candidate_count': candidateCount,
        },
      );

  static Future<void> logRequestAccepted({
    required String zoneId,
    required String merchantRef,
    required String distanceBucket,
  }) =>
      _safeLog(
        name: 'pharmacy_reassignment_request_accepted',
        parameters: {
          'zone_id': zoneId,
          'merchant_ref': merchantRef,
          'distance_bucket': distanceBucket,
        },
      );

  static Future<void> logRequestRejected({
    required String zoneId,
    required String merchantRef,
  }) =>
      _safeLog(
        name: 'pharmacy_reassignment_request_rejected',
        parameters: {
          'zone_id': zoneId,
          'merchant_ref': merchantRef,
        },
      );

  static Future<void> logRoundExpired({
    required String zoneId,
    required String merchantRef,
  }) =>
      _safeLog(
        name: 'pharmacy_reassignment_round_expired',
        parameters: {
          'zone_id': zoneId,
          'merchant_ref': merchantRef,
        },
      );

  static Future<void> logDutyReassignedSuccessfully({
    required String zoneId,
    required String merchantRef,
    int? timeToRecoverSeconds,
  }) =>
      _safeLog(
        name: 'pharmacy_duty_reassigned_successfully',
        parameters: {
          'zone_id': zoneId,
          'merchant_ref': merchantRef,
          if (timeToRecoverSeconds != null)
            'time_to_recover_seconds': timeToRecoverSeconds,
        },
      );

  static Future<void> _safeLog({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (_) {
      // Analytics nunca debe romper el flujo operativo.
    }
  }
}
