// ── Users ────────────────────────────────────────────────────────────────────
export type { UserDocument, UserRole, UserStatus } from './user';

// ── Zones ────────────────────────────────────────────────────────────────────
export type {
  ZoneDocument,
  ZoneStatus,
  ZoneLaunchPhase,
  ZoneBounds,
  ZoneCoverageMetrics,
} from './zone';

// ── Merchants (canonical) ────────────────────────────────────────────────────
export type {
  MerchantDocument,
  MerchantStatus,
  MerchantVisibilityStatus,
  MerchantVerificationStatus,
  MerchantSourceType,
  MerchantLocation,
  MerchantContact,
  ConfidenceLevel,
} from './merchant';

// ── Merchant public view ─────────────────────────────────────────────────────
export type {
  MerchantPublicDocument,
  MerchantBadge,
  OperationalSignalsSnapshot,
} from './merchant_public';

// ── Merchant schedules ───────────────────────────────────────────────────────
export type {
  MerchantSchedulesDocument,
  WeeklySchedule,
  DaySchedule,
  DayOfWeek,
  ScheduleSlot,
  ScheduleException,
} from './merchant_schedules';

// ── Merchant operational signals ─────────────────────────────────────────────
export type {
  MerchantOperationalSignalsDocument,
  OperationalSignals,
  DerivedSignals,
  IsOpenNowSource,
  IsOpenNowConfidence,
} from './merchant_operational_signals';

// ── Merchant products ────────────────────────────────────────────────────────
export type {
  MerchantProductDocument,
  ProductStatus,
  ProductVisibilityStatus,
  ProductStockStatus,
} from './merchant_products';

// ── Pharmacy duties ──────────────────────────────────────────────────────────
export type {
  PharmacyDutyDocument,
  PharmacyDutyStatus,
  PharmacyDutyVerificationStatus,
} from './pharmacy_duties';

// ── External places ──────────────────────────────────────────────────────────
export type {
  ExternalPlaceDocument,
  ExternalPlaceSource,
  ExternalPlaceImportStatus,
} from './external_places';

// ── Import batches ───────────────────────────────────────────────────────────
export type { ImportBatchDocument, ImportBatchStatus } from './import_batches';

// ── Merchant claims ──────────────────────────────────────────────────────────
export type {
  MerchantClaimDocument,
  MerchantClaimStatus,
  ClaimEvidence,
} from './merchant_claims';

// ── Reports ──────────────────────────────────────────────────────────────────
export type {
  ReportDocument,
  ReportTargetType,
  ReportType,
  ReportStatus,
} from './reports';

// ── Admin configs ────────────────────────────────────────────────────────────
export type {
  AdminConfigGlobal,
  ZonePublicationRules,
  BootstrapRules,
  FeatureFlags,
} from './admin_configs';

// ── Onboarding owner progress ─────────────────────────────────────────────────
export type {
  OnboardingOwnerProgress,
  OnboardingOwnerStep,
  OnboardingStep1Data,
  OnboardingStep2Data,
} from './onboarding_owner';
