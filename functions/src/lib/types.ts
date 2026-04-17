// Shared type definitions for TuM2 Cloud Functions

export type VerificationStatus =
  | "unverified"
  | "referential"
  | "community_submitted"
  | "claimed"
  | "validated"
  | "verified";

export type VisibilityStatus =
  | "visible"
  | "hidden"
  | "suppressed"
  | "review_pending";

export type SourceType = "owner_created" | "external_seed" | "community";

export interface WeeklyScheduleEntry {
  open: string;  // "HH:MM"
  close: string; // "HH:MM"
  closed?: boolean;
}

export type DayOfWeek =
  | "monday"
  | "tuesday"
  | "wednesday"
  | "thursday"
  | "friday"
  | "saturday"
  | "sunday";

export type WeeklySchedule = Partial<Record<DayOfWeek, WeeklyScheduleEntry>>;

export interface MerchantScheduleDoc {
  merchantId: string;
  schedule: WeeklySchedule;
  timezone?: string;
  updatedAt?: FirebaseFirestore.Timestamp;
}

export interface OperationalSignals {
  signalType?: "none" | "vacation" | "temporary_closure" | "delay";
  isActive?: boolean;
  message?: string | null;
  forceClosed?: boolean;
  hasOperationalSignal?: boolean;
  manualOverrideMode?: "none" | "force_closed" | "informational";
  operationalStatusLabel?: string | null;
  ownerUserId?: string;
  updatedByUid?: string;
  schemaVersion?: number;
  isOpenNow?: boolean;
  todayScheduleLabel?: string;
  temporaryClosed?: boolean;
  temporaryClosedNote?: string;
  hasDelivery?: boolean;
  acceptsWhatsappOrders?: boolean;
  openNowManualOverride?: boolean;
  hasPharmacyDutyToday?: boolean;
  manualOverrides?: Record<string, unknown>;
  updatedAt?: FirebaseFirestore.Timestamp;
}

export interface MerchantDoc {
  merchantId: string;
  name: string;
  category: string;
  categoryId?: string;
  zone: string;
  address?: string;
  lat?: number;
  lng?: number;
  geohash?: string;
  zoneId?: string;
  cityId?: string;
  provinceId?: string;
  verificationStatus: VerificationStatus;
  visibilityStatus: VisibilityStatus;
  sourceType: SourceType;
  ownerUserId?: string;
  isPharmacy?: boolean;
  completenessScore?: number;
  lastActivityAt?: FirebaseFirestore.Timestamp;
  externalPlaceId?: string;
  createdAt?: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
}

export interface MerchantProductDoc {
  id?: string;
  merchantId: string;
  ownerUserId: string;
  name: string;
  normalizedName: string;
  priceLabel: string;
  stockStatus: "available" | "out_of_stock";
  visibilityStatus: "visible" | "hidden";
  status: "active" | "inactive";
  imageUrl?: string;
  imagePath?: string;
  imageUploadStatus?: "pending" | "ready" | "failed";
  sourceType: "owner_created";
  createdBy: string;
  updatedBy: string;
  createdAt?: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
}

// ─── Onboarding Owner Types ─────────────────────────────────────────────────

export type OnboardingOwnerStep =
  | "step_1"
  | "step_2"
  | "step_3"
  | "confirmation"
  | "submitted"
  | "completed"
  | "abandoned";

export interface OnboardingStep1Data {
  name: string;
  categoryId: string;
}

export interface OnboardingStep2Data {
  address: string;
  lat: number;
  lng: number;
  geohash: string;
  zoneId: string;
  cityId: string;
  provinceId: string;
}

export interface OnboardingStep3Day {
  open: string;   // "HH:MM"
  close: string;  // "HH:MM"
  closed?: boolean;
}

export type OnboardingStep3Data = Partial<Record<string, OnboardingStep3Day>>;

export interface OnboardingOwnerProgress {
  currentStep: OnboardingOwnerStep;
  draftMerchantId: string | null;
  step1: OnboardingStep1Data | null;
  step2: OnboardingStep2Data | null;
  step3: OnboardingStep3Data | null;
  step3Skipped: boolean;
  startedAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  abandonedAt?: FirebaseFirestore.Timestamp;
}

