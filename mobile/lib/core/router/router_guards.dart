import '../auth/auth_state.dart';
import 'app_routes.dart';

/// Lógica de guards de navegación, extraída del router para ser testeable
/// de forma independiente sin Firebase ni Riverpod.
abstract class RouterGuards {
  /// Rutas del stack de autenticación.
  static const authPaths = {
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.emailVerification,
  };

  /// Rutas navegables en modo invitado.
  static const guestPaths = {
    AppRoutes.home,
    AppRoutes.homeAbiertoAhora,
    AppRoutes.homeFarmacias,
    AppRoutes.search,
    AppRoutes.searchResults,
    AppRoutes.searchMap,
    AppRoutes.searchFarmacias,
    AppRoutes.searchLocationFallback,
  };

  /// Devuelve true si el path no requiere sesión activa.
  static bool isPublicPath(String path) {
    path = _pathOnly(path);
    if (authPaths.contains(path) || guestPaths.contains(path)) return true;
    // /commerce/:id y /pharmacy/:id son públicos (contenido visible sin login)
    if (path.startsWith('/commerce/')) return true;
    if (path.startsWith('/pharmacy/')) return true;
    return false;
  }

  /// Devuelve true si el path pertenece al Auth Stack.
  static bool isAuthPath(String path) => authPaths.contains(_pathOnly(path));

  /// Ruta de entrada para usuario sin sesión.
  static String unauthenticatedEntryPath({required bool isFirstLaunch}) {
    return isFirstLaunch ? AppRoutes.onboarding : AppRoutes.home;
  }

  /// Verifica si el rol tiene acceso a la ruta dada.
  static bool canAccessRoute(String route, String role) {
    route = _pathOnly(route);
    if (route.startsWith('/owner') &&
        role != 'owner' &&
        role != 'admin' &&
        role != 'super_admin') {
      return false;
    }
    if (route.startsWith('/admin') &&
        role != 'admin' &&
        role != 'super_admin') {
      return false;
    }
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
    final path = _pathOnly(location);

    switch (authState) {
      case AuthLoading():
        if (path == AppRoutes.splash) return null;
        return AppRoutes.splash;

      case AuthUnauthenticated():
        if (isPublicPath(path)) return null;
        return AppRoutes.login;

      case AuthAuthenticated(:final role, :final ownerPending):
        // Desde ruta de auth → navegar al destino autenticado
        if (isAuthPath(path)) {
          return _authenticatedHome(
            role: role,
            ownerPending: ownerPending,
            pendingRoute: pendingRoute,
            consumePendingRoute: consumePendingRoute,
          );
        }

        // Guard: /owner solo owner o admin
        final isOwnerRoute = path.startsWith('/owner');
        final isOwnerRole = role == 'owner';
        final canAccessAsAdmin = role == 'admin' || role == 'super_admin';
        if (isOwnerRoute && !isOwnerRole && !canAccessAsAdmin) {
          return AppRoutes.profile;
        }
        if (isOwnerRoute &&
            isOwnerRole &&
            ownerPending &&
            path == AppRoutes.ownerResolve) {
          return AppRoutes.ownerDashboard;
        }
        if (isOwnerRoute &&
            isOwnerRole &&
            ownerPending &&
            path != AppRoutes.owner &&
            path != AppRoutes.ownerDashboard) {
          return AppRoutes.ownerDashboard;
        }

        // Guard: /admin solo admin o super_admin
        if (path.startsWith('/admin') &&
            role != 'admin' &&
            role != 'super_admin') {
          return AppRoutes.home;
        }

        return null;
    }
  }

  static String _authenticatedHome({
    required String role,
    required bool ownerPending,
    String? pendingRoute,
    void Function()? consumePendingRoute,
  }) {
    final isOwner = role == 'owner';
    if (pendingRoute != null &&
        !isAuthPath(pendingRoute) &&
        canAccessRoute(pendingRoute, role) &&
        !(ownerPending && _pathOnly(pendingRoute).startsWith('/owner'))) {
      consumePendingRoute?.call();
      return pendingRoute;
    }
    if (isOwner && ownerPending) return AppRoutes.ownerDashboard;
    if (isOwner) return AppRoutes.ownerResolve;
    return AppRoutes.home;
  }

  /// Extrae solo el path de una ubicación que puede incluir querystring.
  static String _pathOnly(String location) {
    try {
      return Uri.parse(location).path;
    } catch (_) {
      return location;
    }
  }
}
