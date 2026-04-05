import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";

const db = () => getFirestore();
const BATCH_SIZE = 500;
const TTL_HOURS = 72;

const ACTIVE_STEPS = ["step_1", "step_2", "step_3", "confirmation"];

/**
 * nightlyCleanupExpiredDrafts
 *
 * Runs every hour. Marks onboarding drafts as 'abandoned' when their
 * updatedAt timestamp is older than 72 hours and they are still in an
 * active (non-terminal) step.
 *
 * Does NOT delete documents — sets currentStep to 'abandoned' so the
 * client can show the EX-04 expired draft screen on next open.
 */
export const nightlyCleanupExpiredDrafts = onSchedule(
  {
    schedule: "0 * * * *",
    timeZone: "America/Argentina/Buenos_Aires",
  },
  async () => {
    console.log("[nightlyCleanupExpiredDrafts] Starting...");

    const cutoff = new Date(Date.now() - TTL_HOURS * 60 * 60 * 1000);
    const cutoffTimestamp = Timestamp.fromDate(cutoff);

    // Query users with active drafts older than TTL
    const usersSnap = await db()
      .collection("users")
      .where("onboardingOwnerProgress.updatedAt", "<", cutoffTimestamp)
      .get();

    if (usersSnap.empty) {
      console.log("[nightlyCleanupExpiredDrafts] No expired drafts found.");
      return;
    }

    // Filter client-side for active steps (Firestore doesn't support
    // array-contains on non-array fields combined with range queries)
    const expiredDocs = usersSnap.docs.filter((doc) => {
      const step = doc.data()?.onboardingOwnerProgress?.currentStep;
      return step && ACTIVE_STEPS.includes(step);
    });

    if (expiredDocs.length === 0) {
      console.log("[nightlyCleanupExpiredDrafts] No active expired drafts found.");
      return;
    }

    console.log(`[nightlyCleanupExpiredDrafts] Marking ${expiredDocs.length} drafts as abandoned`);

    let purged = 0;
    let batch = db().batch();
    let batchOps = 0;

    for (const doc of expiredDocs) {
      batch.update(doc.ref, {
        "onboardingOwnerProgress.currentStep": "abandoned",
        "onboardingOwnerProgress.abandonedAt": FieldValue.serverTimestamp(),
      });
      batchOps++;
      purged++;

      if (batchOps >= BATCH_SIZE) {
        await batch.commit();
        batch = db().batch();
        batchOps = 0;
      }
    }

    if (batchOps > 0) {
      await batch.commit();
    }

    console.log(`[nightlyCleanupExpiredDrafts] Done. Purged ${purged} expired drafts.`);
  }
);
