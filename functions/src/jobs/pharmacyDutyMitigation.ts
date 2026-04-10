import { getMessaging } from "firebase-admin/messaging";
import {
  FieldValue,
  Timestamp,
  WriteBatch,
  getFirestore,
} from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  DutyConfirmationStatus,
  DutyStatus,
  RequestStatus,
  deriveDutyPublicState,
  normalizeDutyStatus,
} from "../lib/pharmacyDutyMitigation";
import { addDaysToDateKey } from "../lib/pharmacyDuties";
import { todayDateString } from "../lib/schedules";

const db = () => getFirestore();
const MAX_SCAN_PER_RUN = 200;
const MAX_BATCH_WRITES = 450;

interface PharmacyDutyDoc {
  merchantId: string;
  date: string;
  status: DutyStatus | string;
  confirmationStatus?: DutyConfirmationStatus | string;
  startsAt?: FirebaseFirestore.Timestamp | string;
  confirmationReminderLastSentAt?: FirebaseFirestore.Timestamp;
  confirmationReminderCount?: number;
}

interface ReassignmentRequestDoc {
  dutyId: string;
  roundId: string;
  incidentId: string;
  status: RequestStatus;
  expiresAt: FirebaseFirestore.Timestamp;
}

interface ReassignmentRoundDoc {
  dutyId: string;
  status: "open" | "covered" | "expired" | "cancelled";
}

interface MerchantDoc {
  ownerUserId?: string;
  fcmTokens?: string[];
  notificationTokens?: string[];
}

function toDutyDate(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
}

function safeTokens(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((entry) => typeof entry === "string")
    .map((entry) => (entry as string).trim())
    .filter((entry) => entry.length > 0)
    .slice(0, 10);
}

