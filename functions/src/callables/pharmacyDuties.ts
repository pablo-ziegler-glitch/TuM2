import { randomUUID } from "crypto";
import {
  FieldValue,
  Timestamp,
  Transaction,
  getFirestore,
} from "firebase-admin/firestore";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import {
  addDaysToDateKey,
  areRangesOverlapping,
  formatDateInArgentina,
  isPharmacyCategory,
  isValidDateKey,
} from "../lib/pharmacyDuties";
import {
  DEFAULT_PHARMACY_DUTY_RULES_CONFIG,
  DutyConfidenceLevel,
  DutyConfirmationStatus,
  DutyPublicStatusLabel,
  DutyStatus,
  IncidentType,
  PharmacyDutyRulesConfig,
  RequestAction,
  RequestStatus,
  assertMutableRole,
  deriveDutyPublicState,
  distanceBucket,
  haversineDistanceKm,
  isAdminRole,
  normalizeDutyStatus,
  normalizeNote,
  parseIncidentType,
  parsePositiveInt,
  parseRequestAction,
  resolveActorRole,
  roundDistance,
} from "../lib/pharmacyDutyMitigation";
import { todayDateString } from "../lib/schedules";

const db = () => getFirestore();
const PHARMACY_DUTY_RULES_DOC = "admin_configs/pharmacyDutyRules";
const CONFIG_CACHE_TTL_MS = 60_000;
const PHARMACY_DUTY_MUTATION_RATE_LIMIT_COLLECTION =
  "pharmacy_duty_mutation_rate_limits";

let dutyRulesCache:
  | {
    config: PharmacyDutyRulesConfig;
    expiresAtMs: number;
  }
  | undefined;

function readIntEnv(params: {
  key: string;
  fallback: number;
  min: number;
  max: number;
}): number {
  const raw = process.env[params.key];
  if (raw == null || raw.trim().length === 0) return params.fallback;
  const value = Number.parseInt(raw, 10);
  if (!Number.isFinite(value)) return params.fallback;
  return Math.min(params.max, Math.max(params.min, value));
}

const PHARMACY_DUTY_MUTATION_RATE_LIMIT_WINDOW_MS = readIntEnv({
  key: "PHARMACY_DUTY_MUTATION_RATE_LIMIT_WINDOW_MS",
  fallback: 60_000,
  min: 10_000,
  max: 3_600_000,
});

const PHARMACY_DUTY_MUTATION_RATE_LIMIT_MAX = readIntEnv({
  key: "PHARMACY_DUTY_MUTATION_RATE_LIMIT_MAX",
  fallback: 12,
  min: 1,
  max: 200,
});

interface MerchantLocation {
  lat: number;
  lng: number;
}

interface MerchantContext {
  merchantId: string;
  ownerUserId: string;
  zoneId: string;
  categoryId: string;
  status: string;
  name: string;
  location: MerchantLocation | null;
}

interface PharmacyDutyDoc {
  merchantId: string;
  originMerchantId?: string;
  replacementMerchantId?: string;
  zoneId: string;
  date: string;
  startsAt: FirebaseFirestore.Timestamp | string;
  endsAt: FirebaseFirestore.Timestamp | string;
  status: DutyStatus | string;
  confirmationStatus?: DutyConfirmationStatus | string;
  verificationStatus?: "claimed" | "validated" | "verified" | "referential";
  sourceType: "owner_created" | "admin_created" | "external_seed" | "system_reassigned";
  createdAt?: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
  createdBy: string;
  updatedBy: string;
  notes?: string | null;
  confirmedAt?: FirebaseFirestore.Timestamp;
  confirmedByUserId?: string;
  incidentOpen?: boolean;
  incidentId?: string;
  replacementRoundOpen?: boolean;
  replacementAcceptedAt?: FirebaseFirestore.Timestamp;
  confidenceLevel?: DutyConfidenceLevel;
  publicStatusLabel?: DutyPublicStatusLabel;
}

interface PharmacyDutyIncidentDoc {
  dutyId: string;
  merchantId: string;
  zoneId: string;
  incidentType: IncidentType;
  note?: string;
  status: "open" | "covered" | "expired" | "cancelled";
  createdByUserId: string;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  resolvedAt?: FirebaseFirestore.Timestamp;
  resolvedByUserId?: string;
}

interface ReassignmentRoundDoc {
  dutyId: string;
  incidentId: string;
  originMerchantId: string;
  zoneId: string;
  status: "open" | "covered" | "expired" | "cancelled";
  maxDistanceKmApplied: number;
  candidateCount: number;
  acceptedRequestId?: string;
  acceptedMerchantId?: string;
  expiresAt: FirebaseFirestore.Timestamp;
  createdByUserId: string;
  createdAt: FirebaseFirestore.Timestamp;
  closedAt?: FirebaseFirestore.Timestamp;
  lastEventAt: FirebaseFirestore.Timestamp;
}

interface ReassignmentRequestDoc {
  roundId: string;
  dutyId: string;
  incidentId: string;
  originMerchantId: string;
  candidateMerchantId: string;
  zoneId: string;
  distanceKm: number;
  status: RequestStatus;
  sentAt: FirebaseFirestore.Timestamp;
  expiresAt: FirebaseFirestore.Timestamp;
  respondedAt?: FirebaseFirestore.Timestamp;
  responseReason?:
    | "accepted"
    | "rejected"
    | "expired"
    | "cancelled_due_to_other_acceptance";
  createdByUserId: string;
  responseByUserId?: string;
  lastEventAt: FirebaseFirestore.Timestamp;
}

interface UpsertPharmacyDutyRequest {
  merchantId?: string;
  dutyId?: string | null;
  date?: string;
  startsAt?: string;
  endsAt?: string;
  status?: string;
  notes?: string | null;
  expectedUpdatedAtMillis?: number | null;
}

interface UpsertPharmacyDutyResponse {
  dutyId: string;
  merchantId: string;
  zoneId: string;
  status: DutyStatus;
  confirmationStatus: DutyConfirmationStatus;
  date: string;
  created: boolean;
  updatedAtMillis: number;
}

interface ChangePharmacyDutyStatusRequest {
  dutyId?: string;
  status?: string;
  expectedUpdatedAtMillis?: number | null;
}

interface ChangePharmacyDutyStatusResponse {
  dutyId: string;
  merchantId: string;
  status: DutyStatus;
  updatedAtMillis: number;
}

interface ConfirmPharmacyDutyRequest {
  dutyId?: string;
}

interface ConfirmPharmacyDutyResponse {
  dutyId: string;
  merchantId: string;
  status: DutyStatus;
  confirmationStatus: DutyConfirmationStatus;
  confirmedAtMillis: number;
}

interface ReportPharmacyDutyIncidentRequest {
  dutyId?: string;
  incidentType?: IncidentType;
  note?: string;
}

interface ReportPharmacyDutyIncidentResponse {
  dutyId: string;
  incidentId: string;
  status: DutyStatus;
  confirmationStatus: DutyConfirmationStatus;
}

interface GetEligibleReplacementCandidatesRequest {
  dutyId?: string;
}

interface ReplacementCandidate {
  merchantId: string;
  merchantName: string;
  zoneId: string;
  distanceKm: number;
  distanceBucket: string;
}

interface GetEligibleReplacementCandidatesResponse {
  dutyId: string;
  originMerchantId: string;
  maxDistanceKmApplied: number;
  maxCandidatesPerRound: number;
  candidates: ReplacementCandidate[];
}

interface CreateReassignmentRoundRequest {
  dutyId?: string;
  candidateMerchantIds?: string[];
}

