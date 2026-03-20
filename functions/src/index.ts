import { initializeApp } from "firebase-admin/app";

// Initialize Firebase Admin SDK once
initializeApp();

// ─── Firestore Triggers ────────────────────────────────────────────────────

export { onMerchantWriteSyncPublic } from "./triggers/merchants";
export { onScheduleWriteRecalculateOpenNow } from "./triggers/schedules";
export { onSignalsWriteSyncPublic } from "./triggers/signals";
export { onPharmacyDutyWriteSyncMerchant } from "./triggers/duties";
export { onClaimApprovedPromoteMerchant } from "./triggers/claims";
export { onReportThresholdSuppressMerchant } from "./triggers/reports";
export { onExternalPlaceCreateNormalize } from "./triggers/externalPlaces";

// ─── Scheduled Jobs ────────────────────────────────────────────────────────

export { nightlyRefreshOpenStatuses } from "./jobs/refreshOpenStatuses";
export { nightlyRefreshPharmacyDutyFlags } from "./jobs/refreshDuties";

// ─── Zone Coverage ─────────────────────────────────────────────────────────

export { updateZoneCoverageMetrics, scheduledRefreshZoneCoverage } from "./coverage/zoneCoverage";

// ─── Admin Callables ───────────────────────────────────────────────────────

export { runZoneBootstrapBatch } from "./jobs/bootstrap";
export { adminRebuildMerchantPublic } from "./admin/rebuildPublic";