export interface MerchantPublicDoc {
  merchantId: string;
  name: string;
  category: string;
  categoryId?: string;
  zone: string;
  zoneId?: string;
  address?: string;
  verificationStatus: VerificationStatus;
  visibilityStatus: VisibilityStatus;
  isOpenNow?: boolean;
  hasOperationalSignal?: boolean;
  operationalSignalType?: "none" | "vacation" | "temporary_closure" | "delay";
  operationalSignalMessage?: string | null;
  operationalSignalUpdatedAt?: FirebaseFirestore.Timestamp | null;
  manualOverrideMode?: "none" | "force_closed" | "informational";
  operationalStatusLabel?: string | null;
  todayScheduleLabel?: string;
  hasPharmacyDutyToday?: boolean;
  isOnDutyToday?: boolean;
  confidenceLevel?: "high" | "medium" | "low" | null;
  publicStatusLabel?:
    | "guardia_confirmada"
    | "guardia_en_verificacion"
    | "cambio_operativo_en_curso"
    | null;
  operationalSignals?: OperationalSignals;
  sortBoost: number;
  searchKeywords?: string[];
  isPharmacy?: boolean;
  syncedAt: FirebaseFirestore.Timestamp;
}

export interface ZoneCoverageMetrics {
  merchantCount: number;
  visibleMerchantCount: number;
  pharmacyCount: number;
  verifiedCount: number;
  referentialCount: number;
  communitySubmittedCount: number;
  usefulCoverageScore: number;
  updatedAt?: FirebaseFirestore.Timestamp;
}

export interface ExternalPlaceDoc {
  externalId: string;
  sourceType: "google_places" | string;
  rawName: string;
  rawCategory: string;
  rawAddress: string;
  rawLat?: number;
  rawLng?: number;
  zoneId: string;
  importBatchId: string;
  linkedMerchantId?: string;
  normalizedAt?: FirebaseFirestore.Timestamp;
  createdAt?: FirebaseFirestore.Timestamp;
}

export interface ImportBatchDoc {
  batchId: string;
  zoneId: string;
  sourceType: string;
  startedAt: FirebaseFirestore.Timestamp;
  completedAt?: FirebaseFirestore.Timestamp;
  status: "running" | "completed" | "failed";
  inputCount: number;
  createdCount: number;
  linkedCount: number;
  skippedCount: number;
  estimatedCost?: number;
  error?: string;
}

export interface MerchantClaimDoc {
  claimId: string;
  merchantId: string;
  userId: string;
  claimStatus:
    | "draft"
    | "submitted"
    | "under_review"
    | "needs_more_info"
    | "approved"
    | "rejected"
    | "duplicate_claim"
    | "conflict_detected";
  userVisibleStatus?:
    | "draft"
    | "submitted"
    | "under_review"
    | "needs_more_info"
    | "approved"
    | "rejected"
    | "duplicate_claim"
    | "conflict_detected";
  internalWorkflowStatus?:
    | "draft_editing"
    | "auto_validation_running"
    | "auto_validation_passed"
    | "auto_validation_blocked_rejected"
    | "auto_validation_blocked_conflict"
    | "auto_validation_blocked_duplicate"
    | "auto_validation_needs_more_info"
    | "manual_resolution_completed";
  workflowManagedBy?: string;
  authenticatedEmail: string;
  declaredRole: "owner" | "co_owner" | "authorized_representative";
  categoryId: string;
  zoneId: string;
  storefrontPhotoUploaded: boolean;
  ownershipDocumentUploaded: boolean;
  hasAcceptedDataProcessingConsent: boolean;
  hasAcceptedLegitimacyDeclaration: boolean;
  submittedAt?: FirebaseFirestore.Timestamp | null;
  autoValidationStatus?: "running" | "passed" | "blocked" | null;
  autoValidationReasons?: string[];
  autoValidationCompletedAt?: FirebaseFirestore.Timestamp | null;
  duplicateOfClaimId?: string | null;
  conflictType?: string | null;
  hasConflict?: boolean;
  hasDuplicate?: boolean;
  requiresManualReview?: boolean;
  missingEvidence?: boolean;
  missingEvidenceTypes?: string[];
  riskFlags?: string[];
  riskPriority?: "low" | "medium" | "high" | "critical" | null;
  reviewQueuePriority?: number | null;
  lastAutoValidationHash?: string | null;
  processedBySystem?: boolean;
  systemVersion?: string | null;
  phoneMasked?: string | null;
  claimantDisplayNameMasked?: string | null;
  claimantNoteMasked?: string | null;
  createdAt?: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
  reviewedAt?: FirebaseFirestore.Timestamp;
}

export interface ReportDoc {
  reportId: string;
  targetId: string;
  targetType: "merchant" | "product" | "signal";
  reason: string;
  status: "open" | "resolved" | "dismissed";
  reportedBy: string;
  createdAt?: FirebaseFirestore.Timestamp;
}

export interface DedupeResult {
  matched: boolean;
  merchantId?: string;
  confidence?: number;
}
