import { createHash, randomUUID } from "node:crypto";
import { FieldValue, Timestamp, Transaction, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { formatDateInArgentina, isPharmacyCategory, isValidDateKey } from "../lib/pharmacyDuties";
import { withUsageGuard } from "../middleware/usageGuard";
import { trackUsage } from "../utils/usageTracker";

const db = () => getFirestore();
const RATE_LIMIT_COLLECTION = "outdated_info_report_rate_limits";
const DEDUPE_COLLECTION = "outdated_info_report_dedupes";
const REPORTS_COLLECTION = "reports";

const ALLOWED_REASON_CODES = new Set([
  "wrong_schedule",
  "closed_on_duty",
  "not_found",
  "data_mismatch",
]);

const ALLOWED_SOURCES = new Set([
  "pharmacy_duty_list",
  "pharmacy_duty_detail",
]);

const RATE_LIMIT_WINDOW_MS = readIntEnv({
  key: "OUTDATED_INFO_REPORT_RATE_LIMIT_WINDOW_MS",
  fallback: 60 * 60 * 1000,
  min: 10_000,
  max: 24 * 60 * 60 * 1000,
});

const RATE_LIMIT_MAX = readIntEnv({
  key: "OUTDATED_INFO_REPORT_RATE_LIMIT_MAX",
  fallback: 6,
  min: 1,
  max: 50,
});

const DEDUPE_WINDOW_MS = readIntEnv({
  key: "OUTDATED_INFO_REPORT_DEDUPE_WINDOW_MS",
  fallback: 24 * 60 * 60 * 1000,
  min: 60_000,
  max: 14 * 24 * 60 * 60 * 1000,
});

interface SubmitOutdatedInfoReportRequest {
  merchantId?: string;
  zoneId?: string;
  reasonCode?: string;
  source?: string;
  dateKey?: string;
}

interface SubmitOutdatedInfoReportResponse {
  reportId: string | null;
  created: boolean;
  deduped: boolean;
}

function readIntEnv(params: {
  key: string;
  fallback: number;
  min: number;
  max: number;
}): number {
  const raw = process.env[params.key];
  if (raw == null || raw.trim().length === 0) return params.fallback;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) return params.fallback;
  return Math.min(params.max, Math.max(params.min, parsed));
}

function normalizeString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function resolveIpHash(rawIp: string | undefined): string {
  const ip = (rawIp ?? "unknown").trim();
  const salt = (process.env.IP_HASH_SALT ?? "missing-salt").trim();
  return createHash("sha256").update(`${salt}:${ip}`).digest("hex");
}

