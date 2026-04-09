import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { computeUsefulCoverageScore } from "../lib/scoring";
import { MerchantPublicDoc, ZoneCoverageMetrics } from "../lib/types";

const db = () => getFirestore();

function zoneKey(merchant: MerchantPublicDoc | undefined): string {
  if (!merchant) return "";
  return (merchant.zoneId ?? merchant.zone ?? "").trim();
}

function metricContribution(
  merchant: MerchantPublicDoc | undefined
): Omit<ZoneCoverageMetrics, "usefulCoverageScore" | "updatedAt"> {
  if (!merchant) {
    return {
      merchantCount: 0,
      visibleMerchantCount: 0,
      pharmacyCount: 0,
      verifiedCount: 0,
      referentialCount: 0,
      communitySubmittedCount: 0,
    };
  }

  const visible = merchant.visibilityStatus === "visible";
  const verifiedOrClaimed =
    merchant.verificationStatus === "verified" ||
    merchant.verificationStatus === "claimed";

  return {
    merchantCount: 1,
    visibleMerchantCount: visible ? 1 : 0,
    pharmacyCount: merchant.isPharmacy ? 1 : 0,
    verifiedCount: verifiedOrClaimed ? 1 : 0,
    referentialCount: merchant.verificationStatus === "referential" ? 1 : 0,
    communitySubmittedCount:
      visible && merchant.verificationStatus === "unverified" ? 1 : 0,
  };
}

function applyDelta(
  base: Omit<ZoneCoverageMetrics, "usefulCoverageScore" | "updatedAt">,
  delta: Omit<ZoneCoverageMetrics, "usefulCoverageScore" | "updatedAt">
): Omit<ZoneCoverageMetrics, "usefulCoverageScore" | "updatedAt"> {
  return {
    merchantCount: Math.max(0, base.merchantCount + delta.merchantCount),
    visibleMerchantCount: Math.max(
      0,
      base.visibleMerchantCount + delta.visibleMerchantCount
    ),
    pharmacyCount: Math.max(0, base.pharmacyCount + delta.pharmacyCount),
    verifiedCount: Math.max(0, base.verifiedCount + delta.verifiedCount),
    referentialCount: Math.max(
      0,
      base.referentialCount + delta.referentialCount
    ),
    communitySubmittedCount: Math.max(
      0,
      base.communitySubmittedCount + delta.communitySubmittedCount
    ),
  };
}

function negateDelta(
  value: Omit<ZoneCoverageMetrics, "usefulCoverageScore" | "updatedAt">
): Omit<ZoneCoverageMetrics, "usefulCoverageScore" | "updatedAt"> {
  return {
    merchantCount: -value.merchantCount,
    visibleMerchantCount: -value.visibleMerchantCount,
    pharmacyCount: -value.pharmacyCount,
    verifiedCount: -value.verifiedCount,
    referentialCount: -value.referentialCount,
    communitySubmittedCount: -value.communitySubmittedCount,
  };
}

function mergeContributions(
  left: Omit<ZoneCoverageMetrics, "usefulCoverageScore" | "updatedAt">,
  right: Omit<ZoneCoverageMetrics, "usefulCoverageScore" | "updatedAt">
): Omit<ZoneCoverageMetrics, "usefulCoverageScore" | "updatedAt"> {
  return {
    merchantCount: left.merchantCount + right.merchantCount,
    visibleMerchantCount: left.visibleMerchantCount + right.visibleMerchantCount,
    pharmacyCount: left.pharmacyCount + right.pharmacyCount,
    verifiedCount: left.verifiedCount + right.verifiedCount,
    referentialCount: left.referentialCount + right.referentialCount,
    communitySubmittedCount:
      left.communitySubmittedCount + right.communitySubmittedCount,
  };
}

function parseCoverageBase(
  data: FirebaseFirestore.DocumentData | undefined
): Omit<ZoneCoverageMetrics, "usefulCoverageScore" | "updatedAt"> {
  const raw = (data?.coverageMetrics ?? {}) as Record<string, unknown>;
  return {
    merchantCount: Number(raw.merchantCount ?? 0),
    visibleMerchantCount: Number(raw.visibleMerchantCount ?? 0),
    pharmacyCount: Number(raw.pharmacyCount ?? 0),
    verifiedCount: Number(raw.verifiedCount ?? 0),
    referentialCount: Number(raw.referentialCount ?? 0),
    communitySubmittedCount: Number(raw.communitySubmittedCount ?? 0),
  };
}

/**
 * Recomputes and writes coverageMetrics for a given zone.
 * Scheduled fallback (full recompute).
 */
async function refreshZoneCoverage(zoneId: string): Promise<void> {
  const byZoneIdSnap = await db()
    .collection("merchant_public")
    .where("zoneId", "==", zoneId)
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

  for (const doc of byZoneIdSnap.docs) {
    const merchant = doc.data() as MerchantPublicDoc;
    const contribution = metricContribution(merchant);
    metrics.merchantCount += contribution.merchantCount;
    metrics.visibleMerchantCount += contribution.visibleMerchantCount;
    metrics.pharmacyCount += contribution.pharmacyCount;
    metrics.verifiedCount += contribution.verifiedCount;
    metrics.referentialCount += contribution.referentialCount;
    metrics.communitySubmittedCount += contribution.communitySubmittedCount;
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
 * Incremental update on merchant_public write.
 * Avoids full scan of zone merchants on each event.
 */
export const updateZoneCoverageMetrics = onDocumentWritten(
  "merchant_public/{merchantId}",
  async (event) => {
    const before = event.data?.before.exists
      ? (event.data.before.data() as MerchantPublicDoc)
      : undefined;
    const after = event.data?.after.exists
      ? (event.data.after.data() as MerchantPublicDoc)
      : undefined;

    const beforeZone = zoneKey(before);
    const afterZone = zoneKey(after);
    const affectedZones = new Set<string>();
    if (beforeZone) affectedZones.add(beforeZone);
    if (afterZone) affectedZones.add(afterZone);
    if (affectedZones.size === 0) return;

    await Promise.all(
      [...affectedZones].map(async (zoneId) => {
        const zoneRef = db().doc(`zones/${zoneId}`);
        await db().runTransaction(async (tx) => {
          const zoneSnap = await tx.get(zoneRef);
          const base = parseCoverageBase(zoneSnap.data());

          const beforeContribution = beforeZone === zoneId
            ? metricContribution(before)
            : metricContribution(undefined);
          const afterContribution = afterZone === zoneId
            ? metricContribution(after)
            : metricContribution(undefined);
          const delta = mergeContributions(
            negateDelta(beforeContribution),
            afterContribution
          );
          const next = applyDelta(base, delta);
          const usefulCoverageScore = computeUsefulCoverageScore(next);

          tx.set(
            zoneRef,
            {
              coverageMetrics: {
                ...next,
                usefulCoverageScore,
                updatedAt: FieldValue.serverTimestamp(),
              },
            },
            { merge: true }
          );
        });
      })
    );
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
