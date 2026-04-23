import '../../../core/analytics/analytics_runtime.dart';

abstract class MerchantClaimAnalytics {
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

  static Future<void> logEvidenceRequirementsViewed({
    required String categoryId,
    required String policyVersion,
  }) =>
      _safeLog(
        'merchant_claim_evidence_requirements_viewed',
        parameters: {
          'category_id': categoryId,
          'policy_version': policyVersion,
        },
      );

  static Future<void> logCategorySpecificHelpViewed({
    required String categoryId,
  }) =>
      _safeLog(
        'merchant_claim_category_specific_help_viewed',
        parameters: {'category_id': categoryId},
      );

  static Future<void> logEvidenceUploadStarted({
    required String kind,
  }) =>
      _safeLog(
        'merchant_claim_evidence_upload_started',
        parameters: {'evidence_kind': kind},
      );

  static Future<void> logEvidenceUploadCompleted({
    required String kind,
  }) =>
      _safeLog(
        'merchant_claim_evidence_upload_completed',
        parameters: {'evidence_kind': kind},
      );

  static Future<void> logEvidenceUploadFailed({
    required String kind,
    required String code,
  }) =>
      _safeLog(
        'merchant_claim_evidence_upload_failed',
        parameters: {'evidence_kind': kind, 'error_code': code},
      );

  static Future<void> logSentToManualReview({
    required String categoryId,
    required String policyVersion,
  }) =>
      _safeLog(
        'merchant_claim_sent_to_manual_review',
        parameters: {
          'category_id': categoryId,
          'policy_version': policyVersion,
        },
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
    try {
      await AnalyticsRuntime.service.track(
        event: eventName,
        parameters: parameters ?? const <String, Object?>{},
      );
    } catch (_) {
      // Analytics no bloquea el flujo de claim.
    }
  }
}
