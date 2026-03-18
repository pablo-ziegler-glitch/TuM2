import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { StoreDoc, BadgeDefinitionDoc } from "../types";
import { getCurrentDateInTimezone } from "../utils/timeUtils";

const DEFAULT_TIMEZONE = "America/Argentina/Buenos_Aires";
const BADGE_KEYS = {
  VISIBLE_EN_TUM2: "visible_en_tum2",
  ACTIVO_EN_TUM2: "activo_en_tum2",
  HORARIO_ACTUALIZADO: "horario_actualizado",
  TURNO_CARGADO: "turno_cargado",
} as const;

/**
 * Triggered when a store document is written.
 * Evaluates badge conditions and updates activeBadgeKeys on the store.
 */
export const onStoreWriteUpdateBadges = functions.firestore
  .document("stores/{storeId}")
  .onWrite(async (change, context) => {
    const storeId = context.params.storeId;

    // Skip if store was deleted
    if (!change.after.exists) return;

    const store = change.after.data() as StoreDoc;

    // Skip if the update was triggered by this function (avoid infinite loop)
    // We detect this by checking if only activeBadgeKeys changed
    const before = change.before.exists ? (change.before.data() as StoreDoc) : null;
    if (before && JSON.stringify(before.activeBadgeKeys) !== JSON.stringify(store.activeBadgeKeys)) {
      // This write was just a badge update — stop to prevent loop
      return;
    }

    const db = admin.firestore();
    const today = getCurrentDateInTimezone(DEFAULT_TIMEZONE);

    try {
      const earnedBadges: string[] = [];

      // Badge: visible_en_tum2 — store is active
      if (store.visibilityStatus === "active") {
        earnedBadges.push(BADGE_KEYS.VISIBLE_EN_TUM2);
      }

      // Badge: activo_en_tum2 — store updated within last 30 days
      if (store.updatedAt) {
        const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
        if (store.updatedAt.toMillis() > thirtyDaysAgo) {
          earnedBadges.push(BADGE_KEYS.ACTIVO_EN_TUM2);
        }
      }

      // Badge: horario_actualizado — schedule completeness > 70%
      if (store.operationalDataCompletenessScore >= 70) {
        earnedBadges.push(BADGE_KEYS.HORARIO_ACTUALIZADO);
      }

      // Badge: turno_cargado — has a future duty schedule
      const futuredutySnap = await db
        .collection("dutySchedules")
        .where("storeId", "==", storeId)
        .where("date", ">=", today)
        .where("status", "!=", "cancelled")
        .limit(1)
        .get();

      if (!futuredutySnap.empty) {
        earnedBadges.push(BADGE_KEYS.TURNO_CARGADO);
      }

      // Only update if badges changed
      const currentBadges = store.activeBadgeKeys ?? [];
      const badgesChanged =
        JSON.stringify([...earnedBadges].sort()) !==
        JSON.stringify([...currentBadges].sort());

      if (badgesChanged) {
        await change.after.ref.update({
          activeBadgeKeys: earnedBadges,
          updatedAt: admin.firestore.Timestamp.now(),
        });

        functions.logger.info(
          `Badges updated for store ${storeId}:`,
          earnedBadges
        );
      }
    } catch (error) {
      functions.logger.error(
        `Error updating badges for store ${storeId}:`,
        error
      );
      throw error;
    }
  });
