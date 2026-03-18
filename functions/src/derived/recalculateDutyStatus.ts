import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { getCurrentDateInTimezone } from "../utils/timeUtils";

const DEFAULT_TIMEZONE = "America/Argentina/Buenos_Aires";
const BATCH_SIZE = 400;

/**
 * Scheduled Cloud Function that runs daily at 00:01 AR time.
 * Updates isOnDutyToday on all pharmacy stores based on duty schedules.
 */
export const recalculateDutyStatus = functions.pubsub
  .schedule("1 0 * * *")
  .timeZone(DEFAULT_TIMEZONE)
  .onRun(async () => {
    const db = admin.firestore();
    const today = getCurrentDateInTimezone(DEFAULT_TIMEZONE);

    functions.logger.info(`Recalculating duty status for date: ${today}`);

    try {
      // Find all duty schedules for today that are active
      const dutySnap = await db
        .collection("dutySchedules")
        .where("date", "==", today)
        .where("status", "!=", "cancelled")
        .get();

      const dutyStoreIds = new Set<string>(
        dutySnap.docs.map((doc) => doc.data().storeId as string)
      );

      functions.logger.info(
        `Found ${dutyStoreIds.size} stores on duty today.`
      );

      // Get all stores that currently have isOnDutyToday = true
      const prevDutySnap = await db
        .collection("stores")
        .where("isOnDutyToday", "==", true)
        .get();

      // Build batches for updates
      const batches: admin.firestore.WriteBatch[] = [];
      let currentBatch = db.batch();
      let opCount = 0;

      const flushBatch = () => {
        batches.push(currentBatch);
        currentBatch = db.batch();
        opCount = 0;
      };

      const batchUpdate = (ref: admin.firestore.DocumentReference, data: object) => {
        currentBatch.update(ref, data);
        opCount++;
        if (opCount >= BATCH_SIZE) flushBatch();
      };

      // Set isOnDutyToday = false for stores no longer on duty
      for (const doc of prevDutySnap.docs) {
        if (!dutyStoreIds.has(doc.id)) {
          batchUpdate(doc.ref, { isOnDutyToday: false, updatedAt: admin.firestore.Timestamp.now() });
        }
      }

      // Set isOnDutyToday = true for stores on duty today
      for (const storeId of dutyStoreIds) {
        const storeRef = db.collection("stores").doc(storeId);
        batchUpdate(storeRef, { isOnDutyToday: true, updatedAt: admin.firestore.Timestamp.now() });
      }

      // Commit remaining batch
      if (opCount > 0) batches.push(currentBatch);

      await Promise.all(batches.map((b) => b.commit()));

      functions.logger.info(
        `Duty status updated: ${dutyStoreIds.size} stores on duty, ${prevDutySnap.size} previously.`
      );
    } catch (error) {
      functions.logger.error("Error recalculating duty status:", error);
      throw error;
    }
  });
