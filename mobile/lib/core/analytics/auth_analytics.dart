import 'analytics_runtime.dart';

/// Eventos de analítica del flujo de autenticación TuM2.
///
/// Todos los eventos siguen el patrón `auth_*` para agruparse en Firebase.
/// Los parámetros son snake_case según la convención de Firebase Analytics.
///
/// Para verificar en desarrollo: Firebase DebugView con `--dart-define=FIREBASE_DEBUG=true`
/// o `adb shell setprop debug.firebase.analytics.app com.floki.tum2.staging`.
abstract class AuthAnalytics {
  // ── Nombres de eventos ──────────────────────────────────────────────────────

  static const _kMagicLinkSent = 'auth_magic_link_sent';
  static const _kMagicLinkVerified = 'auth_magic_link_verified';
  static const _kMagicLinkError = 'auth_magic_link_error';
  static const _kGoogleSignIn = 'auth_google_sign_in';
  static const _kGoogleSignInError = 'auth_google_sign_in_error';
  static const _kSignOut = 'auth_sign_out';
  static const _kDisplayNameSet = 'auth_display_name_set';
  static const _kDisplayNameSkipped = 'auth_display_name_skipped';
  static const _kOnboardingStarted = 'auth_onboarding_started';
  static const _kOnboardingSlideViewed = 'auth_onboarding_slide_viewed';
  static const _kOnboardingSkipped = 'auth_onboarding_skipped';
  static const _kOnboardingCompleted = 'auth_onboarding_completed';
  static const _kSplashViewed = 'auth_splash_viewed';
  static const _kSplashTimeout = 'auth_splash_timeout';
  static const _kSplashResolved = 'auth_splash_resolved';

  // ── Parámetros ──────────────────────────────────────────────────────────────

  static const _pIsNewUser = 'is_new_user';
  static const _pErrorCode = 'error_code';
  static const _pIsCrossDevice = 'is_cross_device';
  static const _pSlideIndex = 'slide_index';
  static const _pSlideId = 'slide_id';
  static const _pTotalSlides = 'total_slides';
  static const _pSource = 'source';
  static const _pResult = 'result';
  static const _pSourceScreen = 'source_screen';
  static const _pLatencyMs = 'latency_ms';

  // ── Métodos públicos ────────────────────────────────────────────────────────

  /// Magic link enviado al email del usuario.
  static Future<void> logMagicLinkSent() =>
      _safeLogEvent(name: _kMagicLinkSent);

  /// Magic link procesado exitosamente — usuario autenticado.
  /// [isNewUser] true si es el primer login.
  /// [isCrossDevice] true si el link fue abierto en otro dispositivo.
  static Future<void> logMagicLinkVerified({
    required bool isNewUser,
    required bool isCrossDevice,
  }) =>
      _safeLogEvent(
        name: _kMagicLinkVerified,
        parameters: {
          _pIsNewUser: isNewUser,
          _pIsCrossDevice: isCrossDevice,
        },
      );

  /// Error al procesar el magic link.
  static Future<void> logMagicLinkError(String errorCode) => _safeLogEvent(
        name: _kMagicLinkError,
        parameters: {_pErrorCode: errorCode},
      );

  /// Inicio de sesión con Google exitoso.
  /// [isNewUser] true si es el primer login.
  static Future<void> logGoogleSignIn({required bool isNewUser}) =>
      _safeLogEvent(
        name: _kGoogleSignIn,
        parameters: {_pIsNewUser: isNewUser},
      );

  /// Error al iniciar sesión con Google.
  static Future<void> logGoogleSignInError(String errorCode) => _safeLogEvent(
        name: _kGoogleSignInError,
        parameters: {_pErrorCode: errorCode},
      );

  /// Usuario cerró sesión.
  static Future<void> logSignOut() => _safeLogEvent(name: _kSignOut);

  /// Usuario guardó su displayName en el micro-step AUTH-05.
  static Future<void> logDisplayNameSet() =>
      _safeLogEvent(name: _kDisplayNameSet);

  /// Usuario saltó el micro-step de displayName con "Ahora no".
  static Future<void> logDisplayNameSkipped() =>
      _safeLogEvent(name: _kDisplayNameSkipped);

  static Future<void> logOnboardingStarted({
    required String source,
    required int totalSlides,
  }) =>
      _safeLogEvent(
        name: _kOnboardingStarted,
        parameters: {
          _pSource: source,
          _pTotalSlides: totalSlides,
          _pResult: 'started',
        },
      );

  static Future<void> logOnboardingSlideViewed({
    required int slideIndex,
    required String slideId,
    required int totalSlides,
    required String source,
  }) =>
      _safeLogEvent(
        name: _kOnboardingSlideViewed,
        parameters: {
          _pSlideIndex: slideIndex,
          _pSlideId: slideId,
          _pTotalSlides: totalSlides,
          _pSource: source,
          _pResult: 'viewed',
        },
      );

  static Future<void> logOnboardingSkipped({
    required int slideIndex,
    required String slideId,
    required int totalSlides,
    required String source,
  }) =>
      _safeLogEvent(
        name: _kOnboardingSkipped,
        parameters: {
          _pSlideIndex: slideIndex,
          _pSlideId: slideId,
          _pTotalSlides: totalSlides,
          _pSource: source,
          _pResult: 'skipped',
        },
      );

  static Future<void> logOnboardingCompleted({
    required int slideIndex,
    required String slideId,
    required int totalSlides,
    required String source,
  }) =>
      _safeLogEvent(
        name: _kOnboardingCompleted,
        parameters: {
          _pSlideIndex: slideIndex,
          _pSlideId: slideId,
          _pTotalSlides: totalSlides,
          _pSource: source,
          _pResult: 'completed',
        },
      );

  static Future<void> logSplashViewed({required int latencyMs}) =>
      _safeLogEvent(
        name: _kSplashViewed,
        parameters: {
          _pSourceScreen: 'splash',
          _pResult: 'viewed',
          _pLatencyMs: latencyMs,
        },
      );

  static Future<void> logSplashTimeout({required int latencyMs}) =>
      _safeLogEvent(
        name: _kSplashTimeout,
        parameters: {
          _pSourceScreen: 'splash',
          _pResult: 'timeout',
          _pLatencyMs: latencyMs,
        },
      );

  static Future<void> logSplashResolved({
    required String result,
    required int latencyMs,
  }) =>
      _safeLogEvent(
        name: _kSplashResolved,
        parameters: {
          _pSourceScreen: 'splash',
          _pResult: result,
          _pLatencyMs: latencyMs,
        },
      );

  static Future<void> _safeLogEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await AnalyticsRuntime.service.track(
        event: name,
        parameters: parameters ?? const <String, Object?>{},
      );
    } catch (_) {
      // No-op: analytics nunca debe romper flujos de auth.
    }
  }
}
