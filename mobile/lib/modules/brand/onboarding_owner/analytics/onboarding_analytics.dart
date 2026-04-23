import '../../../../core/analytics/analytics_runtime.dart';

/// AN-01 — OnboardingAnalytics
///
/// Tracking de todos los eventos del flujo de onboarding OWNER.
/// Se integra en OnboardingOwnerFlow en cada transición de estado.
///
/// Eventos definidos en TuM2-0082 / ONBOARDING-OWNER-FSM.md.
class OnboardingAnalytics {
  // ─── Flujo principal ────────────────────────────────────────────────────

  static Future<void> logStarted() => _track('onboarding_owner_started');

  static Future<void> logStepCompleted(String step) =>
      _track('onboarding_owner_step_completed', {'step': step});

  static Future<void> logStep3Skipped() =>
      _track('onboarding_owner_step_3_skipped');

  static Future<void> logSubmitted() => _track('onboarding_owner_submitted');

  static Future<void> logCompleted() => _track('onboarding_owner_completed');

  static Future<void> logExited(String step) =>
      _track('onboarding_owner_exited', {'step': step});

  // ─── Draft ──────────────────────────────────────────────────────────────

  static Future<void> logDraftResumed() =>
      _track('onboarding_owner_draft_resumed');

  static Future<void> logDraftDiscarded() =>
      _track('onboarding_owner_draft_discarded');

  // ─── Errores ────────────────────────────────────────────────────────────

  static Future<void> logError(String step, String errorCode) =>
      _track('onboarding_owner_error', {'step': step, 'error_code': errorCode});

  // ─── Duplicados ─────────────────────────────────────────────────────────

  static Future<void> logDuplicateSoft() =>
      _track('onboarding_owner_duplicate_soft');

  static Future<void> logDuplicateHard() =>
      _track('onboarding_owner_duplicate_hard');

  static Future<void> _track(
    String event, [
    Map<String, Object?> parameters = const <String, Object?>{},
  ]) async {
    try {
      await AnalyticsRuntime.service
          .track(event: event, parameters: parameters);
    } catch (_) {
      // Analytics nunca debe romper onboarding.
    }
  }
}
