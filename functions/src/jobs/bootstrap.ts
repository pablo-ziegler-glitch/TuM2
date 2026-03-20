import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { ImportBatchDoc } from "../lib/types";

const db = () => getFirestore();

const MAX_RESULTS_LIMIT = 50;
const ZONES_COLLECTION = "zones";

interface BootstrapRequest {
  zoneId: string;
  sourceType: string;
  maxResults?: number;
  categories?: string[];
}

/**
 * runZoneBootstrapBatch
 *
 * Admin-only HTTPS callable that seeds external_places for a given zone.
 * Actual external API integration (e.g. Google Places) is a stub here —
 * the function establishes the pipeline, guardrails, and traceability.
 *
 * Guardrails:
 * - Caller must have custom claim admin=true
 * - maxResults <= 50
 * - Zone must not be paused or outside pilot
 * - Records import_batches document with full audit trail
 */
export const runZoneBootstrapBatch = onCall(
  { enforceAppCheck: false },
  async (request) => {
    // Auth check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }
    if (!request.auth.token.admin) {
      throw new HttpsError("permission-denied", "Admin access required.");
    }

    const data = request.data as BootstrapRequest;
    const { zoneId, sourceType, categories } = data;
    const maxResults = Math.min(data.maxResults ?? MAX_RESULTS_LIMIT, MAX_RESULTS_LIMIT);

    if (!zoneId || !sourceType) {
      throw new HttpsError("invalid-argument", "zoneId and sourceType are required.");
    }

    // Check zone is valid and not paused
    const zoneSnap = await db().doc(`${ZONES_COLLECTION}/${zoneId}`).get();
    if (!zoneSnap.exists) {
      throw new HttpsError("not-found", `Zone ${zoneId} not found.`);
    }
    const zoneData = zoneSnap.data();
    if (zoneData?.bootstrapPaused === true) {
      throw new HttpsError(
        "failed-precondition",
        `Bootstrap is paused for zone ${zoneId}.`
      );
    }
    if (zoneData?.inPilot === false) {
      throw new HttpsError(
        "failed-precondition",
        `Zone ${zoneId} is not in the pilot program.`
      );
    }

    // Create import batch record
    const batchRef = db().collection("import_batches").doc();
    const batchDoc: Omit<ImportBatchDoc, "completedAt"> = {
      batchId: batchRef.id,
      zoneId,
      sourceType,
      startedAt: FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp,
      status: "running",
      inputCount: 0,
      createdCount: 0,
      linkedCount: 0,
      skippedCount: 0,
    };

    await batchRef.set(batchDoc);

    // --- External data fetch stub ---
    // In production, replace this with an actual API call, e.g.:
    //   const places = await fetchGooglePlaces({ zoneId, categories, maxResults });
    // For now, we return an empty result set to establish the pipeline.
    const places: Array<{
      externalId: string;
      name: string;
      category: string;
      address: string;
      lat?: number;
      lng?: number;
    }> = [];

    // Persist external places (triggers onExternalPlaceCreateNormalize for each)
    let createdCount = 0;
    const batchWriter = db().batch();

    for (const place of places.slice(0, maxResults)) {
      const placeRef = db().collection("external_places").doc(
        `${sourceType}_${place.externalId}`
      );
      batchWriter.set(placeRef, {
        externalId: place.externalId,
        sourceType,
        rawName: place.name,
        rawCategory: place.category,
        rawAddress: place.address,
        rawLat: place.lat,
        rawLng: place.lng,
        zoneId,
        importBatchId: batchRef.id,
        createdAt: FieldValue.serverTimestamp(),
      });
      createdCount++;
    }

    await batchWriter.commit();

    // Finalize batch record
    await batchRef.set(
      {
        status: "completed",
        completedAt: FieldValue.serverTimestamp(),
        inputCount: places.length,
        createdCount,
        skippedCount: places.length - createdCount,
        estimatedCost: estimateCost(sourceType, places.length),
      },
      { merge: true }
    );

    console.log(
      `[runZoneBootstrapBatch] Batch ${batchRef.id} complete. zone=${zoneId} source=${sourceType} created=${createdCount}`
    );

    return {
      batchId: batchRef.id,
      zoneId,
      sourceType,
      inputCount: places.length,
      createdCount,
      categories: categories ?? [],
    };
  }
);

/**
 * Returns a rough cost estimate (USD) for the given source + count.
 * Based on Google Places pricing: ~$0.017 per place detail.
 */
function estimateCost(sourceType: string, count: number): number {
  if (sourceType === "google_places") {
    return Math.round(count * 0.017 * 1000) / 1000;
  }
  return 0;
}
