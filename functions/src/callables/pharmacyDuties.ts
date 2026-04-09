import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  getFirestore,
  FieldValue,
  Timestamp,
  Transaction,
} from "firebase-admin/firestore";
import {
  addDaysToDateKey,
  areRangesOverlapping,
  formatDateInArgentina,
  isPharmacyCategory,
  isValidDateKey,
} from "../lib/pharmacyDuties";
import { todayDateString } from "../lib/schedules";

const db = () => getFirestore();

type PharmacyDutyStatus = "draft" | "published" | "cancelled";
type Role = "owner" | "admin" | "super_admin" | "customer" | "unknown";

interface PharmacyDutyDoc {
  merchantId: string;
  zoneId: string;
  date: string;
  startsAt: FirebaseFirestore.Timestamp;
  endsAt: FirebaseFirestore.Timestamp;
  status: PharmacyDutyStatus;
  sourceType: "owner_created" | "admin_created" | "external_seed";
  createdAt?: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
  createdBy: string;
  updatedBy: string;
  notes?: string | null;
}

interface UpsertPharmacyDutyRequest {
  merchantId?: string;
  dutyId?: string | null;
  date?: string;
  startsAt?: string;
  endsAt?: string;
  status?: "draft" | "published";
  notes?: string | null;
  expectedUpdatedAtMillis?: number | null;
}

interface UpsertPharmacyDutyResponse {
  dutyId: string;
  merchantId: string;
  zoneId: string;
  status: "draft" | "published";
  date: string;
  created: boolean;
  updatedAtMillis: number;
}

interface ChangePharmacyDutyStatusRequest {
  dutyId?: string;
  status?: PharmacyDutyStatus;
  expectedUpdatedAtMillis?: number | null;
}

interface ChangePharmacyDutyStatusResponse {
  dutyId: string;
  merchantId: string;
  status: PharmacyDutyStatus;
  updatedAtMillis: number;
}

interface ConflictResult {
  dutyId: string;
  startsAtMillis: number;
  endsAtMillis: number;
  date: string;
}

