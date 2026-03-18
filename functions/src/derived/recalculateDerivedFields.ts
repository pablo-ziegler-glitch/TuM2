import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {
  ScheduleDoc,
  OperationalSignalDoc,
} from "../types";
import {
  isOpenNow,
  isLateNightNow,
  calculateCompletenessScore,
} from "../utils/timeUtils";

const DEFAULT_TIMEZONE = "America/Argentina/Buenos_Aires";

/**
 * Recalculates derived fields on a store when its schedules change.
 */
export const onScheduleWrite = functions.firestore
  .document("stores/{storeId}/schedules/{scheduleId}")
  .onWrite(async (change, context) => {
    const storeId = context.params.storeId;
    await recalculate(storeId);
  });

/**
 * Recalculates derived fields on a store when its operational signals change.
 */
export const onSignalWrite = functions.firestore
  .document("stores/{storeId}/operationalSignals/{signalId}")
  .onWrite(async (change, context) => {
    const storeId = context.params.storeId;
    await recalculate(storeId);
  });

async function recalculate(storeId: string): Promise<void> {
  const db = admin.firestore();

  try {
    // Load the store document
    const storeRef = db.collection("stores").doc(storeId);
    const storeSnap = await storeRef.get();

    if (!storeSnap.exists) {
      functions.logger.warn(`Store ${storeId} not found for derived fields recalculation.`);
      return;
    }

    // Load all schedules for this store
    const schedulesSnap = await storeRef.collection("schedules").get();
    const schedules: ScheduleDoc[] = schedulesSnap.docs.map(
      (doc) => doc.data() as ScheduleDoc
    );

    // Load all active operational signals
    const signalsSnap = await storeRef
      .collection("operationalSignals")
      .where("status", "==", "active")
      .get();
    const activeSignals: OperationalSignalDoc[] = signalsSnap.docs.map(
      (doc) => doc.data() as OperationalSignalDoc
    );

    // Use the first schedule's timezone or default
    const timezone = schedules[0]?.timezone ?? DEFAULT_TIMEZONE;
    const weeklySchedule = schedules[0]?.weeklySchedule ?? null;

    // Calculate derived fields
    const derived = {
      isOpenNow: isOpenNow(weeklySchedule, timezone),
      isLateNightNow: isLateNightNow(weeklySchedule, timezone),
      hasActiveSpecialSignal: activeSignals.some((s) =>
        ["special_hours", "special_service"].includes(s.signalType)
      ),
      operationalDataCompletenessScore: calculateCompletenessScore(weeklySchedule),
      operationalFreshnessHours: calculateFreshnessHours(schedules, activeSignals),
    };

    await storeRef.update({
      ...derived,
      updatedAt: admin.firestore.Timestamp.now(),
    });

    functions.logger.info(
      `Derived fields recalculated for store ${storeId}:`,
      derived
    );
  } catch (error) {
    functions.logger.error(
      `Error recalculating derived fields for store ${storeId}:`,
      error
    );
    throw error;
  }
}

/**
 * Calculates how many hours ago the last operational data was updated.
 */
function calculateFreshnessHours(
  schedules: ScheduleDoc[],
  signals: OperationalSignalDoc[]
): number {
  const now = Date.now();
  let latestMs = 0;

  for (const schedule of schedules) {
    const ms = schedule.updatedAt?.toMillis() ?? 0;
    if (ms > latestMs) latestMs = ms;
  }

  for (const signal of signals) {
    const ms = signal.updatedAt?.toMillis() ?? 0;
    if (ms > latestMs) latestMs = ms;
  }

  if (latestMs === 0) return 9999; // No data

  return Math.round((now - latestMs) / (1000 * 60 * 60));
}