interface CreateReassignmentRoundResponse {
  dutyId: string;
  incidentId: string;
  roundId: string;
  requestCount: number;
  expiresAtMillis: number;
}

interface RespondToReassignmentRequestRequest {
  requestId?: string;
  action?: RequestAction;
}

interface RespondToReassignmentRequestResponse {
  requestId: string;
  dutyId: string;
  roundId: string;
  requestStatus: RequestStatus;
  roundStatus: "open" | "covered" | "expired" | "cancelled";
  dutyStatus: DutyStatus;
}

interface CancelReassignmentRoundRequest {
  roundId?: string;
}

interface CancelReassignmentRoundResponse {
  roundId: string;
  dutyId: string;
  roundStatus: "open" | "covered" | "expired" | "cancelled";
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

function extractString(data: Record<string, unknown>, key: string): string {
  const value = data[key];
  if (typeof value !== "string") return "";
  return value.trim();
}

function extractMerchantLocation(
  data: Record<string, unknown>
): MerchantLocation | null {
  const nested = data["primaryLocation"];
  if (nested && typeof nested === "object") {
    const location = nested as Record<string, unknown>;
    const lat = typeof location["lat"] === "number" ? location["lat"] : null;
    const lng = typeof location["lng"] === "number" ? location["lng"] : null;
    if (lat != null && lng != null) return { lat, lng };
  }

  const lat = typeof data["lat"] === "number" ? data["lat"] : null;
  const lng = typeof data["lng"] === "number" ? data["lng"] : null;
  if (lat != null && lng != null) return { lat, lng };
  return null;
}

function toDutyDate(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
}

function parseClaimMerchantId(claimMerchantId: unknown): string | null {
  if (typeof claimMerchantId !== "string") return null;
  const value = claimMerchantId.trim();
  return value.length > 0 ? value : null;
}

function resolveCorrelationId<T>(request: CallableRequest<T>): string {
  const headers = request.rawRequest.headers;
  const direct = headers["x-correlation-id"];
  if (typeof direct === "string" && direct.trim().length > 0) {
    return direct.trim();
  }
  if (Array.isArray(direct) && direct.length > 0) {
    const first = direct[0]?.trim();
    if (first) return first;
  }
  return randomUUID();
}

function logStructured(
  event: string,
  payload: Record<string, unknown>
): void {
  console.log(JSON.stringify({ event, ...payload }));
}

function resolveConflictReason(error: unknown): string | null {
  if (!(error instanceof HttpsError)) return null;
  const details = error.details;
  if (details && typeof details === "object") {
    const detailCode = (details as Record<string, unknown>)["code"];
    if (typeof detailCode === "string" && detailCode.trim().length > 0) {
      return detailCode.trim();
    }
  }
  return error.code;
}

function logDutyMutationEvent(params: {
  action: string;
  result: "success" | "error";
  actorUserId: string;
  correlationId: string;
  merchantId?: string;
  dutyId?: string;
  roundId?: string;
  requestId?: string;
  conflictReason?: string | null;
  errorCode?: string | null;
}): void {
  logStructured("pharmacy_duty_mutation", {
    action: params.action,
    result: params.result,
    actorUserId: params.actorUserId,
    merchantId: params.merchantId ?? null,
    dutyId: params.dutyId ?? null,
    roundId: params.roundId ?? null,
    requestId: params.requestId ?? null,
    conflictReason: params.conflictReason ?? null,
    errorCode: params.errorCode ?? null,
    correlationId: params.correlationId,
  });
}

async function assertMutationRateLimit(params: {
  tx: Transaction;
  action: string;
  uid: string;
  merchantId: string;
  nowMillis?: number;
}): Promise<void> {
  const normalizedMerchantId = params.merchantId.trim();
  if (normalizedMerchantId.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "merchantId es requerido para controlar rate limit."
    );
  }

  const nowMillis = params.nowMillis ?? Date.now();
  const windowMs = PHARMACY_DUTY_MUTATION_RATE_LIMIT_WINDOW_MS;
  const windowStartMillis = Math.floor(nowMillis / windowMs) * windowMs;
  const retryAfterMillis = windowStartMillis + windowMs - nowMillis;
  const docId = [
    params.action.trim().toLowerCase(),
    params.uid.trim(),
    normalizedMerchantId.split("/").join("_"),
    String(windowStartMillis),
  ].join("__");
  const limiterRef = db()
    .collection(PHARMACY_DUTY_MUTATION_RATE_LIMIT_COLLECTION)
    .doc(docId);
  const limiterSnap = await params.tx.get(limiterRef);
  const previousCountRaw = limiterSnap.data()?.["count"];
  const previousCount =
    typeof previousCountRaw === "number" && Number.isFinite(previousCountRaw)
      ? Math.max(0, Math.trunc(previousCountRaw))
      : 0;
  const nextCount = previousCount + 1;

  if (nextCount > PHARMACY_DUTY_MUTATION_RATE_LIMIT_MAX) {
    throw new HttpsError(
      "resource-exhausted",
      "Demasiadas mutaciones en poco tiempo. Intentá nuevamente en unos segundos.",
      {
        code: "rate_limited",
        action: params.action,
        merchantId: normalizedMerchantId,
        retryAfterMillis: Math.max(1, retryAfterMillis),
      }
    );
  }