async function assertOutdatedInfoRateLimit(params: {
  tx: Transaction;
  ipHash: string;
  nowMillis: number;
}): Promise<void> {
  const windowStartMillis =
    Math.floor(params.nowMillis / RATE_LIMIT_WINDOW_MS) * RATE_LIMIT_WINDOW_MS;
  const retryAfterMillis =
    windowStartMillis + RATE_LIMIT_WINDOW_MS - params.nowMillis;
  const limiterDocId = [
    "submit_outdated_info_report",
    params.ipHash,
    String(windowStartMillis),
  ].join("__");
  const limiterRef = db().collection(RATE_LIMIT_COLLECTION).doc(limiterDocId);
  const limiterSnap = await params.tx.get(limiterRef);
  const previousCountRaw = limiterSnap.data()?.["count"];
  const previousCount =
    typeof previousCountRaw === "number" && Number.isFinite(previousCountRaw)
      ? Math.max(0, Math.trunc(previousCountRaw))
      : 0;
  const nextCount = previousCount + 1;

  if (nextCount > RATE_LIMIT_MAX) {
    throw new HttpsError(
      "resource-exhausted",
      "Demasiados reportes en poco tiempo. Intentá nuevamente en unos minutos.",
      {
        code: "rate_limited",
        retryAfterMillis: Math.max(1, retryAfterMillis),
      }
    );
  }

  params.tx.set(
    limiterRef,
    {
      count: nextCount,
      ipHash: params.ipHash,
      windowStartMillis,
      windowDurationMillis: RATE_LIMIT_WINDOW_MS,
      expiresAt: Timestamp.fromMillis(
        windowStartMillis + RATE_LIMIT_WINDOW_MS * 2
      ),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

export const submitOutdatedInfoReport = onCall(
  { enforceAppCheck: true, maxInstances: 20 },
  withUsageGuard(
    async (request): Promise<SubmitOutdatedInfoReportResponse> => {
      const payload = request.data as SubmitOutdatedInfoReportRequest;
      const merchantId = normalizeString(payload.merchantId);
      const zoneId = normalizeString(payload.zoneId);
      const reasonCode = normalizeString(payload.reasonCode);
      const source = normalizeString(payload.source);
      const dateKeyRaw = normalizeString(payload.dateKey);
      const dateKey =
        dateKeyRaw.length > 0 ? dateKeyRaw : formatDateInArgentina(new Date());

      if (!merchantId || !zoneId || !reasonCode || !source) {
        throw new HttpsError(
          "invalid-argument",
          "merchantId, zoneId, reasonCode y source son requeridos."
        );
      }
      if (!ALLOWED_REASON_CODES.has(reasonCode)) {
        throw new HttpsError("invalid-argument", "reasonCode no permitido.");
      }
      if (!ALLOWED_SOURCES.has(source)) {
        throw new HttpsError("invalid-argument", "source no permitido.");
      }
      if (!isValidDateKey(dateKey)) {
        throw new HttpsError("invalid-argument", "dateKey inválido.");
      }

      const merchantSnap = await db().doc(`merchant_public/${merchantId}`).get();
      if (!merchantSnap.exists) {
        throw new HttpsError("not-found", "Comercio no encontrado.");
      }
      const merchantData = merchantSnap.data() ?? {};
      const merchantZoneId =
        typeof merchantData.zoneId === "string" ? merchantData.zoneId.trim() : "";
      if (merchantZoneId && merchantZoneId !== zoneId) {
        throw new HttpsError(
          "failed-precondition",
          "El comercio no corresponde a la zona reportada."
        );
      }
      const categoryId =
        typeof merchantData.categoryId === "string"
          ? merchantData.categoryId.trim()
          : "";
      if (!isPharmacyCategory(categoryId)) {
        throw new HttpsError(
          "failed-precondition",
          "Solo se aceptan reportes para farmacias de turno."
        );
      }

      const rawRequest = request.rawRequest as { ip?: string } | undefined;
      const ipHash = resolveIpHash(rawRequest?.ip);
      const nowMillis = Date.now();
      const dedupeId = createHash("sha256")
        .update([merchantId, zoneId, dateKey, reasonCode, ipHash].join("|"))
        .digest("hex");
      const dedupeRef = db().collection(DEDUPE_COLLECTION).doc(dedupeId);
      const reportRef = db().collection(REPORTS_COLLECTION).doc(randomUUID());

      let reportId: string | null = null;
      let created = false;
      let deduped = false;
      const usage = { reads: 3, writes: 1 };

      await db().runTransaction(async (tx) => {
        await assertOutdatedInfoRateLimit({
          tx,
          ipHash,
          nowMillis,
        });

        const dedupeSnap = await tx.get(dedupeRef);
        const createdAtMillisRaw = dedupeSnap.data()?.["createdAtMillis"];
        const dedupeCreatedAtMillis =
          typeof createdAtMillisRaw === "number" &&
            Number.isFinite(createdAtMillisRaw)
            ? Math.trunc(createdAtMillisRaw)
            : null;

        if (
          dedupeCreatedAtMillis != null &&
          nowMillis - dedupeCreatedAtMillis < DEDUPE_WINDOW_MS
        ) {
          deduped = true;
          const previousReportId = dedupeSnap.data()?.["lastReportId"];
          reportId =
            typeof previousReportId === "string" && previousReportId.trim().length > 0
              ? previousReportId.trim()
              : null;
          return;
        }

        reportId = reportRef.id;
        created = true;
        usage.writes += 2;

        tx.set(reportRef, {
          reportId: reportRef.id,
          targetType: "merchant",
          targetId: merchantId,
          reason: `outdated_info:${reasonCode}`,
          reasonCode,
          source,
          zoneId,
          dateKey,
          channel: "outdated_info",
          status: "open",
          ipHash,
          reportedBy:
            typeof request.auth?.uid === "string" &&
              request.auth.uid.trim().length > 0
              ? request.auth.uid.trim()
              : "anonymous",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        tx.set(
          dedupeRef,
          {
            merchantId,
            zoneId,
            dateKey,
            reasonCode,
            source,
            ipHash,
            createdAtMillis: nowMillis,
            expiresAt: Timestamp.fromMillis(nowMillis + DEDUPE_WINDOW_MS * 2),
            lastReportId: reportRef.id,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      });

      await trackUsage(usage);
      return {
        reportId,
        created,
        deduped,
      };
    }
  )
);
