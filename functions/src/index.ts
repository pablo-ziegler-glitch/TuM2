import { initializeApp } from "firebase-admin/app";

// Initialize Firebase Admin SDK once
initializeApp();

// ─── Auth Triggers ─────────────────────────────────────────────────────────

export { onUserCreate } from "./triggers/onUserCreate";
export { onUserDelete } from "./triggers/onUserDelete";

// ─── Auth Callables ────────────────────────────────────────────────────────

export { assignOwnerRole } from "./callables/assignOwnerRole";

// ─── Firestore Triggers ────────────────────────────────────────────────────

export { onMerchantWriteSyncPublic } from "./triggers/merchants";
export { onMerchantProductWriteRecalculateHasProducts } from "./triggers/products";
export { onScheduleWriteRecalculateOpenNow } from "./triggers/schedules";
export {
  onOwnerWeeklyScheduleWrite,
  onOwnerScheduleExceptionWrite,
  onOwnerScheduleRangeWrite,
} from "./triggers/ownerSchedules";
export { onSignalsWriteSyncPublic } from "./triggers/signals";
export { onPharmacyDutyWriteSyncMerchant } from "./triggers/duties";
export {
  onClaimSubmittedRunAutoValidation,
  onClaimApprovedPromoteMerchant,
} from "./triggers/claims";
export { onReportThresholdSuppressMerchant } from "./triggers/reports";
export { onExternalPlaceCreateNormalize } from "./triggers/externalPlaces";

// ─── Scheduled Jobs ────────────────────────────────────────────────────────

export { nightlyRefreshOpenStatuses } from "./jobs/refreshOpenStatuses";
export { nightlyRefreshPharmacyDutyFlags } from "./jobs/refreshDuties";

// ─── Zone Coverage ─────────────────────────────────────────────────────────

export { updateZoneCoverageMetrics, scheduledRefreshZoneCoverage } from "./coverage/zoneCoverage";

// ─── Owner Onboarding Callables ────────────────────────────────────────────

export { onboardingOwnerSubmit } from "./callables/onboardingOwnerSubmit";
export { checkMerchantDuplicates } from "./callables/checkMerchantDuplicates";
export {
  upsertPharmacyDuty,
  upsertPharmacyDutiesBatch,
  changePharmacyDutyStatus,
  confirmPharmacyDuty,
  reportPharmacyDutyIncident,
  getEligibleReplacementCandidates,
  createReassignmentRound,
  respondToReassignmentRequest,
  cancelReassignmentRound,
} from "./callables/pharmacyDuties";
export {
  setGlobalCatalogProductLimit,
  setCategoryCatalogProductLimit,
  clearCategoryCatalogProductLimit,
  setMerchantCatalogLimitOverride,
  clearMerchantCatalogLimitOverride,
  searchCatalogLimitMerchants,
  createMerchantProduct,
  deactivateMerchantProduct,
} from "./callables/catalogLimits";
export {
  listAdminCategories,
  upsertAdminCategory,
  toggleAdminCategoryActive,
} from "./callables/adminCategories";
export {
  upsertMerchantClaimDraft,
  submitMerchantClaim,
  evaluateMerchantClaim,
  resolveMerchantClaim,
  revealMerchantClaimSensitive,
  revealMerchantClaimSensitiveData,
  getMerchantClaimDetailForReview,
  getMerchantClaimReviewDetail,
  getMerchantClaimAttachmentPreviewUrl,
  getMerchantClaimAttachmentDownloadUrl,
  getMyMerchantClaimStatus,
  listMerchantClaimsForReview,
  listMyMerchantClaims,
  searchClaimableMerchants,
} from "./callables/merchantClaims";

// ─── Onboarding Scheduled Jobs ─────────────────────────────────────────────

export { nightlyCleanupExpiredDrafts } from "./jobs/cleanupExpiredDrafts";
export {
  sendDutyConfirmationReminders,
  expirePendingReassignmentRequests,
} from "./jobs/pharmacyDutyMitigation";

// ─── Admin Callables ───────────────────────────────────────────────────────

export { runZoneBootstrapBatch } from "./jobs/bootstrap";
export { adminRebuildMerchantPublic } from "./admin/rebuildPublic";
export { backfillSearchKeywords } from "./admin/backfillKeywords";
export { adminSanitizeMerchantClaimsSensitive } from "./admin/sanitizeMerchantClaims";