  params.tx.set(
    limiterRef,
    {
      action: params.action,
      uid: params.uid,
      merchantId: normalizedMerchantId,
      count: nextCount,
      windowStartMillis,
      windowDurationMillis: windowMs,
      expiresAt: Timestamp.fromMillis(windowStartMillis + windowMs * 2),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
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

function assertOwnerCanEditPastDate(role: ReturnType<typeof resolveActorRole>, dateKey: string): void {
  if (isAdminRole(role)) return;
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

async function getPharmacyDutyRulesConfig(): Promise<PharmacyDutyRulesConfig> {
  // Cache in-memory de corta vida para evitar read por callable.
  if (dutyRulesCache && dutyRulesCache.expiresAtMs > Date.now()) {
    return dutyRulesCache.config;
  }

  const snap = await db().doc(PHARMACY_DUTY_RULES_DOC).get();
  if (!snap.exists) {
    dutyRulesCache = {
      config: DEFAULT_PHARMACY_DUTY_RULES_CONFIG,
      expiresAtMs: Date.now() + CONFIG_CACHE_TTL_MS,
    };
    return DEFAULT_PHARMACY_DUTY_RULES_CONFIG;
  }

  const raw = snap.data() ?? {};
  const config: PharmacyDutyRulesConfig = {
    maxReassignmentDistanceKm: parsePositiveInt(
      raw["maxReassignmentDistanceKm"],
      {
        field: "maxReassignmentDistanceKm",
        fallback: DEFAULT_PHARMACY_DUTY_RULES_CONFIG.maxReassignmentDistanceKm,
        min: 1,
        max: 50,
      }
    ),
    requestExpiryMinutes: parsePositiveInt(raw["requestExpiryMinutes"], {
      field: "requestExpiryMinutes",
      fallback: DEFAULT_PHARMACY_DUTY_RULES_CONFIG.requestExpiryMinutes,
      min: 5,
      max: 120,
    }),
    maxCandidatesPerRound: parsePositiveInt(raw["maxCandidatesPerRound"], {
      field: "maxCandidatesPerRound",
      fallback: DEFAULT_PHARMACY_DUTY_RULES_CONFIG.maxCandidatesPerRound,
      min: 1,
      max: 20,
    }),
    allowParallelRequests: raw["allowParallelRequests"] !== false,
    preventMultipleOpenRoundsPerDuty:
      raw["preventMultipleOpenRoundsPerDuty"] !== false,
  };

  dutyRulesCache = {
    config,
    expiresAtMs: Date.now() + CONFIG_CACHE_TTL_MS,
  };
  return config;
}

async function assertMerchantAccessAndGetContext(
  merchantId: string,
  uid: string,
  role: ReturnType<typeof resolveActorRole>,
  claimMerchantId: string | null,
  tx?: Transaction
): Promise<MerchantContext> {
  const merchantRef = db().doc(`merchants/${merchantId}`);
  const merchantSnap = tx ? await tx.get(merchantRef) : await merchantRef.get();
  if (!merchantSnap.exists) {
    throw new HttpsError("not-found", "Comercio no encontrado.");
  }
  const merchantData = merchantSnap.data() ?? {};

  const ownerUserId =
    (merchantData["ownerUserId"] as string | undefined)?.trim() ?? "";
  if (role === "owner") {
    // Seguridad: para mutaciones críticas con Admin SDK exigimos ownership vivo
    // en merchants/{id}. El claim merchantId no alcanza por sí solo porque puede
    // quedar stale durante cambios de ownership.
    if (ownerUserId.length === 0 || ownerUserId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "No podés operar guardias de otro comercio."
      );
    }
  }

  const categoryId =
    extractString(merchantData, "categoryId") ||
    extractString(merchantData, "category");
  const isPharmacy = merchantData["isPharmacy"] === true ||
    isPharmacyCategory(categoryId);
  if (!isPharmacy) {
    throw new HttpsError(
      "failed-precondition",
      "Solo farmacias pueden operar guardias."
    );
  }

  const zoneId =
    extractString(merchantData, "zoneId") ||
    extractString(merchantData, "zone");
  if (zoneId.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "El comercio no tiene zoneId configurado."
    );
  }

  return {
    merchantId,
    ownerUserId,
    zoneId,
    categoryId,
    status: extractString(merchantData, "status"),
    name: extractString(merchantData, "name") || merchantId,
    location: extractMerchantLocation(merchantData),
  };
}

async function assertOwnerControlsMerchant(
  merchantId: string,
  uid: string,
  role: ReturnType<typeof resolveActorRole>,
  claimMerchantId: string | null,
  tx?: Transaction
): Promise<void> {
  if (isAdminRole(role)) return;
  if (role !== "owner") {
    throw new HttpsError(
      "permission-denied",
      "No tenés permisos para operar solicitudes de cobertura."
    );
  }
  await assertMerchantAccessAndGetContext(
    merchantId,
    uid,
    role,
    claimMerchantId,
    tx
  );
}

async function findDutyConflict(params: {
  tx: Transaction;
  merchantId: string;
  date: string;
  startsAt: Date;
  endsAt: Date;
  excludeDutyId?: string;
}): Promise<ConflictResult | null> {
  // Sólo leemos ventana acotada de 3 días para evitar escaneos amplios.
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
    const status = normalizeDutyStatus(duty.status ?? "scheduled");
    if (status === "cancelled") continue;
    const startsAt = toDutyDate(duty.startsAt);
    const endsAt = toDutyDate(duty.endsAt);
    if (!startsAt || !endsAt) continue;

    const hasConflict = areRangesOverlapping(
      params.startsAt,
      params.endsAt,
      startsAt,
      endsAt
    );
    if (!hasConflict) continue;
    return {
      dutyId: doc.id,
      startsAtMillis: startsAt.getTime(),
      endsAtMillis: endsAt.getTime(),
      date: (duty.date as string | undefined) ?? params.date,
    };
  }

  return null;
}

function applyDerivedDutyState(input: {
  status: DutyStatus;
  confirmationStatus: DutyConfirmationStatus;
  incidentOpen: boolean;
}): { confidenceLevel: DutyConfidenceLevel; publicStatusLabel: DutyPublicStatusLabel } {
  return deriveDutyPublicState({
    status: input.status,
    confirmationStatus: input.confirmationStatus,
    incidentOpen: input.incidentOpen,
  });
}

function parseCandidateMerchantIds(value: unknown): string[] {
  if (!Array.isArray(value)) {
    throw new HttpsError(
      "invalid-argument",
      "candidateMerchantIds debe ser un array."
    );
  }
  const normalized = value
    .map((entry) => (typeof entry === "string" ? entry.trim() : ""))
    .filter((entry) => entry.length > 0);
  return Array.from(new Set(normalized));
}

function assertCandidateEligible(candidate: MerchantContext, zoneId: string): void {
  if (candidate.zoneId !== zoneId) {
    throw new HttpsError(
      "failed-precondition",
      "La candidata no pertenece a la misma zona."
    );
  }
  if (!isPharmacyCategory(candidate.categoryId)) {
    throw new HttpsError(
      "failed-precondition",
      "Solo farmacias pueden cubrir guardias."
    );
  }
  if (candidate.status !== "active") {
    throw new HttpsError(
      "failed-precondition",
      "La candidata no está activa."
    );
  }
  if (!candidate.location) {
    throw new HttpsError(
      "failed-precondition",
      "La candidata no tiene coordenadas configuradas."
    );
  }
}

function dutyResponseSummary(duty: PharmacyDutyDoc): {
  status: DutyStatus;
  confirmationStatus: DutyConfirmationStatus;
} {
  return {
    status: normalizeDutyStatus(duty.status),
    confirmationStatus:
      duty.confirmationStatus === "confirmed" ||
        duty.confirmationStatus === "overdue" ||
        duty.confirmationStatus === "incident_reported" ||
        duty.confirmationStatus === "replaced"
        ? duty.confirmationStatus
        : "pending",
  };
}

export const upsertPharmacyDuty = onCall<
  UpsertPharmacyDutyRequest,
  Promise<UpsertPharmacyDutyResponse>
>(
  { enforceAppCheck: true },
  async (request) => {
    const action = "upsert_duty";
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }

    const correlationId = resolveCorrelationId(request);
    const uid = request.auth.uid;
    const role = resolveActorRole(request.auth.token.role);
    const claimMerchantId = parseClaimMerchantId(request.auth.token.merchantId);
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

    const requestedStatus = normalizeDutyStatus(request.data.status);
    const status: DutyStatus = requestedStatus === "cancelled"
      ? "cancelled"
      : "scheduled";
    const notes = normalizeNote(request.data.notes);
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
    let confirmationStatus: DutyConfirmationStatus = "pending";
    let resolvedMerchantId = merchantId;

    try {
      await db().runTransaction(async (tx) => {
        const merchantContext = await assertMerchantAccessAndGetContext(
          merchantId,
          uid,
          role,
          claimMerchantId,
          tx
        );
        resolvedZoneId = merchantContext.zoneId;
        resolvedMerchantId = merchantContext.merchantId;
        await assertMutationRateLimit({
          tx,
          action,
          uid,
          merchantId: merchantContext.merchantId,
        });

        const existingSnap = await tx.get(dutyRef);
        const existing = existingSnap.exists
          ? (existingSnap.data() as PharmacyDutyDoc)
          : null;

        if (existing) {
          if (existing.merchantId !== merchantId) {
            throw new HttpsError("permission-denied", "dutyId inválido.");
          }
          assertExpectedUpdatedAt(expectedUpdatedAtMillis, existing.updatedAt);
        }

        const conflict = await findDutyConflict({
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

        const nextConfirmationStatus: DutyConfirmationStatus = existing?.confirmationStatus === "confirmed" ||
            existing?.confirmationStatus === "overdue" ||
            existing?.confirmationStatus === "incident_reported" ||
            existing?.confirmationStatus === "replaced"
          ? existing.confirmationStatus
          : "pending";
        confirmationStatus = nextConfirmationStatus;
        const incidentOpen = existing?.incidentOpen === true;
        const derived = applyDerivedDutyState({
          status,
          confirmationStatus: nextConfirmationStatus,
          incidentOpen,
        });
        const sourceType = existing?.sourceType ??
          (role === "owner" ? "owner_created" : "admin_created");

        const payload: Record<string, unknown> = {
          merchantId,
          originMerchantId: existing?.originMerchantId ?? merchantId,
          zoneId: merchantContext.zoneId,
          date: dateKey,
          startsAt: startsAtTs,
          endsAt: endsAtTs,
          status,
          confirmationStatus: nextConfirmationStatus,
          verificationStatus: existing?.verificationStatus ?? (role === "owner" ? "claimed" : "validated"),
          sourceType,
          notes,
          incidentOpen,
          incidentId: existing?.incidentId ?? null,
          replacementRoundOpen: existing?.replacementRoundOpen ?? false,
          replacementMerchantId: existing?.replacementMerchantId ?? null,
          replacementAcceptedAt: existing?.replacementAcceptedAt ?? null,
          confidenceLevel: derived.confidenceLevel,
          publicStatusLabel: derived.publicStatusLabel,
          lastStatusChangedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: uid,
        };

        if (!existing) {
          tx.set(dutyRef, {
            ...payload,
            createdAt: FieldValue.serverTimestamp(),
            createdBy: uid,
          });
        } else {
          tx.update(dutyRef, payload);
        }
      });

      const savedSnap = await dutyRef.get();
      const saved = savedSnap.data() as PharmacyDutyDoc | undefined;
      const summary = saved ? dutyResponseSummary(saved) : {
        status,
        confirmationStatus,
      };

      logStructured("pharmacy_duty_upserted", {
        dutyId: dutyRef.id,
        actorUserId: uid,
        actorMerchantId: resolvedMerchantId,
        zoneId: resolvedZoneId,
        nextStatus: summary.status,
        correlationId,
      });
      logDutyMutationEvent({
        action,
        result: "success",
        actorUserId: uid,
        correlationId,
        merchantId: resolvedMerchantId,
        dutyId: dutyRef.id,
      });

      return {
        dutyId: dutyRef.id,
        merchantId,
        zoneId: resolvedZoneId,
        status: summary.status,
        confirmationStatus: summary.confirmationStatus,
        date: dateKey,
        created: dutyId.length === 0,
        updatedAtMillis: saved?.updatedAt?.toMillis() ?? Date.now(),
      };
    } catch (error) {
      logDutyMutationEvent({
        action,
        result: "error",
        actorUserId: uid,
        correlationId,
        merchantId: resolvedMerchantId,
        dutyId: dutyId.length === 0 ? dutyRef.id : dutyId,
        conflictReason: resolveConflictReason(error),
        errorCode: error instanceof HttpsError ? error.code : "internal",
      });
      throw error;
    }
  }
);

export const changePharmacyDutyStatus = onCall<
  ChangePharmacyDutyStatusRequest,
  Promise<ChangePharmacyDutyStatusResponse>
>(
  { enforceAppCheck: true },
  async (request) => {
    const action = "change_duty_status";
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }

    const correlationId = resolveCorrelationId(request);
    const dutyId = (request.data.dutyId ?? "").trim();
    if (dutyId.length === 0) {
      throw new HttpsError("invalid-argument", "dutyId es requerido.");
    }

    const nextStatusRaw = normalizeDutyStatus(request.data.status);
    if (nextStatusRaw !== "scheduled" && nextStatusRaw !== "cancelled") {
      throw new HttpsError(
        "invalid-argument",
        "status sólo permite scheduled o cancelled."
      );
    }

    const uid = request.auth.uid;
    const role = resolveActorRole(request.auth.token.role);
    const claimMerchantId = parseClaimMerchantId(request.auth.token.merchantId);
    assertMutableRole(role);

    const dutyRef = db().doc(`pharmacy_duties/${dutyId}`);
    const expectedUpdatedAtMillis = normalizeExpectedUpdatedAt(
      request.data.expectedUpdatedAtMillis
    );
    let merchantId = "";
    let nextStatus: DutyStatus = nextStatusRaw;

    try {
      await db().runTransaction(async (tx) => {
        const dutySnap = await tx.get(dutyRef);
        if (!dutySnap.exists) {
          throw new HttpsError("not-found", "Turno no encontrado.");
        }
        const duty = dutySnap.data() as PharmacyDutyDoc;
        merchantId = duty.merchantId;
        await assertMutationRateLimit({
          tx,
          action,
          uid,
          merchantId: duty.merchantId,
        });
        assertExpectedUpdatedAt(expectedUpdatedAtMillis, duty.updatedAt);
        assertOwnerCanEditPastDate(role, duty.date);
        await assertOwnerControlsMerchant(
          duty.merchantId,
          uid,
          role,
          claimMerchantId,
          tx
        );

        if (nextStatusRaw === "cancelled" && duty.replacementRoundOpen === true) {
          throw new HttpsError(
            "failed-precondition",
            "No podés cancelar una guardia con una ronda de cobertura abierta."
          );
        }

        const confirmationStatus: DutyConfirmationStatus =
          duty.confirmationStatus === "confirmed" ||
            duty.confirmationStatus === "overdue" ||
            duty.confirmationStatus === "incident_reported" ||
            duty.confirmationStatus === "replaced"
            ? duty.confirmationStatus
            : "pending";
        const incidentOpen = duty.incidentOpen === true;
        const derived = applyDerivedDutyState({
          status: nextStatusRaw,
          confirmationStatus,
          incidentOpen,
        });
        nextStatus = nextStatusRaw;

        tx.update(dutyRef, {
          status: nextStatusRaw,
          confidenceLevel: derived.confidenceLevel,
          publicStatusLabel: derived.publicStatusLabel,
          lastStatusChangedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: uid,
        });
      });

      const savedSnap = await dutyRef.get();
      const saved = savedSnap.data() as PharmacyDutyDoc | undefined;

      logStructured("pharmacy_duty_status_changed", {
        dutyId,
        actorUserId: uid,
        actorMerchantId: merchantId,
        nextStatus,
        correlationId,
      });
      logDutyMutationEvent({
        action,
        result: "success",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
      });

      return {
        dutyId,
        merchantId,
        status: saved ? normalizeDutyStatus(saved.status) : nextStatus,
        updatedAtMillis: saved?.updatedAt?.toMillis() ?? Date.now(),
      };
    } catch (error) {
      logDutyMutationEvent({
        action,
        result: "error",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
        conflictReason: resolveConflictReason(error),
        errorCode: error instanceof HttpsError ? error.code : "internal",
      });
      throw error;
    }
  }
);

export const confirmPharmacyDuty = onCall<
  ConfirmPharmacyDutyRequest,
  Promise<ConfirmPharmacyDutyResponse>
>(
  { enforceAppCheck: true },
  async (request) => {
    const action = "confirm_duty";
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }
    const dutyId = (request.data.dutyId ?? "").trim();
    if (dutyId.length === 0) {
      throw new HttpsError("invalid-argument", "dutyId es requerido.");
    }

    const correlationId = resolveCorrelationId(request);
    const uid = request.auth.uid;
    const role = resolveActorRole(request.auth.token.role);
    const claimMerchantId = parseClaimMerchantId(request.auth.token.merchantId);
    assertMutableRole(role);

    const dutyRef = db().doc(`pharmacy_duties/${dutyId}`);
    let merchantId = "";
    let status: DutyStatus = "scheduled";
    let confirmationStatus: DutyConfirmationStatus = "confirmed";

    try {
      await db().runTransaction(async (tx) => {
        const dutySnap = await tx.get(dutyRef);
        if (!dutySnap.exists) {
          throw new HttpsError("not-found", "Turno no encontrado.");
        }
        const duty = dutySnap.data() as PharmacyDutyDoc;
        merchantId = duty.merchantId;
        await assertMutationRateLimit({
          tx,
          action,
          uid,
          merchantId: duty.merchantId,
        });

        await assertOwnerControlsMerchant(
          duty.merchantId,
          uid,
          role,
          claimMerchantId,
          tx
        );

        const currentStatus = normalizeDutyStatus(duty.status);
        if (currentStatus === "cancelled") {
          throw new HttpsError(
            "failed-precondition",
            "No podés confirmar una guardia cancelada."
          );
        }
        if (duty.incidentOpen === true) {
          throw new HttpsError(
            "failed-precondition",
            "No podés confirmar una guardia con incidente operativo abierto."
          );
        }

        const now = new Date();
        const startsAt = toDutyDate(duty.startsAt);
        const endsAt = toDutyDate(duty.endsAt);
        const shouldBeActive = startsAt && endsAt
          ? now >= startsAt && now <= endsAt
          : false;

        status = shouldBeActive
          ? "active"
          : currentStatus === "reassigned"
          ? "reassigned"
          : "scheduled";
        confirmationStatus = currentStatus === "reassigned"
          ? "replaced"
          : "confirmed";
        const derived = applyDerivedDutyState({
          status,
          confirmationStatus,
          incidentOpen: false,
        });

        tx.update(dutyRef, {
          status,
          confirmationStatus,
          confirmedAt: FieldValue.serverTimestamp(),
          confirmedByUserId: uid,
          confidenceLevel: derived.confidenceLevel,
          publicStatusLabel: derived.publicStatusLabel,
          lastStatusChangedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: uid,
        });
      });

      const savedSnap = await dutyRef.get();
      const saved = savedSnap.data() as PharmacyDutyDoc | undefined;

      logStructured("pharmacy_duty_confirmed", {
        dutyId,
        actorUserId: uid,
        actorMerchantId: merchantId,
        previousStatus: saved ? normalizeDutyStatus(saved.status) : "scheduled",
        nextStatus: status,
        correlationId,
      });
      logDutyMutationEvent({
        action,
        result: "success",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
      });

      return {
        dutyId,
        merchantId,
        status,
        confirmationStatus,
        confirmedAtMillis: saved?.confirmedAt?.toMillis() ?? Date.now(),
      };
    } catch (error) {
      logDutyMutationEvent({
        action,
        result: "error",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
        conflictReason: resolveConflictReason(error),
        errorCode: error instanceof HttpsError ? error.code : "internal",
      });
      throw error;
    }
  }
);

