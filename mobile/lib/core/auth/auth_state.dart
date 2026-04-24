import 'package:firebase_auth/firebase_auth.dart';

import 'owner_access_summary.dart';

/// Estado de autenticación de la aplicación.
sealed class AuthState {
  const AuthState();
}

/// Cargando el estado de sesión inicial desde Firebase Auth.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Sin sesión activa.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Sesión activa con usuario autenticado, rol y comercio asociado (si aplica).
class AuthAuthenticated extends AuthState {
  final User user;

  /// Rol del usuario: 'customer' | 'owner' | 'admin'.
  final String role;

  /// Versión de acceso server-side para invalidación de sesión.
  final int accessVersion;

  /// ID del comercio asociado. Null si el owner aún no completó el onboarding.
  final String? merchantId;

  /// Indica si el owner completó el flujo de onboarding de comercio.
  /// Derivado de summary owner y merchantId canónico, no de claims legacy.
  final bool onboardingComplete;

  /// Claim transitorio para alta de owner en proceso.
  final bool ownerPending;

  /// Flags de privilegio administrativo derivados de claims.
  final bool isAdmin;
  final bool isSuperAdmin;

  /// Timestamp Unix de última actualización de claims en backend.
  final int? claimsUpdatedAtSeconds;

  /// Resumen privado de acceso owner. Fuente canónica para contexto OWNER.
  final OwnerAccessSummary? ownerAccessSummary;

  const AuthAuthenticated({
    required this.user,
    required this.role,
    this.accessVersion = 0,
    this.merchantId,
    this.onboardingComplete = false,
    this.ownerPending = false,
    this.isAdmin = false,
    this.isSuperAdmin = false,
    this.claimsUpdatedAtSeconds,
    this.ownerAccessSummary,
  });
}
