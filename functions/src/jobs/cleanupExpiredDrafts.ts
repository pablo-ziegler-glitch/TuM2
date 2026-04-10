import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { shouldRunAutomaticFirestoreJob } from "../lib/automaticJobsGuard";

const db = () => getFirestore();
const BATCH_SIZE = 500;
const TTL_HOURS = 72;
const MAX_EXPIRED_DRAFTS_PER_RUN = 2000;

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
    if (!shouldRunAutomaticFirestoreJob("nightlyCleanupExpiredDrafts")) {
      return;
    }
    console.log("[nightlyCleanupExpiredDrafts] Starting...");

    const cutoff = new Date(Date.now() - TTL_HOURS * 60 * 60 * 1000);
    const cutoffTimestamp = Timestamp.fromDate(cutoff);

    // Query acotada para evitar barridos amplios de users.
    const usersSnap = await db()
      .collection("users")
      .where("onboardingOwnerProgress.currentStep", "in", ACTIVE_STEPS)
      .where("onboardingOwnerProgress.updatedAt", "<", cutoffTimestamp)
      .limit(MAX_EXPIRED_DRAFTS_PER_RUN)
      .get();

    if (usersSnap.empty) {
      console.log("[nightlyCleanupExpiredDrafts] No expired drafts found.");
      return;
    }

    const expiredDocs = usersSnap.docs;

    if (expiredDocs.length === 0) {
      console.log("[nightlyCleanupExpiredDrafts] No active expired drafts found.");
      return;
    }

    if (usersSnap.size >= MAX_EXPIRED_DRAFTS_PER_RUN) {
      console.warn(
        `[nightlyCleanupExpiredDrafts] Hit scan cap (${MAX_EXPIRED_DRAFTS_PER_RUN}). Remaining drafts will be processed in next runs.`
      );
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
    console.log(
      JSON.stringify({
        job: "nightlyCleanupExpiredDrafts",
        scanned: usersSnap.size,
        updated: purged,
        scanCap: MAX_EXPIRED_DRAFTS_PER_RUN,
      })
    );
  }
);
