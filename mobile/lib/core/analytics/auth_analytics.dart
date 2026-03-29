import 'package:firebase_analytics/firebase_analytics.dart';

/// Eventos de analítica del flujo de autenticación TuM2.
///
/// Todos los eventos siguen el patrón `auth_*` para agruparse en Firebase.
/// Los parámetros son snake_case según la convención de Firebase Analytics.
///
/// Para verificar en desarrollo: Firebase DebugView con `--dart-define=FIREBASE_DEBUG=true`
/// o `adb shell setprop debug.firebase.analytics.app com.tum2.app`.
abstract class AuthAnalytics {
  static final _analytics = FirebaseAnalytics.instance;

  // ── Nombres de eventos ──────────────────────────────────────────────────────

  static const _kMagicLinkSent = 'auth_magic_link_sent';
  static const _kMagicLinkVerified = 'auth_magic_link_verified';
  static const _kMagicLinkError = 'auth_magic_link_error';
  static const _kGoogleSignIn = 'auth_google_sign_in';
  static const _kGoogleSignInError = 'auth_google_sign_in_error';
  static const _kSignOut = 'auth_sign_out';
  static const _kDisplayNameSet = 'auth_display_name_set';
  static const _kDisplayNameSkipped = 'auth_display_name_skipped';

  // ── Parámetros ──────────────────────────────────────────────────────────────

  static const _pIsNewUser = 'is_new_user';
  static const _pErrorCode = 'error_code';
  static const _pIsCrossDevice = 'is_cross_device';

  // ── Métodos públicos ────────────────────────────────────────────────────────

  /// Magic link enviado al email del usuario.
  static Future<void> logMagicLinkSent() => _analytics.logEvent(
        name: _kMagicLinkSent,
      );

  /// Magic link procesado exitosamente — usuario autenticado.
  /// [isNewUser] true si es el primer login.
  /// [isCrossDevice] true si el link fue abierto en otro dispositivo.
  static Future<void> logMagicLinkVerified({
    required bool isNewUser,
    required bool isCrossDevice,
  }) =>
      _analytics.logEvent(
        name: _kMagicLinkVerified,
        parameters: {
          _pIsNewUser: isNewUser,
          _pIsCrossDevice: isCrossDevice,
        },
      );

  /// Error al procesar el magic link.
  static Future<void> logMagicLinkError(String errorCode) =>
      _analytics.logEvent(
        name: _kMagicLinkError,
        parameters: {_pErrorCode: errorCode},
      );

  /// Inicio de sesión con Google exitoso.
  /// [isNewUser] true si es el primer login.
  static Future<void> logGoogleSignIn({required bool isNewUser}) =>
      _analytics.logEvent(
        name: _kGoogleSignIn,
        parameters: {_pIsNewUser: isNewUser},
      );

  /// Error al iniciar sesión con Google.
  static Future<void> logGoogleSignInError(String errorCode) =>
      _analytics.logEvent(
        name: _kGoogleSignInError,
        parameters: {_pErrorCode: errorCode},
      );

  /// Usuario cerró sesión.
  static Future<void> logSignOut() => _analytics.logEvent(
        name: _kSignOut,
      );

  /// Usuario guardó su displayName en el micro-step AUTH-05.
  static Future<void> logDisplayNameSet() => _analytics.logEvent(
        name: _kDisplayNameSet,
      );

  /// Usuario saltó el micro-step de displayName con "Ahora no".
  static Future<void> logDisplayNameSkipped() => _analytics.logEvent(
        name: _kDisplayNameSkipped,
      );
}
