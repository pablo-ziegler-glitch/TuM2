import { FieldValue } from "firebase-admin/firestore";
import {
  MerchantDoc,
  MerchantPublicDoc,
  OperationalSignals,
  VerificationStatus,
} from "./types";

const VERIFICATION_BOOST: Record<VerificationStatus, number> = {
  verified: 40,
  claimed: 25,
  referential: 5,
  unverified: 0,
};

/**
 * Computes the sortBoost score for a merchant.
 * Higher = appears earlier in zone listings.
 */
export function computeSortBoost(merchant: MerchantDoc): number {
  let boost = 0;

  // Verification tier
  boost += VERIFICATION_BOOST[merchant.verificationStatus] ?? 0;

  // Completeness
  boost += (merchant.completenessScore ?? 0) * 0.3;

  // Recent activity bonus (within last 30 days)
  if (merchant.lastActivityAt) {
    const msAgo =
      Date.now() - merchant.lastActivityAt.toMillis();
    const daysAgo = msAgo / (1000 * 60 * 60 * 24);
    if (daysAgo < 30) {
      boost += Math.max(0, 10 - daysAgo / 3);
    }
  }

  return Math.round(boost * 10) / 10;
}

/**
 * Builds the full merchant_public projection from source docs.
 */
export function computeMerchantPublicProjection(
  merchant: MerchantDoc,
  signals?: OperationalSignals
): Omit<MerchantPublicDoc, "syncedAt"> {
  const sortBoost = computeSortBoost(merchant);

  const projection: Omit<MerchantPublicDoc, "syncedAt"> = {
    merchantId: merchant.merchantId,
    name: merchant.name,
    category: merchant.category,
    zone: merchant.zone,
    verificationStatus: merchant.verificationStatus,
    visibilityStatus: merchant.visibilityStatus,
    sortBoost,
  };

  if (merchant.address) projection.address = merchant.address;
  if (merchant.isPharmacy) projection.isPharmacy = merchant.isPharmacy;

  if (signals) {
    projection.isOpenNow = signals.isOpenNow ?? false;
    projection.todayScheduleLabel = signals.todayScheduleLabel ?? "";
    projection.hasPharmacyDutyToday = signals.hasPharmacyDutyToday ?? false;
    projection.operationalSignals = signals;
  }

  return projection;
}

// Re-export FieldValue for use in triggers
export { FieldValue };
