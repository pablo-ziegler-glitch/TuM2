import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { computeUsefulCoverageScore } from "../lib/scoring";
import { MerchantPublicDoc, ZoneCoverageMetrics } from "../lib/types";

const db = () => getFirestore();

/**
 * Recomputes and writes coverageMetrics for a given zone.
 */
async function refreshZoneCoverage(zoneId: string): Promise<void> {
  const merchantsSnap = await db()
    .collection("merchant_public")
    .where("zone", "==", zoneId)
    .get();

  const metrics: ZoneCoverageMetrics = {
    merchantCount: 0,
    visibleMerchantCount: 0,
    pharmacyCount: 0,
    verifiedCount: 0,
    referentialCount: 0,
    communitySubmittedCount: 0,
    usefulCoverageScore: 0,
  };

  for (const doc of merchantsSnap.docs) {
    const merchant = doc.data() as MerchantPublicDoc;
    metrics.merchantCount++;

    if (merchant.visibilityStatus === "visible") {
      metrics.visibleMerchantCount++;
    }

    if (merchant.isPharmacy) {
      metrics.pharmacyCount++;
    }

    if (
      merchant.verificationStatus === "verified" ||
      merchant.verificationStatus === "claimed"
    ) {
      metrics.verifiedCount++;
    }

    if (merchant.verificationStatus === "referential") {
      metrics.referentialCount++;
    }

    // Community submitted: visible + unverified (owner_created but unclaimed)
    if (
      merchant.verificationStatus === "unverified" &&
      merchant.visibilityStatus === "visible"
    ) {
      metrics.communitySubmittedCount++;
    }
  }

  metrics.usefulCoverageScore = computeUsefulCoverageScore(metrics);

  await db()
    .doc(`zones/${zoneId}`)
    .set(
      {
        coverageMetrics: {
          ...metrics,
          updatedAt: FieldValue.serverTimestamp(),
        },
      },
      { merge: true }
    );

  console.log(
    `[zoneCoverage] Zone ${zoneId}: visible=${metrics.visibleMerchantCount} verified=${metrics.verifiedCount} score=${metrics.usefulCoverageScore}`
  );
}

/**
 * updateZoneCoverageMetrics (trigger)
 *
 * Triggered on any write to merchant_public/{merchantId}.
 * Updates the zone's coverage metrics when a merchant changes.
 */
export const updateZoneCoverageMetrics = onDocumentWritten(
  "merchant_public/{merchantId}",
  async (event) => {
    const afterSnap = event.data?.after;
    const beforeSnap = event.data?.before;

    // Determine affected zone(s)
    const zones = new Set<string>();

    if (afterSnap?.exists) {
      const data = afterSnap.data() as MerchantPublicDoc;
      if (data.zone) zones.add(data.zone);
    }
    if (beforeSnap?.exists) {
      const data = beforeSnap.data() as MerchantPublicDoc;
      if (data.zone) zones.add(data.zone);
    }

    await Promise.all([...zones].map(refreshZoneCoverage));
  }
);

/**
 * scheduledRefreshZoneCoverage
 *
 * Scheduled fallback: runs daily at 01:00 Argentina time (04:00 UTC).
 * Refreshes coverage metrics for all zones in case triggers were missed.
 */
export const scheduledRefreshZoneCoverage = onSchedule(
  {
    schedule: "0 4 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
  },
  async () => {
    console.log("[scheduledRefreshZoneCoverage] Starting...");

    const zonesSnap = await db().collection("zones").get();
    if (zonesSnap.empty) {
      console.log("[scheduledRefreshZoneCoverage] No zones found.");
      return;
    }

    const zoneIds = zonesSnap.docs.map((d) => d.id);
    await Promise.all(zoneIds.map(refreshZoneCoverage));

    console.log(`[scheduledRefreshZoneCoverage] Done. Refreshed ${zoneIds.length} zones.`);
  }
);