export const reportPharmacyDutyIncident = onCall<
  ReportPharmacyDutyIncidentRequest,
  Promise<ReportPharmacyDutyIncidentResponse>
>(
  { enforceAppCheck: true },
  async (request) => {
    const action = "report_incident";
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }

    const dutyId = (request.data.dutyId ?? "").trim();
    if (dutyId.length === 0) {
      throw new HttpsError("invalid-argument", "dutyId es requerido.");
    }
    const incidentType = parseIncidentType(request.data.incidentType);
    const note = normalizeNote(request.data.note);
    const correlationId = resolveCorrelationId(request);
    const uid = request.auth.uid;
    const role = resolveActorRole(request.auth.token.role);
    const claimMerchantId = parseClaimMerchantId(request.auth.token.merchantId);
    assertMutableRole(role);

    const dutyRef = db().doc(`pharmacy_duties/${dutyId}`);
    const incidentRef = db().collection("pharmacy_duty_incidents").doc();
    let merchantId = "";
    let incidentId = incidentRef.id;

    try {
      await db().runTransaction(async (tx) => {
        const dutySnap = await tx.get(dutyRef);
        if (!dutySnap.exists) {
          throw new HttpsError("not-found", "Turno no encontrado.");
        }

        const duty = dutySnap.data() as PharmacyDutyDoc;
        merchantId = duty.merchantId;
        await assertMutationRateLimit({
          tx,
          action,
          uid,
          merchantId: duty.merchantId,
        });
        await assertOwnerControlsMerchant(
          duty.merchantId,
          uid,
          role,
          claimMerchantId,
          tx
        );

        if (duty.incidentOpen === true && duty.incidentId) {
          const openIncidentRef = db().doc(
            `pharmacy_duty_incidents/${duty.incidentId}`
          );
          const openIncidentSnap = await tx.get(openIncidentRef);
          if (openIncidentSnap.exists) {
            const openIncident = openIncidentSnap.data() as PharmacyDutyIncidentDoc;
            if (openIncident.status === "open") {
              incidentId = openIncidentSnap.id;
              return;
            }
          }
        }

        const derived = applyDerivedDutyState({
          status: "incident_reported",
          confirmationStatus: "incident_reported",
          incidentOpen: true,
        });

        tx.set(incidentRef, {
          dutyId,
          merchantId: duty.merchantId,
          zoneId: duty.zoneId,
          incidentType,
          note,
          status: "open",
          createdByUserId: uid,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        tx.update(dutyRef, {
          originMerchantId: duty.originMerchantId ?? duty.merchantId,
          status: "incident_reported",
          confirmationStatus: "incident_reported",
          incidentOpen: true,
          incidentId: incidentRef.id,
          replacementRoundOpen: false,
          confidenceLevel: derived.confidenceLevel,
          publicStatusLabel: derived.publicStatusLabel,
          lastStatusChangedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: uid,
        });
        incidentId = incidentRef.id;
      });

      logStructured("pharmacy_duty_incident_reported", {
        dutyId,
        incidentId,
        actorUserId: uid,
        actorMerchantId: merchantId,
        nextStatus: "incident_reported",
        correlationId,
      });
      logDutyMutationEvent({
        action,
        result: "success",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
      });

      return {
        dutyId,
        incidentId,
        status: "incident_reported",
        confirmationStatus: "incident_reported",
      };
    } catch (error) {
      logDutyMutationEvent({
        action,
        result: "error",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
        conflictReason: resolveConflictReason(error),
        errorCode: error instanceof HttpsError ? error.code : "internal",
      });
      throw error;
    }
  }
);

export const getEligibleReplacementCandidates = onCall<
  GetEligibleReplacementCandidatesRequest,
  Promise<GetEligibleReplacementCandidatesResponse>
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

    const correlationId = resolveCorrelationId(request);
    const uid = request.auth.uid;
    const role = resolveActorRole(request.auth.token.role);
    const claimMerchantId = parseClaimMerchantId(request.auth.token.merchantId);
    assertMutableRole(role);

    const [dutySnap, config] = await Promise.all([
      db().doc(`pharmacy_duties/${dutyId}`).get(),
      getPharmacyDutyRulesConfig(),
    ]);
    if (!dutySnap.exists) {
      throw new HttpsError("not-found", "Turno no encontrado.");
    }
    const duty = dutySnap.data() as PharmacyDutyDoc;
    const dutyStatus = normalizeDutyStatus(duty.status);
    if (dutyStatus === "cancelled") {
      throw new HttpsError(
        "failed-precondition",
        "No hay candidatas para un turno cancelado."
      );
    }

    const originMerchantId = duty.originMerchantId ?? duty.merchantId;
    const originContext = await assertMerchantAccessAndGetContext(
      originMerchantId,
      uid,
      role,
      claimMerchantId
    );
    if (!originContext.location) {
      throw new HttpsError(
        "failed-precondition",
        "La farmacia origen no tiene coordenadas configuradas."
      );
    }

    const seedLimit = Math.min(
      Math.max(config.maxCandidatesPerRound * 8, 20),
      80
    );
    // Query acotada por zoneId/categoryId/status + limit para costo controlado.
    const candidatesSnap = await db()
      .collection("merchants")
      .where("zoneId", "==", duty.zoneId)
      .where("categoryId", "==", "pharmacy")
      .where("status", "==", "active")
      .limit(seedLimit)
      .get();

    const candidates: ReplacementCandidate[] = [];
    for (const candidateDoc of candidatesSnap.docs) {
      if (candidateDoc.id === originMerchantId) continue;
      const candidateData = candidateDoc.data();
      const candidate: MerchantContext = {
        merchantId: candidateDoc.id,
        ownerUserId: extractString(candidateData, "ownerUserId"),
        zoneId: extractString(candidateData, "zoneId"),
        categoryId: extractString(candidateData, "categoryId"),
        status: extractString(candidateData, "status"),
        name: extractString(candidateData, "name") || candidateDoc.id,
        location: extractMerchantLocation(candidateData),
      };
      if (!candidate.location) continue;

      try {
        assertCandidateEligible(candidate, duty.zoneId);
      } catch {
        continue;
      }

      const rawDistance = haversineDistanceKm(
        originContext.location.lat,
        originContext.location.lng,
        candidate.location.lat,
        candidate.location.lng
      );
      const distanceKm = roundDistance(rawDistance);
      if (distanceKm > config.maxReassignmentDistanceKm) continue;

      candidates.push({
        merchantId: candidate.merchantId,
        merchantName: candidate.name,
        zoneId: candidate.zoneId,
        distanceKm,
        distanceBucket: distanceBucket(distanceKm),
      });
    }

    candidates.sort((a, b) => a.distanceKm - b.distanceKm);
    const boundedCandidates = candidates.slice(0, config.maxCandidatesPerRound);

    logStructured("pharmacy_duty_reassignment_candidates_loaded", {
      dutyId,
      actorUserId: uid,
      actorMerchantId: originMerchantId,
      zoneId: duty.zoneId,
      candidateCount: boundedCandidates.length,
      correlationId,
    });

    return {
      dutyId,
      originMerchantId,
      maxDistanceKmApplied: config.maxReassignmentDistanceKm,
      maxCandidatesPerRound: config.maxCandidatesPerRound,
      candidates: boundedCandidates,
    };
  }
);

