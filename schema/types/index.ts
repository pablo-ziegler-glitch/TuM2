// ── Users ────────────────────────────────────────────────────────────────────
export type { UserDocument, UserRole, UserStatus, TrustLevel } from './user';

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
  MerchantOwnershipStatus,
  MerchantSourceType,
  MerchantLocation,
  MerchantContact,
  MerchantCatalogLimits,
  MerchantCatalogStats,
  ConfidenceLevel,
  OwnerDisplay,
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
  MerchantOperationalSignalType,
  ManualOverrideMode,
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
  PharmacyDutyConfirmationStatus,
  PharmacyDutySourceType,
  PharmacyDutyConfidenceLevel,
  PharmacyDutyPublicStatusLabel,
  PharmacyDutyStatus,
  PharmacyDutyVerificationStatus,
} from './pharmacy_duties';
export type {
  PharmacyDutyIncidentDocument,
  PharmacyDutyIncidentType,
  PharmacyDutyIncidentStatus,
} from './pharmacy_duty_incidents';
export type {
  PharmacyDutyReassignmentRoundDocument,
  PharmacyDutyReassignmentRoundStatus,
} from './pharmacy_duty_reassignment_rounds';
export type {
  PharmacyDutyReassignmentRequestDocument,
  PharmacyDutyReassignmentRequestStatus,
  PharmacyDutyReassignmentResponseReason,
} from './pharmacy_duty_reassignment_requests';

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
  ClaimEvidenceType,
} from './merchant_claims';

// ── Reports ──────────────────────────────────────────────────────────────────
export type {
  ReportDocument,
  ReportTargetType,
  ReportType,
  ReportStatus,
} from './reports';

// ── Contributions ────────────────────────────────────────────────────────────
export type {
  ContributionDocument,
  ContributionTargetType,
  ContributionType,
  ContributionStatus,
  ContributionReviewMode,
} from './contributions';

// ── Conversations & messages ──────────────────────────────────────────────────
export type {
  ConversationDocument,
  ConversationStatus,
  ConversationType,
  MessageDocument,
  MessageType,
  MessageStatus,
  MessageSenderRole,
} from './conversations';

// ── Favorites ────────────────────────────────────────────────────────────────
export type { FavoriteDocument } from './favorites';

// ── Feedback ─────────────────────────────────────────────────────────────────
export type {
  FeedbackDocument,
  FeedbackType,
  FeedbackChannel,
  FeedbackStatus,
} from './feedback';

// ── Categories & subcategories ───────────────────────────────────────────────
export type { CategoryDocument, SubcategoryDocument } from './categories';

// ── Moderation queue ─────────────────────────────────────────────────────────
export type {
  ModerationQueueDocument,
  ModerationEntityType,
  ModerationPriority,
  ModerationStatus,
} from './moderation_queue';

// ── Audit logs ───────────────────────────────────────────────────────────────
export type {
  AuditLogDocument,
  AuditEntityType,
  AuditAction,
  AuditSource,
  AuditFieldChange,
} from './audit_logs';

// ── Entity versions ───────────────────────────────────────────────────────────
export type {
  EntityVersionDocument,
  VersionedEntityType,
} from './entity_versions';

// ── Admin configs ────────────────────────────────────────────────────────────
export type {
  AdminConfigGlobal,
  CatalogLimitsConfig,
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
