import 'package:firebase_analytics/firebase_analytics.dart';

abstract class MerchantClaimAnalytics {
  static FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logStarted() => _safeLog('merchant_claim_started');

  static Future<void> logStepViewed(String stepId) => _safeLog(
        'merchant_claim_step_viewed',
        parameters: {'step_id': stepId},
      );

  static Future<void> logStepCompleted(String stepId) => _safeLog(
        'merchant_claim_step_completed',
        parameters: {'step_id': stepId},
      );

  static Future<void> logEvidenceUploaded(String kind) => _safeLog(
        'merchant_claim_evidence_uploaded',
        parameters: {'evidence_kind': kind},
      );

  static Future<void> logSubmitted(String status) => _safeLog(
        'merchant_claim_submitted',
        parameters: {'claim_status': status},
      );

  static Future<void> logSubmissionFailed(String code) => _safeLog(
        'merchant_claim_submission_failed',
        parameters: {'error_code': code},
      );

  static Future<void> logStatusViewed(String status) => _safeLog(
        'merchant_claim_status_viewed',
        parameters: {'claim_status': status},
      );

  static Future<void> _safeLog(
    String eventName, {
    Map<String, Object>? parameters,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logEvent(name: eventName, parameters: parameters);
    } catch (_) {
      // Analytics no bloquea el flujo de claim.
    }
  }
}