export const createReassignmentRound = onCall<
  CreateReassignmentRoundRequest,
  Promise<CreateReassignmentRoundResponse>
>(
  { enforceAppCheck: true },
  async (request) => {
    const action = "create_reassignment_round";
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }
    const dutyId = (request.data.dutyId ?? "").trim();
    if (dutyId.length === 0) {
      throw new HttpsError("invalid-argument", "dutyId es requerido.");
    }
    const candidateMerchantIds = parseCandidateMerchantIds(
      request.data.candidateMerchantIds
    );
    if (candidateMerchantIds.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "Debés seleccionar al menos una candidata."
      );
    }

    const correlationId = resolveCorrelationId(request);
    const uid = request.auth.uid;
    const role = resolveActorRole(request.auth.token.role);
    const claimMerchantId = parseClaimMerchantId(request.auth.token.merchantId);
    assertMutableRole(role);
    const config = await getPharmacyDutyRulesConfig();

    if (
      !config.allowParallelRequests &&
      candidateMerchantIds.length > 1
    ) {
      throw new HttpsError(
        "failed-precondition",
        "La configuración actual no permite invitaciones paralelas."
      );
    }
    if (candidateMerchantIds.length > config.maxCandidatesPerRound) {
      throw new HttpsError(
        "failed-precondition",
        `Solo podés invitar hasta ${config.maxCandidatesPerRound} candidatas por ronda.`
      );
    }

    const dutyRef = db().doc(`pharmacy_duties/${dutyId}`);
    const roundRef = db().collection("pharmacy_duty_reassignment_rounds").doc();
    const expiresAtMillis = Date.now() + config.requestExpiryMinutes * 60_000;
    const expiresAt = Timestamp.fromMillis(expiresAtMillis);
    let incidentId = "";
    let requestCount = 0;
    let merchantId = "";

    try {
      await db().runTransaction(async (tx) => {
        const dutySnap = await tx.get(dutyRef);
        if (!dutySnap.exists) {
          throw new HttpsError("not-found", "Turno no encontrado.");
        }
        const duty = dutySnap.data() as PharmacyDutyDoc;
        const originMerchantId = duty.originMerchantId ?? duty.merchantId;
        merchantId = originMerchantId;
        await assertMutationRateLimit({
          tx,
          action,
          uid,
          merchantId: originMerchantId,
        });
        await assertOwnerControlsMerchant(
          originMerchantId,
          uid,
          role,
          claimMerchantId,
          tx
        );

        if (duty.incidentOpen !== true || !duty.incidentId) {
          throw new HttpsError(
            "failed-precondition",
            "Debés reportar un incidente operativo antes de iniciar cobertura."
          );
        }
        incidentId = duty.incidentId;

        if (config.preventMultipleOpenRoundsPerDuty || duty.replacementRoundOpen) {
          const openRoundSnap = await tx.get(
            db()
              .collection("pharmacy_duty_reassignment_rounds")
              .where("dutyId", "==", dutyId)
              .where("status", "==", "open")
              .limit(1)
          );
          if (!openRoundSnap.empty) {
            throw new HttpsError(
              "failed-precondition",
              "Ya existe una ronda de cobertura abierta para este turno."
            );
          }
        }

        const incidentRef = db().doc(`pharmacy_duty_incidents/${duty.incidentId}`);
        const incidentSnap = await tx.get(incidentRef);
        if (!incidentSnap.exists) {
          throw new HttpsError("not-found", "Incidente no encontrado.");
        }
        const incident = incidentSnap.data() as PharmacyDutyIncidentDoc;
        if (incident.status !== "open") {
          throw new HttpsError(
            "failed-precondition",
            "El incidente no está abierto."
          );
        }

        const originContext = await assertMerchantAccessAndGetContext(
          originMerchantId,
          uid,
          role,
          claimMerchantId,
          tx
        );
        if (!originContext.location) {
          throw new HttpsError(
            "failed-precondition",
            "La farmacia origen no tiene coordenadas configuradas."
          );
        }

        const candidateDocs = await Promise.all(
          // Leemos únicamente candidatas explícitamente seleccionadas por owner.
          candidateMerchantIds.map((merchantId) =>
            tx.get(db().doc(`merchants/${merchantId}`))
          )
        );

        const validCandidates: Array<{
          merchantId: string;
          distanceKm: number;
        }> = [];
        for (const candidateSnap of candidateDocs) {
          if (!candidateSnap.exists) {
            throw new HttpsError(
              "failed-precondition",
              "Una candidata seleccionada no existe."
            );
          }
          const candidateData = candidateSnap.data() ?? {};
          const candidate: MerchantContext = {
            merchantId: candidateSnap.id,
            ownerUserId: extractString(candidateData, "ownerUserId"),
            zoneId: extractString(candidateData, "zoneId"),
            categoryId: extractString(candidateData, "categoryId"),
            status: extractString(candidateData, "status"),
            name: extractString(candidateData, "name") || candidateSnap.id,
            location: extractMerchantLocation(candidateData),
          };
          if (candidate.merchantId === originMerchantId) {
            throw new HttpsError(
              "failed-precondition",
              "No podés auto-invitarte como cobertura."
            );
          }
          assertCandidateEligible(candidate, duty.zoneId);

          const distanceKm = roundDistance(
            haversineDistanceKm(
              originContext.location.lat,
              originContext.location.lng,
              candidate.location!.lat,
              candidate.location!.lng
            )
          );
          if (distanceKm > config.maxReassignmentDistanceKm) {
            throw new HttpsError(
              "failed-precondition",
              "Una candidata quedó fuera del radio máximo permitido."
            );
          }
          validCandidates.push({
            merchantId: candidate.merchantId,
            distanceKm,
          });
        }

        if (validCandidates.length === 0) {
          throw new HttpsError(
            "failed-precondition",
            "No hay candidatas elegibles para esta ronda."
          );
        }

        tx.set(roundRef, {
          dutyId,
          incidentId: duty.incidentId,
          originMerchantId,
          zoneId: duty.zoneId,
          status: "open",
          maxDistanceKmApplied: config.maxReassignmentDistanceKm,
          candidateCount: validCandidates.length,
          expiresAt,
          createdByUserId: uid,
          createdAt: FieldValue.serverTimestamp(),
          lastEventAt: FieldValue.serverTimestamp(),
        });

        for (const candidate of validCandidates) {
          const requestRef = db()
            .collection("pharmacy_duty_reassignment_requests")
            .doc();
          tx.set(requestRef, {
            roundId: roundRef.id,
            dutyId,
            incidentId: duty.incidentId,
            originMerchantId,
            candidateMerchantId: candidate.merchantId,
            zoneId: duty.zoneId,
            distanceKm: candidate.distanceKm,
            status: "pending",
            sentAt: FieldValue.serverTimestamp(),
            expiresAt,
            createdByUserId: uid,
            lastEventAt: FieldValue.serverTimestamp(),
          });
        }

        const derived = applyDerivedDutyState({
          status: "replacement_pending",
          confirmationStatus: "incident_reported",
          incidentOpen: true,
        });
        tx.update(dutyRef, {
          status: "replacement_pending",
          confirmationStatus: "incident_reported",
          replacementRoundOpen: true,
          confidenceLevel: derived.confidenceLevel,
          publicStatusLabel: derived.publicStatusLabel,
          lastStatusChangedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: uid,
        });

        requestCount = validCandidates.length;
      });

      logStructured("pharmacy_duty_reassignment_round_created", {
        dutyId,
        incidentId,
        roundId: roundRef.id,
        actorUserId: uid,
        candidateCount: requestCount,
        correlationId,
      });
      logDutyMutationEvent({
        action,
        result: "success",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
        roundId: roundRef.id,
      });

      return {
        dutyId,
        incidentId,
        roundId: roundRef.id,
        requestCount,
        expiresAtMillis,
      };
    } catch (error) {
      logDutyMutationEvent({
        action,
        result: "error",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
        roundId: roundRef.id,
        conflictReason: resolveConflictReason(error),
        errorCode: error instanceof HttpsError ? error.code : "internal",
      });
      throw error;
    }
  }
);

