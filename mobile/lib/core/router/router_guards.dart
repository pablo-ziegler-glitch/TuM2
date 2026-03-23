import '../auth/auth_state.dart';
import 'app_routes.dart';

/// Lógica de guards de navegación, extraída del router para ser testeable
/// de forma independiente sin Firebase ni Riverpod.
abstract class RouterGuards {
  /// Rutas accesibles sin sesión activa.
  static const publicPaths = {
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.emailVerification,
  };

  /// Devuelve true si el path no requiere sesión activa.
  static bool isPublicPath(String path) {
    if (publicPaths.contains(path)) return true;
    // /commerce/:id y /pharmacy/:id son públicos (contenido visible sin login)
    if (path.startsWith('/commerce/')) return true;
    if (path.startsWith('/pharmacy/')) return true;
    // La vista listado de farmacias de turno también es pública
    if (path == AppRoutes.homeFarmacias) return true;
    return false;
  }

  /// Devuelve true si el path pertenece al Auth Stack.
  static bool isAuthPath(String path) => publicPaths.contains(path);

  /// Verifica si el rol tiene acceso a la ruta dada.
  static bool canAccessRoute(String route, String role) {
    if (route.startsWith('/owner') && role == 'customer') return false;
    if (route.startsWith('/admin') && role != 'admin') return false;
    return true;
  }

  /// Evalúa el redirect necesario dado el estado de auth y la ubicación actual.
  ///
  /// Devuelve null si no se necesita redirect (se permite la navegación).
  /// Devuelve un path de destino si se debe redirigir.
  ///
  /// [pendingRoute] es la ruta pendiente guardada antes de que el usuario
  /// se autenticara (deep link pre-auth).
  /// [consumePendingRoute] es un callback para limpiar el pending route.
  static String? evaluate({
    required AuthState authState,
    required String location,
    String? pendingRoute,
    void Function()? consumePendingRoute,
  }) {
    switch (authState) {
      case AuthLoading():
        if (location == AppRoutes.splash) return null;
        return AppRoutes.splash;

      case AuthUnauthenticated():
        if (isPublicPath(location)) return null;
        return AppRoutes.login;

      case AuthAuthenticated(:final role, :final onboardingComplete):
        // Desde ruta de auth → navegar al destino autenticado
        if (isAuthPath(location)) {
          return _authenticatedHome(
            role: role,
            onboardingComplete: onboardingComplete,
            pendingRoute: pendingRoute,
            consumePendingRoute: consumePendingRoute,
          );
        }

        // Owner que no completó el onboarding → redirigir a flujo de alta
        if (role == 'owner' &&
            !onboardingComplete &&
            !location.startsWith('/onboarding/owner')) {
          return AppRoutes.onboardingOwner;
        }

        // Guard: /owner solo owner o admin
        if (location.startsWith('/owner') && role == 'customer') {
          return AppRoutes.profile;
        }

        // Guard: /admin solo admin
        if (location.startsWith('/admin') && role != 'admin') {
          return AppRoutes.home;
        }

        return null;
    }
  }

  static String _authenticatedHome({
    required String role,
    required bool onboardingComplete,
    String? pendingRoute,
    void Function()? consumePendingRoute,
  }) {
    if (pendingRoute != null && canAccessRoute(pendingRoute, role)) {
      consumePendingRoute?.call();
      return pendingRoute;
    }
    if (role == 'owner' && !onboardingComplete) {
      return AppRoutes.onboardingOwner;
    }
    return AppRoutes.home;
  }
}
