/// Constantes de rutas de la aplicación.
abstract class AppRoutes {
  // ── Auth Stack ──────────────────────────────────────────────────────────────
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const emailVerification = '/email-verification';

  /// Micro-step de nombre de usuario para nuevos usuarios de magic link.
  /// Se muestra solo cuando user.displayName es null/vacío tras el primer login.
  static const displayName = '/auth/display-name';

  // ── CustomerTabs — Tab Inicio ───────────────────────────────────────────────
  static const home = '/home';
  static const homeAbiertoAhora = '/home/abierto-ahora';
  static const homeFarmacias = '/home/farmacias-de-turno';

  // ── CustomerTabs — Tab Buscar ───────────────────────────────────────────────
  static const search = '/search';
  static const searchResults = '/search/resultados';
  static const searchMap = '/search/mapa';
  static const searchFarmacias = '/search/farmacias';
  static const searchLocationFallback = '/search/ubicacion';

  // ── CustomerTabs — Tab Perfil ───────────────────────────────────────────────
  static const profile = '/profile';
  static const profileSettings = '/profile/settings';
  static const profileProposals = '/profile/propuestas';

  // ── OwnerStack (modal full-screen) ──────────────────────────────────────────
  static const owner = '/owner';
  static const ownerEdit = '/owner/edit';
  static const ownerProducts = '/owner/products';
  static const ownerSchedules = '/owner/schedules';
  static const ownerDuties = '/owner/duties';

  // ── AdminStack (modal full-screen) ──────────────────────────────────────────
  static const admin = '/admin';
  static const adminMerchants = '/admin/merchants';
  static const adminSignals = '/admin/signals';

  // ── Shared Screens ──────────────────────────────────────────────────────────
  static const commerceDetail = '/commerce/:id';
  static const onboardingOwner = '/onboarding/owner';

  // ── Pharmacy ─────────────────────────────────────────────────────────────────
  static const pharmacyDutyDetail = '/pharmacy/:id';

  /// Construye la ruta concreta de detalle de un comercio.
  static String commerceDetailPath(String id) => '/commerce/$id';

  /// Construye la ruta concreta de detalle de una farmacia de turno.
  static String pharmacyDutyDetailPath(String id) => '/pharmacy/$id';
}