export const respondToReassignmentRequest = onCall<
  RespondToReassignmentRequestRequest,
  Promise<RespondToReassignmentRequestResponse>
>(
  { enforceAppCheck: true },
  async (request) => {
    const actionName = "respond_reassignment_request";
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }
    const requestId = (request.data.requestId ?? "").trim();
    if (requestId.length === 0) {
      throw new HttpsError("invalid-argument", "requestId es requerido.");
    }
    const action = parseRequestAction(request.data.action);
    const uid = request.auth.uid;
    const role = resolveActorRole(request.auth.token.role);
    const claimMerchantId = parseClaimMerchantId(request.auth.token.merchantId);
    assertMutableRole(role);
    const correlationId = resolveCorrelationId(request);

    const requestRef = db().doc(`pharmacy_duty_reassignment_requests/${requestId}`);
    let dutyId = "";
    let roundId = "";
    let merchantId = "";
    let requestStatus: RequestStatus = "pending";
    let roundStatus: ReassignmentRoundDoc["status"] = "open";
    let dutyStatus: DutyStatus = "scheduled";

    try {
      await db().runTransaction(async (tx) => {
        const reassignmentRequestSnap = await tx.get(requestRef);
        if (!reassignmentRequestSnap.exists) {
          throw new HttpsError("not-found", "Invitación no encontrada.");
        }
        const reassignmentRequest = reassignmentRequestSnap.data() as ReassignmentRequestDoc;
        dutyId = reassignmentRequest.dutyId;
        roundId = reassignmentRequest.roundId;
        merchantId = reassignmentRequest.candidateMerchantId;
        requestStatus = reassignmentRequest.status;
        await assertMutationRateLimit({
          tx,
          action: actionName,
          uid,
          merchantId: reassignmentRequest.candidateMerchantId,
        });

        await assertOwnerControlsMerchant(
          reassignmentRequest.candidateMerchantId,
          uid,
          role,
          claimMerchantId,
          tx
        );

      const roundRef = db().doc(
        `pharmacy_duty_reassignment_rounds/${reassignmentRequest.roundId}`
      );
      const dutyRef = db().doc(`pharmacy_duties/${reassignmentRequest.dutyId}`);
      const incidentRef = db().doc(
        `pharmacy_duty_incidents/${reassignmentRequest.incidentId}`
      );

      const [roundSnap, dutySnap, pendingRequestsSnap, incidentSnap] = await Promise.all([
        tx.get(roundRef),
        tx.get(dutyRef),
        tx.get(
          db()
            .collection("pharmacy_duty_reassignment_requests")
            .where("roundId", "==", reassignmentRequest.roundId)
            .where("status", "==", "pending")
        ),
        tx.get(incidentRef),
      ]);

      if (!roundSnap.exists || !dutySnap.exists) {
        throw new HttpsError(
          "failed-precondition",
          "La ronda o el turno ya no están disponibles."
        );
      }

      const round = roundSnap.data() as ReassignmentRoundDoc;
      const duty = dutySnap.data() as PharmacyDutyDoc;
      roundStatus = round.status;
      dutyStatus = normalizeDutyStatus(duty.status);

      if (action === "reject") {
        if (reassignmentRequest.status !== "pending") {
          requestStatus = reassignmentRequest.status;
          return;
        }

        const remainingPending = pendingRequestsSnap.docs.filter((doc) => doc.id !== requestId);
        tx.update(requestRef, {
          status: "rejected",
          respondedAt: FieldValue.serverTimestamp(),
          responseByUserId: uid,
          responseReason: "rejected",
          lastEventAt: FieldValue.serverTimestamp(),
        });
        requestStatus = "rejected";

        if (round.status === "open" && remainingPending.length === 0) {
          roundStatus = "expired";
          dutyStatus = "incident_reported";
          tx.update(roundRef, {
            status: "expired",
            closedAt: FieldValue.serverTimestamp(),
            lastEventAt: FieldValue.serverTimestamp(),
          });
          const derived = applyDerivedDutyState({
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
            updatedBy: uid,
          });
        }
        return;
      }

      if (reassignmentRequest.status === "accepted") {
        requestStatus = "accepted";
        roundStatus = round.status;
        dutyStatus = normalizeDutyStatus(duty.status);
        return;
      }
      if (reassignmentRequest.status !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "La invitación ya no está pendiente."
        );
      }
      if (round.status !== "open") {
        throw new HttpsError(
          "failed-precondition",
          "La ronda de cobertura ya no está abierta."
        );
      }
      const nowMillis = Timestamp.now().toMillis();
      if (reassignmentRequest.expiresAt.toMillis() <= nowMillis) {
        throw new HttpsError(
          "failed-precondition",
          "La invitación de cobertura ya expiró."
        );
      }
      if (round.expiresAt.toMillis() <= nowMillis) {
        throw new HttpsError(
          "failed-precondition",
          "La ronda de cobertura ya expiró."
        );
      }
      if (normalizeDutyStatus(duty.status) === "reassigned") {
        throw new HttpsError(
          "failed-precondition",
          "El turno ya fue reasignado."
        );
      }

      tx.update(requestRef, {
        status: "accepted",
        respondedAt: FieldValue.serverTimestamp(),
        responseByUserId: uid,
        responseReason: "accepted",
        lastEventAt: FieldValue.serverTimestamp(),
      });

      for (const pending of pendingRequestsSnap.docs) {
        if (pending.id === requestId) continue;
        // Primera aceptación válida gana; el resto se cancela en la misma tx.
        tx.update(pending.ref, {
          status: "cancelled",
          respondedAt: FieldValue.serverTimestamp(),
          responseReason: "cancelled_due_to_other_acceptance",
          lastEventAt: FieldValue.serverTimestamp(),
        });
      }

      tx.update(roundRef, {
        status: "covered",
        acceptedRequestId: requestId,
        acceptedMerchantId: reassignmentRequest.candidateMerchantId,
        closedAt: FieldValue.serverTimestamp(),
        lastEventAt: FieldValue.serverTimestamp(),
      });

      const derived = applyDerivedDutyState({
        status: "reassigned",
        confirmationStatus: "replaced",
        incidentOpen: false,
      });
      tx.update(dutyRef, {
        originMerchantId: duty.originMerchantId ?? duty.merchantId,
        merchantId: reassignmentRequest.candidateMerchantId,
        replacementMerchantId: reassignmentRequest.candidateMerchantId,
        replacementAcceptedAt: FieldValue.serverTimestamp(),
        status: "reassigned",
        confirmationStatus: "replaced",
        sourceType: "system_reassigned",
        incidentOpen: false,
        replacementRoundOpen: false,
        confidenceLevel: derived.confidenceLevel,
        publicStatusLabel: derived.publicStatusLabel,
        lastStatusChangedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: uid,
      });

      if (incidentSnap.exists) {
        const incident = incidentSnap.data() as PharmacyDutyIncidentDoc;
        if (incident.status === "open") {
          tx.update(incidentRef, {
            status: "covered",
            resolvedAt: FieldValue.serverTimestamp(),
            resolvedByUserId: uid,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }

        requestStatus = "accepted";
        roundStatus = "covered";
        dutyStatus = "reassigned";
      });

      logStructured("pharmacy_duty_reassignment_request_responded", {
        requestId,
        dutyId,
        roundId,
        actorUserId: uid,
        nextStatus: requestStatus,
        correlationId,
      });
      logDutyMutationEvent({
        action: actionName,
        result: "success",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
        roundId,
        requestId,
      });

      return {
        requestId,
        dutyId,
        roundId,
        requestStatus,
        roundStatus,
        dutyStatus,
      };
    } catch (error) {
      logDutyMutationEvent({
        action: actionName,
        result: "error",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
        roundId,
        requestId,
        conflictReason: resolveConflictReason(error),
        errorCode: error instanceof HttpsError ? error.code : "internal",
      });
      throw error;
    }
  }
);

export const cancelReassignmentRound = onCall<
  CancelReassignmentRoundRequest,
  Promise<CancelReassignmentRoundResponse>
>(
  { enforceAppCheck: true },
  async (request) => {
    const action = "cancel_reassignment_round";
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }

    const roundId = (request.data.roundId ?? "").trim();
    if (roundId.length === 0) {
      throw new HttpsError("invalid-argument", "roundId es requerido.");
    }

    const correlationId = resolveCorrelationId(request);
    const uid = request.auth.uid;
    const role = resolveActorRole(request.auth.token.role);
    const claimMerchantId = parseClaimMerchantId(request.auth.token.merchantId);
    assertMutableRole(role);

    const roundRef = db().doc(`pharmacy_duty_reassignment_rounds/${roundId}`);
    let dutyId = "";
    let merchantId = "";
    let roundStatus: ReassignmentRoundDoc["status"] = "cancelled";

    try {
      await db().runTransaction(async (tx) => {
        const roundSnap = await tx.get(roundRef);
        if (!roundSnap.exists) {
          throw new HttpsError("not-found", "Ronda no encontrada.");
        }
        const round = roundSnap.data() as ReassignmentRoundDoc;
        roundStatus = round.status;
        dutyId = round.dutyId;
        merchantId = round.originMerchantId;
        await assertMutationRateLimit({
          tx,
          action,
          uid,
          merchantId: round.originMerchantId,
        });

        const dutyRef = db().doc(`pharmacy_duties/${round.dutyId}`);
        const [dutySnap, pendingRequestsSnap] = await Promise.all([
          tx.get(dutyRef),
          tx.get(
            db()
              .collection("pharmacy_duty_reassignment_requests")
              .where("roundId", "==", roundId)
              .where("status", "==", "pending")
          ),
        ]);
        if (!dutySnap.exists) {
          throw new HttpsError("not-found", "Turno no encontrado.");
        }

        await assertOwnerControlsMerchant(
          round.originMerchantId,
          uid,
          role,
          claimMerchantId,
          tx
        );

        if (round.status !== "open") {
          return;
        }

        for (const pending of pendingRequestsSnap.docs) {
          tx.update(pending.ref, {
            status: "cancelled",
            respondedAt: FieldValue.serverTimestamp(),
            responseReason: "cancelled_due_to_other_acceptance",
            lastEventAt: FieldValue.serverTimestamp(),
          });
        }

        tx.update(roundRef, {
          status: "cancelled",
          closedAt: FieldValue.serverTimestamp(),
          lastEventAt: FieldValue.serverTimestamp(),
        });

        const duty = dutySnap.data() as PharmacyDutyDoc;
        const nextDutyStatus: DutyStatus = duty.incidentOpen === true
          ? "incident_reported"
          : "scheduled";
        const nextConfirmationStatus: DutyConfirmationStatus = duty.incidentOpen === true
          ? "incident_reported"
          : "pending";
        const derived = applyDerivedDutyState({
          status: nextDutyStatus,
          confirmationStatus: nextConfirmationStatus,
          incidentOpen: duty.incidentOpen === true,
        });

        tx.update(dutyRef, {
          status: nextDutyStatus,
          confirmationStatus: nextConfirmationStatus,
          replacementRoundOpen: false,
          confidenceLevel: derived.confidenceLevel,
          publicStatusLabel: derived.publicStatusLabel,
          lastStatusChangedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: uid,
        });
        roundStatus = "cancelled";
      });

      logStructured("pharmacy_duty_reassignment_round_cancelled", {
        roundId,
        dutyId,
        actorUserId: uid,
        nextStatus: roundStatus,
        correlationId,
      });
      logDutyMutationEvent({
        action,
        result: "success",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
        roundId,
      });

      return {
        roundId,
        dutyId,
        roundStatus,
      };
    } catch (error) {
      logDutyMutationEvent({
        action,
        result: "error",
        actorUserId: uid,
        correlationId,
        merchantId,
        dutyId,
        roundId,
        conflictReason: resolveConflictReason(error),
        errorCode: error instanceof HttpsError ? error.code : "internal",
      });
      throw error;
    }
  }
);
