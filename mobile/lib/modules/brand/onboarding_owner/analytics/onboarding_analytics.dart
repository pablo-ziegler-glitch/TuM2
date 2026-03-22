import 'package:firebase_analytics/firebase_analytics.dart';

/// AN-01 — OnboardingAnalytics
///
/// Tracking de todos los eventos del flujo de onboarding OWNER.
/// Se integra en OnboardingOwnerFlow en cada transición de estado.
///
/// Eventos definidos en TuM2-0082 / ONBOARDING-OWNER-FSM.md.
class OnboardingAnalytics {
  static final _analytics = FirebaseAnalytics.instance;

  // ─── Flujo principal ────────────────────────────────────────────────────

  static Future<void> logStarted() =>
      _analytics.logEvent(name: 'onboarding_owner_started');

  static Future<void> logStepCompleted(String step) =>
      _analytics.logEvent(
        name: 'onboarding_owner_step_completed',
        parameters: {'step': step},
      );

  static Future<void> logStep3Skipped() =>
      _analytics.logEvent(name: 'onboarding_owner_step_3_skipped');

  static Future<void> logSubmitted() =>
      _analytics.logEvent(name: 'onboarding_owner_submitted');

  static Future<void> logCompleted() =>
      _analytics.logEvent(name: 'onboarding_owner_completed');

  static Future<void> logExited(String step) =>
      _analytics.logEvent(
        name: 'onboarding_owner_exited',
        parameters: {'step': step},
      );

  // ─── Draft ──────────────────────────────────────────────────────────────

  static Future<void> logDraftResumed() =>
      _analytics.logEvent(name: 'onboarding_owner_draft_resumed');

  static Future<void> logDraftDiscarded() =>
      _analytics.logEvent(name: 'onboarding_owner_draft_discarded');

  // ─── Errores ────────────────────────────────────────────────────────────

  static Future<void> logError(String step, String errorCode) =>
      _analytics.logEvent(
        name: 'onboarding_owner_error',
        parameters: {'step': step, 'error_code': errorCode},
      );

  // ─── Duplicados ─────────────────────────────────────────────────────────

  static Future<void> logDuplicateSoft() =>
      _analytics.logEvent(name: 'onboarding_owner_duplicate_soft');

  static Future<void> logDuplicateHard() =>
      _analytics.logEvent(name: 'onboarding_owner_duplicate_hard');
}
