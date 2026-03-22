import 'package:firebase_auth/firebase_auth.dart';

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

  /// ID del comercio asociado. Null si el owner aún no completó el onboarding.
  final String? merchantId;

  const AuthAuthenticated({
    required this.user,
    required this.role,
    this.merchantId,
  });
}