export const sendDutyConfirmationReminders = onSchedule(
  {
    schedule: "*/15 * * * *",
    timeZone: "America/Argentina/Buenos_Aires",
  },
  async () => {
    const now = new Date();
    const today = todayDateString();
    const tomorrow = addDaysToDateKey(today, 1);
    const reminderCutoffMs = 6 * 60 * 60 * 1000;
    const reminderWindowMs = 12 * 60 * 60 * 1000;

    const dutiesSnap = await db()
      .collection("pharmacy_duties")
      .where("date", ">=", today)
      .where("date", "<=", tomorrow)
      .where("confirmationStatus", "==", "pending")
      // Límite duro para evitar barrido global en cada ciclo.
      .limit(MAX_SCAN_PER_RUN)
      .get();

    const dueDuties = dutiesSnap.docs.filter((dutyDoc) => {
      const duty = dutyDoc.data() as PharmacyDutyDoc;
      const status = normalizeDutyStatus(duty.status);
      if (status !== "scheduled" && status !== "active") return false;
      const startsAt = toDutyDate(duty.startsAt);
      if (!startsAt) return false;
      const untilStartMs = startsAt.getTime() - now.getTime();
      if (untilStartMs < 0 || untilStartMs > reminderWindowMs) return false;
      const lastReminder = duty.confirmationReminderLastSentAt;
      if (lastReminder instanceof Timestamp) {
        const elapsedMs = now.getTime() - lastReminder.toMillis();
        if (elapsedMs < reminderCutoffMs) return false;
      }
      return true;
    });

    if (dueDuties.length === 0) {
      console.log("[sendDutyConfirmationReminders] No reminders to send.");
      return;
    }

    const merchantRefs = Array.from(
      new Set(dueDuties.map((dutyDoc) => (dutyDoc.data() as PharmacyDutyDoc).merchantId))
    ).map((merchantId) => db().doc(`merchants/${merchantId}`));
    const merchantSnaps = await db().getAll(...merchantRefs);
    const tokensByMerchantId = new Map<string, string[]>();
    for (const merchantSnap of merchantSnaps) {
      if (!merchantSnap.exists) continue;
      const merchant = merchantSnap.data() as MerchantDoc;
      const tokens = [
        ...safeTokens(merchant.fcmTokens),
        ...safeTokens(merchant.notificationTokens),
      ];
      if (tokens.length > 0) {
        tokensByMerchantId.set(merchantSnap.id, Array.from(new Set(tokens)));
      }
    }

    const batches: WriteBatch[] = [];
    let currentBatch = db().batch();
    let writes = 0;
    let sentNotifications = 0;
    let updatedDocs = 0;

    for (const dutyDoc of dueDuties) {
      const duty = dutyDoc.data() as PharmacyDutyDoc;
      const tokens = tokensByMerchantId.get(duty.merchantId) ?? [];
      if (tokens.length > 0) {
        try {
          const response = await getMessaging().sendEachForMulticast({
            tokens,
            notification: {
              title: "Recordatorio de guardia",
              body: "Confirmá tu guardia para mantener la información pública al día.",
            },
            data: {
              type: "pharmacy_duty_confirmation_reminder",
              dutyId: dutyDoc.id,
            },
          });
          sentNotifications += response.successCount;
        } catch (error) {
          console.error(
            `[sendDutyConfirmationReminders] Error enviando FCM duty=${dutyDoc.id}`,
            error
          );
        }
      }

      currentBatch.update(dutyDoc.ref, {
        confirmationReminderLastSentAt: FieldValue.serverTimestamp(),
        confirmationReminderCount:
          typeof duty.confirmationReminderCount === "number"
            ? duty.confirmationReminderCount + 1
            : 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
      writes += 1;
      updatedDocs += 1;

      if (writes >= MAX_BATCH_WRITES) {
        batches.push(currentBatch);
        currentBatch = db().batch();
        writes = 0;
      }
    }

    if (writes > 0) {
      batches.push(currentBatch);
    }
    await Promise.all(batches.map((batch) => batch.commit()));

    console.log(
      JSON.stringify({
        job: "sendDutyConfirmationReminders",
        scanned: dutiesSnap.size,
        dueCount: dueDuties.length,
        updatedDocs,
        sentNotifications,
      })
    );
  }
);

export const expirePendingReassignmentRequests = onSchedule(
  {
    schedule: "*/10 * * * *",
    timeZone: "America/Argentina/Buenos_Aires",
  },
  async () => {
    const nowTs = Timestamp.now();
    const expiredSnap = await db()
      .collection("pharmacy_duty_reassignment_requests")
      .where("status", "==", "pending")
      .where("expiresAt", "<=", nowTs)
      .orderBy("expiresAt", "asc")
      // Procesamiento incremental para costo y latencia predecibles.
      .limit(MAX_SCAN_PER_RUN)
      .get();

    if (expiredSnap.empty) {
      console.log("[expirePendingReassignmentRequests] No pending requests to expire.");
      return;
    }

    const roundIds = new Set<string>();
    const batch = db().batch();
    for (const requestDoc of expiredSnap.docs) {
      const request = requestDoc.data() as ReassignmentRequestDoc;
      roundIds.add(request.roundId);
      batch.update(requestDoc.ref, {
        status: "expired",
        respondedAt: FieldValue.serverTimestamp(),
        responseReason: "expired",
        lastEventAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    let closedRounds = 0;
    for (const roundId of roundIds) {
      await db().runTransaction(async (tx) => {
        const roundRef = db().doc(`pharmacy_duty_reassignment_rounds/${roundId}`);
        const roundSnap = await tx.get(roundRef);
        if (!roundSnap.exists) return;
        const round = roundSnap.data() as ReassignmentRoundDoc;
        if (round.status !== "open") return;

        const pendingSnap = await tx.get(
          db()
            .collection("pharmacy_duty_reassignment_requests")
            .where("roundId", "==", roundId)
            .where("status", "==", "pending")
            .limit(1)
        );
        if (!pendingSnap.empty) return;

        const dutyRef = db().doc(`pharmacy_duties/${round.dutyId}`);
        const dutySnap = await tx.get(dutyRef);
        if (!dutySnap.exists) return;

        tx.update(roundRef, {
          status: "expired",
          closedAt: FieldValue.serverTimestamp(),
          lastEventAt: FieldValue.serverTimestamp(),
        });

        const derived = deriveDutyPublicState({
          status: "incident_reported",
          confirmationStatus: "incident_reported",
          incidentOpen: true,
        });
        tx.update(dutyRef, {
          status: "incident_reported",
          confirmationStatus: "incident_reported",
          replacementRoundOpen: false,
          confidenceLevel: derived.confidenceLevel,
          publicStatusLabel: derived.publicStatusLabel,
          lastStatusChangedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        closedRounds += 1;
      });
    }

    console.log(
      JSON.stringify({
        job: "expirePendingReassignmentRequests",
        expiredRequests: expiredSnap.size,
        touchedRounds: roundIds.size,
        closedRounds,
      })
    );
  }
);
