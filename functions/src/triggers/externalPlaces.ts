import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { ExternalPlaceDoc, MerchantDoc } from "../lib/types";
import { normalizeExternalCategory } from "../lib/normalizeCategory";
import { dedupeMerchantCandidate, ExistingMerchant } from "../lib/dedupe";

const db = () => getFirestore();

/**
 * onExternalPlaceCreateNormalize
 *
 * Triggered on create of external_places/{externalPlaceId}.
 * Normalizes the external place to TuM2 schema, deduplicates
 * against existing merchants, then either links to an existing
 * merchant or creates a new referential candidate.
 */
export const onExternalPlaceCreateNormalize = onDocumentCreated(
  "external_places/{externalPlaceId}",
  async (event) => {
    const externalPlaceId = event.params.externalPlaceId;
    const snap = event.data;
    if (!snap) return;

    const place = snap.data() as ExternalPlaceDoc;

    // Normalize category
    const normalizedCategory = normalizeExternalCategory(
      place.sourceType,
      place.rawCategory
    );

    // Fetch existing merchants in the same zone for dedup
    const existingSnap = await db()
      .collection("merchants")
      .where("zone", "==", place.zoneId)
      .get();

    const existing: ExistingMerchant[] = existingSnap.docs.map((d) => {
      const data = d.data() as MerchantDoc & { lat?: number; lng?: number };
      return {
        merchantId: d.id,
        name: data.name,
        address: data.address,
        lat: data.lat,
        lng: data.lng,
        zone: data.zone,
      };
    });

    const dedupeResult = dedupeMerchantCandidate(
      {
        name: place.rawName,
        address: place.rawAddress,
        lat: place.rawLat,
        lng: place.rawLng,
        zoneId: place.zoneId,
        externalId: externalPlaceId,
      },
      existing
    );

    if (dedupeResult.matched && dedupeResult.merchantId) {
      // Link to existing merchant
      await Promise.all([
        db()
          .doc(`external_places/${externalPlaceId}`)
          .set(
            {
              linkedMerchantId: dedupeResult.merchantId,
              normalizedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          ),
        db()
          .doc(`merchants/${dedupeResult.merchantId}`)
          .set(
            { externalPlaceId: externalPlaceId },
            { merge: true }
          ),
      ]);

      console.log(
        `[onExternalPlaceCreateNormalize] Linked ${externalPlaceId} -> ${dedupeResult.merchantId} (confidence=${dedupeResult.confidence})`
      );
    } else {
      // Create new referential merchant candidate
      const newMerchantRef = db().collection("merchants").doc();
      const newMerchant: Partial<MerchantDoc> = {
        merchantId: newMerchantRef.id,
        name: place.rawName,
        category: normalizedCategory,
        zone: place.zoneId,
        address: place.rawAddress,
        verificationStatus: "referential",
        visibilityStatus: "review_pending",
        sourceType: "external_seed",
        externalPlaceId: externalPlaceId,
        createdAt: FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp,
        updatedAt: FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp,
      };

      await Promise.all([
        newMerchantRef.set(newMerchant),
        db()
          .doc(`external_places/${externalPlaceId}`)
          .set(
            {
              linkedMerchantId: newMerchantRef.id,
              normalizedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          ),
      ]);

      console.log(
        `[onExternalPlaceCreateNormalize] Created new referential merchant ${newMerchantRef.id} from ${externalPlaceId}`
      );
    }
  }
);
