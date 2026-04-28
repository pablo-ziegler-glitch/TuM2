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
  static const profileHelp = '/profile/help';
  static const profileSettings = '/profile/settings';
  static const profileProposals = '/profile/propuestas';
  static const claimIntro = '/claim';
  static const claimSelect = '/claim/select';
  static const claimApplicant = '/claim/applicant';
  static const claimEvidence = '/claim/evidence';
  static const claimConsent = '/claim/consent';
  static const claimSuccess = '/claim/success';
  static const claimStatus = '/claim/status';
  static const accessUpdated = '/access-updated';

  // ── OwnerStack (modal full-screen) ──────────────────────────────────────────
  static const ownerRoot = '/owner';
  static const ownerResolve = '/owner/resolve';
  static const ownerDashboard = '/owner/dashboard';
  static const owner = ownerRoot;
  static const ownerEdit = '/owner/edit';
  static const ownerProducts = '/owner/products';
  static const ownerProductsNew = '/owner/products/new';
  static const ownerProductsEdit = '/owner/products/:productId/edit';
  static const ownerProductsSaved = '/owner/products/saved';
  static const ownerSchedules = '/owner/schedules';
  static const ownerSignals = '/owner/signals';
  static const ownerPharmacyDuties = '/owner/pharmacy-duties';
  static const ownerDuties = '/owner/duties';
  static const ownerPharmacyDutyNew = '/owner/pharmacy-duties/new';
  static const ownerPharmacyDutyEdit = '/owner/pharmacy-duties/:dutyId/edit';
  static const ownerPharmacyDutyUpcoming = '/owner/pharmacy-duty/upcoming';
  static const ownerPharmacyDutyIncidentReport =
      '/owner/pharmacy-duty/:dutyId/report-incident';
  static const ownerPharmacyDutySelectCandidates =
      '/owner/pharmacy-duty/:dutyId/select-candidates';
  static const ownerPharmacyDutyTracking =
      '/owner/pharmacy-duty/:dutyId/tracking';
  static const ownerPharmacyDutyCoverageInvitation =
      '/owner/pharmacy-duty/invitation/:requestId';
  static const ownerPharmacyDutyCoverageResult =
      '/owner/pharmacy-duty/invitation-result';
  static const ownerPharmacyDutyPublicStatus =
      '/owner/pharmacy-duty/public-status';

  // ── AdminStack (modal full-screen) ──────────────────────────────────────────
  static const admin = '/admin';
  static const adminMerchants = '/admin/merchants';
  static const adminSignals = '/admin/signals';

  // ── Shared Screens ──────────────────────────────────────────────────────────
  static const commerceDetail = '/commerce/:merchantId';
  static const commerceProductDetail =
      '/commerce/:merchantId/product/:productId';
  static const onboardingOwner = '/onboarding/owner';

  // ── Pharmacy ─────────────────────────────────────────────────────────────────
  static const pharmacyDutyDetail = '/pharmacy/:id';

  static String onboardingPath({String? source}) {
    final normalized = source?.trim();
    if (normalized == null || normalized.isEmpty) return onboarding;
    return Uri(
      path: onboarding,
      queryParameters: {'source': normalized},
    ).toString();
  }

  /// Construye la ruta concreta de detalle de un comercio.
  static String commerceDetailPath(String merchantId, {String? source}) {
    final path = '/commerce/$merchantId';
    final normalized = source?.trim();
    if (normalized == null || normalized.isEmpty) return path;
    return Uri(path: path, queryParameters: {'source': normalized}).toString();
  }

  /// Construye la ruta concreta de detalle de un producto del comercio.
  static String commerceProductDetailPath({
    required String merchantId,
    required String productId,
  }) =>
      '/commerce/$merchantId/product/$productId';

  static String ownerProductsEditPath(String productId) =>
      '/owner/products/$productId/edit';

  static String ownerPharmacyDutyIncidentReportPath(String dutyId) =>
      '/owner/pharmacy-duty/$dutyId/report-incident';

  static String ownerPharmacyDutyEditPath(String dutyId) =>
      '/owner/pharmacy-duties/$dutyId/edit';

  static String ownerPharmacyDutyNewPath({String? date}) {
    if (date == null || date.isEmpty) return ownerPharmacyDutyNew;
    return '$ownerPharmacyDutyNew?date=$date';
  }

  static String ownerPharmacyDutySelectCandidatesPath(String dutyId) =>
      '/owner/pharmacy-duty/$dutyId/select-candidates';

  static String ownerPharmacyDutyTrackingPath(String dutyId) =>
      '/owner/pharmacy-duty/$dutyId/tracking';

  static String ownerPharmacyDutyCoverageInvitationPath(String requestId) =>
      '/owner/pharmacy-duty/invitation/$requestId';

  static String ownerPharmacyDutyCoverageResultPath({
    required String status,
    required String action,
  }) =>
      '/owner/pharmacy-duty/invitation-result?status=$status&action=$action';

  static String ownerPharmacyDutyPublicStatusPath() =>
      '/owner/pharmacy-duty/public-status';

  static String accessUpdatedPath({
    required String target,
    required String reason,
    String? from,
  }) {
    final query = <String, String>{
      'target': target,
      'reason': reason,
      if (from != null && from.isNotEmpty) 'from': from,
    };
    return Uri(path: accessUpdated, queryParameters: query).toString();
  }

  /// Construye la ruta concreta de detalle de una farmacia de turno.
  static String pharmacyDutyDetailPath(String id) => '/pharmacy/$id';
}
