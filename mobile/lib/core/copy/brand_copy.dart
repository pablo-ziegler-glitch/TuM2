/// Copys canónicos de marca para TuM2 (Tarjeta TuM2-0002).
///
/// Fuente de verdad:
/// - Claim primario: "Lo que necesitás, en tu zona."
/// - Jerarquía de claims definida en docs/branding/TuM2-0002-claim-principal.md
abstract final class BrandCopy {
  static const primaryClaim = 'Lo que necesitás, en tu zona.';
  static const secondaryCampaignClaim = 'Lo útil, a metros.';
  static const activationClaim = 'Abrí TuM2 y resolvés.';
  static const trustClaim = 'Comercios reales, cerca tuyo.';

  static const institutionalSubtitle =
      'Encontrá comercios, farmacias de turno y datos útiles cerca tuyo.';

  static const onboardingInitialSubtitle =
      'TuM2 te ayuda a encontrar soluciones locales cerca tuyo, cuando las necesitás.';
}