function parseIsoDate(value: unknown, field: string): Date {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} es requerido.`);
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpsError("invalid-argument", `${field} inválido.`);
  }
  return parsed;
}

function normalizeNotes(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "notes debe ser string.");
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > 500) {
    throw new HttpsError("invalid-argument", "notes excede 500 caracteres.");
  }
  return trimmed;
}

function normalizeExpectedUpdatedAt(value: unknown): number | null {
  if (value == null) return null;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError(
      "invalid-argument",
      "expectedUpdatedAtMillis debe ser numérico."
    );
  }
  return Math.trunc(value);
}

async function resolveCallerRole(
  uid: string,
  claimRole: unknown
): Promise<Role> {
  if (typeof claimRole === "string" && claimRole.trim().length > 0) {
    const normalized = claimRole.trim().toLowerCase();
    if (normalized === "owner") return "owner";
    if (normalized === "admin") return "admin";
    if (normalized === "super_admin") return "super_admin";
    if (normalized === "customer") return "customer";
  }

  const userSnap = await db().doc(`users/${uid}`).get();
  const roleValue = (userSnap.data()?.["role"] as string | undefined) ?? "";
  const normalized = roleValue.trim().toLowerCase();
  if (normalized === "owner") return "owner";
  if (normalized === "admin") return "admin";
  if (normalized === "super_admin") return "super_admin";
  if (normalized === "customer") return "customer";
  return "unknown";
}

function assertMutableRole(role: Role): void {
  if (role === "owner" || role === "admin" || role === "super_admin") return;
  throw new HttpsError(
    "permission-denied",
    "No tenés permisos para gestionar turnos de farmacia."
  );
}

function assertExpectedUpdatedAt(
  expectedMillis: number | null,
  current: FirebaseFirestore.Timestamp | undefined
): void {
  if (expectedMillis == null || !current) return;
  if (current.toMillis() !== expectedMillis) {
    throw new HttpsError(
      "aborted",
      "Este turno fue actualizado en otra sesión."
    );
  }
}

function assertOwnerCanEditPastDate(
  role: Role,
  dateKey: string
): void {
  if (role === "admin" || role === "super_admin") return;
  if (dateKey < todayDateString()) {
    throw new HttpsError(
      "failed-precondition",
      "No podés editar turnos de fechas pasadas."
    );
  }
}

function buildConflictError(conflict: ConflictResult): HttpsError {
  return new HttpsError(
    "already-exists",
    "Ya existe un turno cargado para ese día y horario.",
    {
      code: "duty_conflict",
      conflict,
    }
  );
}

async function assertMerchantAccessAndGetContext(
  merchantId: string,
  uid: string,
  role: Role,
  tx?: Transaction
): Promise<{ zoneId: string }> {
  const merchantRef = db().doc(`merchants/${merchantId}`);
  const merchantSnap = tx ? await tx.get(merchantRef) : await merchantRef.get();
  if (!merchantSnap.exists) {
    throw new HttpsError("not-found", "Comercio no encontrado.");
  }
  const merchantData = merchantSnap.data() ?? {};

  const ownerUserId =
    (merchantData["ownerUserId"] as string | undefined)?.trim() ?? "";
  if (role === "owner" && ownerUserId !== uid) {
    throw new HttpsError(
      "permission-denied",
      "No podés modificar turnos de otro comercio."
    );
  }

  const isPharmacy = merchantData["isPharmacy"] === true ||
    isPharmacyCategory(merchantData["categoryId"]) ||
    isPharmacyCategory(merchantData["category"]);
  if (!isPharmacy) {
    throw new HttpsError(
      "failed-precondition",
      "Solo farmacias pueden usar este módulo."
    );
  }

  const zoneId =
    (merchantData["zoneId"] as string | undefined)?.trim() ||
    (merchantData["zone"] as string | undefined)?.trim() ||
    "";
  if (zoneId.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Tu comercio no tiene zona configurada."
    );
  }

  return { zoneId };
}

async function findPublishedConflict(params: {
  tx: Transaction;
  merchantId: string;
  date: string;
  startsAt: Date;
  endsAt: Date;
  excludeDutyId?: string;
}): Promise<ConflictResult | null> {
  const prevDate = addDaysToDateKey(params.date, -1);
  const nextDate = addDaysToDateKey(params.date, 1);
  const query = db()
    .collection("pharmacy_duties")
    .where("merchantId", "==", params.merchantId)
    .where("date", ">=", prevDate)
    .where("date", "<=", nextDate);
  const snap = await params.tx.get(query);

  for (const doc of snap.docs) {
    if (params.excludeDutyId && doc.id === params.excludeDutyId) continue;
    const duty = doc.data() as Partial<PharmacyDutyDoc>;
    if (duty.status !== "published") continue;
    if (!(duty.startsAt instanceof Timestamp) || !(duty.endsAt instanceof Timestamp)) {
      continue;
    }

    const hasConflict = areRangesOverlapping(
      params.startsAt,
      params.endsAt,
      duty.startsAt.toDate(),
      duty.endsAt.toDate()
    );
    if (hasConflict) {
      return {
        dutyId: doc.id,
        startsAtMillis: duty.startsAt.toMillis(),
        endsAtMillis: duty.endsAt.toMillis(),
        date: (duty.date as string | undefined) ?? params.date,
      };
    }
  }

  return null;
}

export const upsertPharmacyDuty = onCall<
  UpsertPharmacyDutyRequest,
  Promise<UpsertPharmacyDutyResponse>
>(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }

    const uid = request.auth.uid;
    const role = await resolveCallerRole(uid, request.auth.token.role);
    assertMutableRole(role);

    const merchantId = (request.data.merchantId ?? "").trim();
    if (merchantId.length === 0) {
      throw new HttpsError("invalid-argument", "merchantId es requerido.");
    }
    const dateKey = (request.data.date ?? "").trim();
    if (!isValidDateKey(dateKey)) {
      throw new HttpsError("invalid-argument", "date debe ser YYYY-MM-DD.");
    }

    const startsAtDate = parseIsoDate(request.data.startsAt, "startsAt");
    const endsAtDate = parseIsoDate(request.data.endsAt, "endsAt");
    if (startsAtDate >= endsAtDate) {
      throw new HttpsError(
        "invalid-argument",
        "La hora de fin debe ser posterior a la hora de inicio."
      );
    }

    const startsAtDateKey = formatDateInArgentina(startsAtDate);
    if (startsAtDateKey !== dateKey) {
      throw new HttpsError(
        "invalid-argument",
        "date debe coincidir con el día operativo de startsAt (UTC-3)."
      );
    }

    const status = request.data.status;
    if (status !== "draft" && status !== "published") {
      throw new HttpsError(
        "invalid-argument",
        "status debe ser draft o published."
      );
    }

    const notes = normalizeNotes(request.data.notes);
    const expectedUpdatedAtMillis = normalizeExpectedUpdatedAt(
      request.data.expectedUpdatedAtMillis
    );
    assertOwnerCanEditPastDate(role, dateKey);

    const dutyId = (request.data.dutyId ?? "").trim();
    const dutyRef = dutyId.length === 0
      ? db().collection("pharmacy_duties").doc()
      : db().doc(`pharmacy_duties/${dutyId}`);

    const startsAtTs = Timestamp.fromDate(startsAtDate);
    const endsAtTs = Timestamp.fromDate(endsAtDate);
    let resolvedZoneId = "";

    await db().runTransaction(async (tx) => {
      const merchantContext = await assertMerchantAccessAndGetContext(
        merchantId,
        uid,
        role,
        tx
      );
      resolvedZoneId = merchantContext.zoneId;

      const existingSnap = await tx.get(dutyRef);
      if (existingSnap.exists) {
        const existing = existingSnap.data() as PharmacyDutyDoc;
        if (existing.merchantId !== merchantId) {
          throw new HttpsError("permission-denied", "dutyId inválido.");
        }
        assertExpectedUpdatedAt(expectedUpdatedAtMillis, existing.updatedAt);
      }

      const conflict = await findPublishedConflict({
        tx,
        merchantId,
        date: dateKey,
        startsAt: startsAtDate,
        endsAt: endsAtDate,
        excludeDutyId: existingSnap.exists ? dutyRef.id : undefined,
      });
      if (conflict) {
        throw buildConflictError(conflict);
      }

      const sourceType = role === "owner" ? "owner_created" : "admin_created";
      const basePayload = {
        merchantId,
        zoneId: merchantContext.zoneId,
        date: dateKey,
        startsAt: startsAtTs,
        endsAt: endsAtTs,
        status,
        notes,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: uid,
      };

      if (!existingSnap.exists) {
        tx.set(dutyRef, {
          ...basePayload,
          sourceType,
          createdAt: FieldValue.serverTimestamp(),
          createdBy: uid,
        });
      } else {
        tx.update(dutyRef, basePayload);
      }
    });

    const savedSnap = await dutyRef.get();
    const saved = savedSnap.data() as PharmacyDutyDoc | undefined;
    const savedUpdatedAt = saved?.updatedAt;

    console.log(
      `[upsertPharmacyDuty] uid=${uid} merchantId=${merchantId} dutyId=${dutyRef.id} status=${status}`
    );

    return {
      dutyId: dutyRef.id,
      merchantId,
      zoneId: resolvedZoneId,
      status,
      date: dateKey,
      created: dutyId.length === 0,
      updatedAtMillis: savedUpdatedAt?.toMillis() ?? Date.now(),
    };
  }
);

export const changePharmacyDutyStatus = onCall<
  ChangePharmacyDutyStatusRequest,
  Promise<ChangePharmacyDutyStatusResponse>
>(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }
    const dutyId = (request.data.dutyId ?? "").trim();
    if (dutyId.length === 0) {
      throw new HttpsError("invalid-argument", "dutyId es requerido.");
    }
    const nextStatus = request.data.status;
    if (
      nextStatus !== "draft" &&
      nextStatus !== "published" &&
      nextStatus !== "cancelled"
    ) {
      throw new HttpsError("invalid-argument", "status inválido.");
    }

    const uid = request.auth.uid;
    const role = await resolveCallerRole(uid, request.auth.token.role);
    assertMutableRole(role);

    const dutyRef = db().doc(`pharmacy_duties/${dutyId}`);
    const expectedUpdatedAtMillis = normalizeExpectedUpdatedAt(
      request.data.expectedUpdatedAtMillis
    );
    let merchantId = "";

    await db().runTransaction(async (tx) => {
      const dutySnap = await tx.get(dutyRef);
      if (!dutySnap.exists) {
        throw new HttpsError("not-found", "Turno no encontrado.");
      }
      const duty = dutySnap.data() as PharmacyDutyDoc;
      merchantId = duty.merchantId;
      assertExpectedUpdatedAt(expectedUpdatedAtMillis, duty.updatedAt);
      assertOwnerCanEditPastDate(role, duty.date);
      await assertMerchantAccessAndGetContext(duty.merchantId, uid, role, tx);

      if (nextStatus === "published") {
        const conflict = await findPublishedConflict({
          tx,
          merchantId: duty.merchantId,
          date: duty.date,
          startsAt: duty.startsAt.toDate(),
          endsAt: duty.endsAt.toDate(),
          excludeDutyId: dutyId,
        });
        if (conflict) {
          throw buildConflictError(conflict);
        }
      }

      tx.update(dutyRef, {
        status: nextStatus,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: uid,
      });
    });

    const savedSnap = await dutyRef.get();
    const saved = savedSnap.data() as PharmacyDutyDoc | undefined;
    const updatedAt = saved?.updatedAt;

    console.log(
      `[changePharmacyDutyStatus] uid=${uid} merchantId=${merchantId} dutyId=${dutyId} status=${nextStatus}`
    );

    return {
      dutyId,
      merchantId,
      status: nextStatus,
      updatedAtMillis: updatedAt?.toMillis() ?? Date.now(),
    };
  }
);
