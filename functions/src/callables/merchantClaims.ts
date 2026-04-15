import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

const db = () => getFirestore();

type ClaimStatus =
  | "draft"
  | "submitted"
  | "auto_validating"
  | "under_review"
  | "needs_more_info"
  | "approved"
  | "rejected"
  | "duplicate_claim"
  | "conflict_detected"
  | "cancelled";

type DeclaredRole = "owner" | "co_owner" | "authorized_representative";
type EvidenceKind = "storefront_photo" | "ownership_document";

interface ClaimEvidenceInput {
  id?: unknown;
  kind?: unknown;
  storagePath?: unknown;
  contentType?: unknown;
  sizeBytes?: unknown;
  originalFileName?: unknown;
}

interface ClaimEvidenceStored {
  id: string;
  kind: EvidenceKind;
  storagePath: string;
  contentType: string;
  sizeBytes: number;
  uploadedAt: Timestamp;
  originalFileName?: string | null;
}

interface UpsertMerchantClaimDraftRequest {
  claimId?: unknown;
  merchantId?: unknown;
  declaredRole?: unknown;
  phone?: unknown;
  claimantDisplayName?: unknown;
  claimantNote?: unknown;
  hasAcceptedDataProcessingConsent?: unknown;
  hasAcceptedLegitimacyDeclaration?: unknown;
  evidenceFiles?: unknown;
}

interface UpsertMerchantClaimDraftResponse {
  claimId: string;
  claimStatus: ClaimStatus;
  merchantId: string;
  updatedAtMillis: number | null;
}

interface SubmitMerchantClaimRequest {
  claimId?: unknown;
}

interface SubmitMerchantClaimResponse {
  claimId: string;
  claimStatus: ClaimStatus;
  submittedAtMillis: number | null;
  nextAction: "wait_review" | "resolve_conflict" | "provide_more_info";
}

interface CancelMerchantClaimRequest {
  claimId?: unknown;
  reason?: unknown;
}

interface CancelMerchantClaimResponse {
  claimId: string;
  claimStatus: "cancelled";
  cancelledAtMillis: number | null;
}

interface GetMyMerchantClaimStatusRequest {
  claimId?: unknown;
}

interface GetMyMerchantClaimStatusResponse {
  claim: {
    claimId: string;
    claimStatus: ClaimStatus;
    merchantId: string;
    merchantName: string | null;
    updatedAtMillis: number | null;
    submittedAtMillis: number | null;
    needsMoreInfo: boolean;
    conflictDetected: boolean;
    duplicateDetected: boolean;
  } | null;
}

interface SearchClaimableMerchantsRequest {
  zoneId?: unknown;
  query?: unknown;
  limit?: unknown;
}

interface SearchClaimableMerchantsResponse {
  zoneId: string;
  query: string;
  merchants: Array<{
    merchantId: string;
    name: string;
    address: string | null;
    categoryId: string;
    zoneId: string;
    ownershipStatus: string;
    hasOwner: boolean;
  }>;
}

type CallableAuth = {
  uid: string;
  token: Record<string, unknown>;
};

const DRAFT_MUTABLE_STATUSES: ReadonlySet<ClaimStatus> = new Set([
  "draft",
  "needs_more_info",
]);

const ACTIVE_STATUSES: ReadonlyArray<ClaimStatus> = [
  "draft",
  "submitted",
  "auto_validating",
  "under_review",
  "needs_more_info",
];

const CLAIM_STATUS_CONFLICT: ClaimStatus = "conflict_detected";
const CLAIM_STATUS_DUPLICATE: ClaimStatus = "duplicate_claim";

const MAX_NOTE_LENGTH = 800;
const MAX_PHONE_LENGTH = 32;
const MAX_EVIDENCE_FILES = 6;
const MAX_EVIDENCE_FILE_BYTES = 8 * 1024 * 1024;
const STORAGE_PATH_PREFIX = "merchant-claims/";
const MAX_CLAIMABLE_SEARCH_LIMIT = 20;

function assertAuthenticated(
  auth: CallableAuth | null | undefined
): CallableAuth {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Autenticación requerida.");
  }
  return auth;
}

function normalizeRequiredString(value: unknown, field: string): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} es requerido.`);
  }
  const normalized = value.trim();
  if (!normalized) {
    throw new HttpsError("invalid-argument", `${field} es requerido.`);
  }
  return normalized;
}

function normalizeOptionalString(
  value: unknown,
  field: string,
  maxLength: number
): string | null {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} inválido.`);
  }
  const normalized = value.trim();
  if (!normalized) return null;
  if (normalized.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} supera el máximo de ${maxLength} caracteres.`
    );
  }
  return normalized;
}

function normalizeClaimId(value: unknown): string {
  const claimId = normalizeRequiredString(value, "claimId");
  if (!/^[A-Za-z0-9_-]{10,40}$/.test(claimId)) {
    throw new HttpsError("invalid-argument", "claimId inválido.");
  }
  return claimId;
}

function normalizeDeclaredRole(value: unknown): DeclaredRole {
  if (value === "owner" || value === "co_owner" || value === "authorized_representative") {
    return value;
  }
  throw new HttpsError("invalid-argument", "declaredRole inválido.");
}

function normalizePhone(value: unknown): string | null {
  const normalized = normalizeOptionalString(value, "phone", MAX_PHONE_LENGTH);
  if (normalized == null) return null;
  const compact = normalized.replace(/\s+/g, "");
  if (!/^\+?[0-9()\-.\s]{6,32}$/.test(compact)) {
    throw new HttpsError("invalid-argument", "phone inválido.");
  }
  return normalized;
}

function normalizeEvidenceKind(value: unknown): EvidenceKind {
  if (value === "storefront_photo" || value === "ownership_document") {
    return value;
  }
  throw new HttpsError("invalid-argument", "kind de evidencia inválido.");
}

function normalizeEvidenceId(value: unknown): string {
  const id = normalizeRequiredString(value, "evidence.id");
  if (!/^[A-Za-z0-9_-]{4,80}$/.test(id)) {
    throw new HttpsError("invalid-argument", "evidence.id inválido.");
  }
  return id;
}

function normalizeEvidenceContentType(value: unknown): string {
  const contentType = normalizeRequiredString(value, "evidence.contentType").toLowerCase();
  const allowed = new Set([
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "application/pdf",
  ]);
  if (!allowed.has(contentType)) {
    throw new HttpsError("invalid-argument", "Tipo de archivo no permitido.");
  }
  return contentType;
}

function normalizeEvidenceSizeBytes(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", "evidence.sizeBytes inválido.");
  }
  const size = Math.trunc(value);
  if (size <= 0 || size > MAX_EVIDENCE_FILE_BYTES) {
    throw new HttpsError("invalid-argument", "Tamaño de evidencia inválido.");
  }
  return size;
}

function normalizeEvidenceStoragePath(
  value: unknown,
  uid: string,
  claimId: string
): string {
  const storagePath = normalizeRequiredString(value, "evidence.storagePath");
  const expectedPrefix = `${STORAGE_PATH_PREFIX}${uid}/${claimId}/`;
  if (!storagePath.startsWith(expectedPrefix)) {
    throw new HttpsError(
      "invalid-argument",
      "storagePath de evidencia fuera del path permitido."
    );
  }
  return storagePath;
}

function normalizeEvidenceFiles(
  raw: unknown,
  params: { uid: string; claimId: string }
): ClaimEvidenceStored[] {
  if (raw == null) return [];
  if (!Array.isArray(raw)) {
    throw new HttpsError("invalid-argument", "evidenceFiles debe ser un array.");
  }
  if (raw.length > MAX_EVIDENCE_FILES) {
    throw new HttpsError(
      "invalid-argument",
      `Máximo ${MAX_EVIDENCE_FILES} archivos de evidencia.`
    );
  }

  const now = Timestamp.now();
  const byId = new Map<string, ClaimEvidenceStored>();

  for (const item of raw) {
    const evidence = (item ?? {}) as ClaimEvidenceInput;
    const id = normalizeEvidenceId(evidence.id);
    const normalized: ClaimEvidenceStored = {
      id,
      kind: normalizeEvidenceKind(evidence.kind),
      storagePath: normalizeEvidenceStoragePath(
        evidence.storagePath,
        params.uid,
        params.claimId
      ),
      contentType: normalizeEvidenceContentType(evidence.contentType),
      sizeBytes: normalizeEvidenceSizeBytes(evidence.sizeBytes),
      uploadedAt: now,
      originalFileName: normalizeOptionalString(
        evidence.originalFileName,
        "evidence.originalFileName",
        180
      ),
    };
    byId.set(id, normalized);
  }

  return [...byId.values()];
}

function claimHasRequiredEvidence(evidenceFiles: ClaimEvidenceStored[]): {
  storefront: boolean;
  ownershipDocument: boolean;
} {
  let storefront = false;
  let ownershipDocument = false;
  for (const evidence of evidenceFiles) {
    if (evidence.kind === "storefront_photo") storefront = true;
    if (evidence.kind === "ownership_document") ownershipDocument = true;
  }
  return { storefront, ownershipDocument };
}

function readTimestampMillis(value: unknown): number | null {
  if (value instanceof Timestamp) return value.toMillis();
  return null;
}

function normalizeAuthEmail(token: Record<string, unknown>): string {
  const email = token.email;
  if (typeof email !== "string" || email.trim().length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Necesitás una cuenta con email para reclamar un comercio."
    );
  }
  return email.trim().toLowerCase();
}

function normalizeBoolean(value: unknown, field: string): boolean {
  if (typeof value !== "boolean") {
    throw new HttpsError("invalid-argument", `${field} es requerido.`);
  }
  return value;
}

function normalizeSearchLimit(value: unknown): number {
  if (value == null) return 12;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", "limit inválido.");
  }
  return Math.max(1, Math.min(MAX_CLAIMABLE_SEARCH_LIMIT, Math.trunc(value)));
}

function normalizeSearchQuery(value: unknown): string {
  if (value == null) return "";
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "query inválido.");
  }
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}

function toClaimStatus(raw: unknown): ClaimStatus {
  if (typeof raw !== "string") return "draft";
  const normalized = raw.trim() as ClaimStatus;
  const allowed: ReadonlySet<string> = new Set([
    "draft",
    "submitted",
    "auto_validating",
    "under_review",
    "needs_more_info",
    "approved",
    "rejected",
    "duplicate_claim",
    "conflict_detected",
    "cancelled",
  ]);
  if (allowed.has(normalized)) return normalized;
  return "draft";
}

function resolveMerchantName(data: Record<string, unknown>): string | null {
  const name = data.name;
  if (typeof name === "string" && name.trim().length > 0) {
    return name.trim();
  }
  return null;
}

function isTerminalStatus(status: ClaimStatus): boolean {
  return (
    status === "approved" ||
    status === "rejected" ||
    status === "duplicate_claim" ||
    status === "conflict_detected" ||
    status === "cancelled"
  );
}

export const upsertMerchantClaimDraft = onCall<
  UpsertMerchantClaimDraftRequest,
  Promise<UpsertMerchantClaimDraftResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth as CallableAuth);
  const uid = auth.uid;
  const authEmail = normalizeAuthEmail(auth.token);

  const merchantId = normalizeRequiredString(request.data.merchantId, "merchantId");
  const declaredRole = normalizeDeclaredRole(request.data.declaredRole);
  const phone = normalizePhone(request.data.phone);
  const claimantDisplayName = normalizeOptionalString(
    request.data.claimantDisplayName,
    "claimantDisplayName",
    120
  );
  const claimantNote = normalizeOptionalString(
    request.data.claimantNote,
    "claimantNote",
    MAX_NOTE_LENGTH
  );
  const hasAcceptedDataProcessingConsent = normalizeBoolean(
    request.data.hasAcceptedDataProcessingConsent,
    "hasAcceptedDataProcessingConsent"
  );
  const hasAcceptedLegitimacyDeclaration = normalizeBoolean(
    request.data.hasAcceptedLegitimacyDeclaration,
    "hasAcceptedLegitimacyDeclaration"
  );

  const merchantRef = db().collection("merchants").doc(merchantId);
  const merchantSnap = await merchantRef.get();
  if (!merchantSnap.exists) {
    throw new HttpsError("not-found", "No encontramos el comercio seleccionado.");
  }
  const merchantData = merchantSnap.data() ?? {};
  const categoryId = normalizeRequiredString(merchantData.categoryId, "merchant.categoryId");
  const zoneId = normalizeRequiredString(merchantData.zoneId, "merchant.zoneId");

  const claimId =
    request.data.claimId == null ? db().collection("merchant_claims").doc().id : normalizeClaimId(request.data.claimId);
  const evidenceFiles = normalizeEvidenceFiles(request.data.evidenceFiles, {
    uid,
    claimId,
  });
  const requiredEvidence = claimHasRequiredEvidence(evidenceFiles);

  const claimsCollection = db().collection("merchant_claims");
  const claimRef = claimsCollection.doc(claimId);
  const existingClaimSnap = await claimRef.get();

  if (existingClaimSnap.exists) {
    const existingData = existingClaimSnap.data() ?? {};
    if (existingData.userId !== uid) {
      throw new HttpsError("permission-denied", "No podés modificar este claim.");
    }
    const currentStatus = toClaimStatus(existingData.claimStatus);
    if (!DRAFT_MUTABLE_STATUSES.has(currentStatus)) {
      throw new HttpsError(
        "failed-precondition",
        "Este claim ya no se puede editar desde el flujo de borrador."
      );
    }
  } else {
    const activeSnap = await claimsCollection
      .where("userId", "==", uid)
      .where("merchantId", "==", merchantId)
      .where("claimStatus", "in", ACTIVE_STATUSES)
      .limit(1)
      .get();
    if (!activeSnap.empty) {
      const active = activeSnap.docs[0];
      throw new HttpsError(
        "already-exists",
        "Ya existe un claim activo para este comercio.",
        {
          code: "active_claim_exists",
          claimId: active.id,
          claimStatus: active.data().claimStatus ?? "draft",
        }
      );
    }
  }

  const now = FieldValue.serverTimestamp();
  const nextPayload: Record<string, unknown> = {
    claimId,
    merchantId,
    userId: uid,
    categoryId,
    zoneId,
    claimStatus: "draft",
    authenticatedEmail: authEmail,
    declaredRole,
    phone,
    claimantDisplayName,
    claimantNote,
    evidenceFiles,
    storefrontPhotoUploaded: requiredEvidence.storefront,
    ownershipDocumentUploaded: requiredEvidence.ownershipDocument,
    hasAcceptedDataProcessingConsent,
    hasAcceptedLegitimacyDeclaration,
    updatedAt: now,
    lastStatusAt: now,
  };

  if (!existingClaimSnap.exists) {
    nextPayload.createdAt = now;
  }

  await claimRef.set(nextPayload, { merge: true });
  const saved = await claimRef.get();
  const savedData = saved.data() ?? {};

  console.log(
    JSON.stringify({
      source: "merchant_claims",
      action: existingClaimSnap.exists ? "upsert_draft" : "create_draft",
      claimId,
      merchantId,
      uid,
      claimStatus: savedData.claimStatus ?? "draft",
      storefrontPhotoUploaded: requiredEvidence.storefront,
      ownershipDocumentUploaded: requiredEvidence.ownershipDocument,
    })
  );

  return {
    claimId,
    claimStatus: toClaimStatus(savedData.claimStatus),
    merchantId,
    updatedAtMillis: readTimestampMillis(savedData.updatedAt),
  };
});

export const submitMerchantClaim = onCall<
  SubmitMerchantClaimRequest,
  Promise<SubmitMerchantClaimResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth as CallableAuth);
  const uid = auth.uid;
  const claimId = normalizeClaimId(request.data.claimId);
  const authEmail = normalizeAuthEmail(auth.token);

  const claimRef = db().collection("merchant_claims").doc(claimId);
  const claimSnap = await claimRef.get();
  if (!claimSnap.exists) {
    throw new HttpsError("not-found", "No encontramos el claim.");
  }
  const claimData = claimSnap.data() ?? {};
  if (claimData.userId !== uid) {
    throw new HttpsError("permission-denied", "No podés enviar un claim ajeno.");
  }

  const currentStatus = toClaimStatus(claimData.claimStatus);
  if (!(currentStatus === "draft" || currentStatus === "needs_more_info")) {
    throw new HttpsError(
      "failed-precondition",
      "El claim no está en estado editable para envío."
    );
  }

  const evidenceFilesRaw = Array.isArray(claimData.evidenceFiles) ? claimData.evidenceFiles : [];
  const evidenceFiles = normalizeEvidenceFiles(evidenceFilesRaw, { uid, claimId });
  const requiredEvidence = claimHasRequiredEvidence(evidenceFiles);
  if (!requiredEvidence.storefront || !requiredEvidence.ownershipDocument) {
    throw new HttpsError(
      "failed-precondition",
      "Necesitás subir foto de fachada y prueba documental mínima para enviar el claim."
    );
  }

  if (claimData.hasAcceptedDataProcessingConsent !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Necesitás aceptar el tratamiento de datos para continuar."
    );
  }
  if (claimData.hasAcceptedLegitimacyDeclaration !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Necesitás aceptar la declaración de legitimidad para continuar."
    );
  }

  const merchantId = normalizeRequiredString(claimData.merchantId, "merchantId");
  const merchantRef = db().collection("merchants").doc(merchantId);
  const merchantSnap = await merchantRef.get();
  if (!merchantSnap.exists) {
    throw new HttpsError("failed-precondition", "El comercio ya no está disponible.");
  }
  const merchantData = merchantSnap.data() ?? {};

  const merchantOwnerUid =
    typeof merchantData.ownerUserId === "string" ? merchantData.ownerUserId.trim() : "";
  const ownershipStatus =
    typeof merchantData.ownershipStatus === "string"
      ? merchantData.ownershipStatus.trim().toLowerCase()
      : "";

  let nextStatus: ClaimStatus = "auto_validating";
  let nextAction: SubmitMerchantClaimResponse["nextAction"] = "wait_review";
  let conflictType: string | null = null;
  let duplicateOfClaimId: string | null = null;

  if ((merchantOwnerUid && merchantOwnerUid !== uid) || ownershipStatus === "claimed") {
    nextStatus = CLAIM_STATUS_CONFLICT;
    nextAction = "resolve_conflict";
    conflictType = "merchant_already_owned";
  } else {
    const duplicateSnap = await db()
      .collection("merchant_claims")
      .where("userId", "==", uid)
      .where("merchantId", "==", merchantId)
      .where("claimStatus", "in", ACTIVE_STATUSES)
      .limit(2)
      .get();
    const duplicate = duplicateSnap.docs.find((doc) => doc.id !== claimId);
    if (duplicate) {
      nextStatus = CLAIM_STATUS_DUPLICATE;
      nextAction = "resolve_conflict";
      duplicateOfClaimId = duplicate.id;
    }
  }

  const now = FieldValue.serverTimestamp();
  await claimRef.set(
    {
      authenticatedEmail: authEmail,
      evidenceFiles,
      storefrontPhotoUploaded: requiredEvidence.storefront,
      ownershipDocumentUploaded: requiredEvidence.ownershipDocument,
      claimStatus: nextStatus,
      submittedAt: now,
      updatedAt: now,
      lastStatusAt: now,
      autoValidationVersion: 1,
      autoValidationResult: nextStatus === "auto_validating" ? null : "blocked",
      autoValidationReasonCode: conflictType ?? (duplicateOfClaimId ? "duplicate_claim" : null),
      conflictType,
      duplicateOfClaimId,
    },
    { merge: true }
  );

  const updatedSnap = await claimRef.get();
  const updatedData = updatedSnap.data() ?? {};

  console.log(
    JSON.stringify({
      source: "merchant_claims",
      action: "submit_claim",
      claimId,
      merchantId,
      uid,
      nextStatus,
      conflictType,
      duplicateOfClaimId,
    })
  );

  return {
    claimId,
    claimStatus: toClaimStatus(updatedData.claimStatus),
    submittedAtMillis: readTimestampMillis(updatedData.submittedAt),
    nextAction,
  };
});

export const cancelMerchantClaim = onCall<
  CancelMerchantClaimRequest,
  Promise<CancelMerchantClaimResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth as CallableAuth);
  const uid = auth.uid;
  const claimId = normalizeClaimId(request.data.claimId);
  const reason = normalizeOptionalString(request.data.reason, "reason", 300);

  const claimRef = db().collection("merchant_claims").doc(claimId);
  const claimSnap = await claimRef.get();
  if (!claimSnap.exists) {
    throw new HttpsError("not-found", "No encontramos el claim.");
  }
  const claimData = claimSnap.data() ?? {};
  if (claimData.userId !== uid) {
    throw new HttpsError("permission-denied", "No podés cancelar un claim ajeno.");
  }
  const status = toClaimStatus(claimData.claimStatus);
  if (isTerminalStatus(status)) {
    throw new HttpsError(
      "failed-precondition",
      "El claim ya está cerrado y no puede cancelarse."
    );
  }

  const now = FieldValue.serverTimestamp();
  await claimRef.set(
    {
      claimStatus: "cancelled",
      cancelledAt: now,
      cancelledReason: reason,
      updatedAt: now,
      lastStatusAt: now,
    },
    { merge: true }
  );
  const updatedSnap = await claimRef.get();
  const updatedData = updatedSnap.data() ?? {};

  console.log(
    JSON.stringify({
      source: "merchant_claims",
      action: "cancel_claim",
      claimId,
      uid,
      reason: reason ?? null,
    })
  );

  return {
    claimId,
    claimStatus: "cancelled",
    cancelledAtMillis: readTimestampMillis(updatedData.cancelledAt),
  };
});

export const getMyMerchantClaimStatus = onCall<
  GetMyMerchantClaimStatusRequest,
  Promise<GetMyMerchantClaimStatusResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth as CallableAuth);
  const uid = auth.uid;
  const claimId =
    request.data.claimId == null ? null : normalizeClaimId(request.data.claimId);

  let claimSnap:
    | FirebaseFirestore.DocumentSnapshot<FirebaseFirestore.DocumentData>
    | null = null;

  if (claimId != null) {
    const ref = db().collection("merchant_claims").doc(claimId);
    const snap = await ref.get();
    if (snap.exists) {
      const data = snap.data() ?? {};
      if (data.userId !== uid) {
        throw new HttpsError("permission-denied", "No podés acceder a este claim.");
      }
      claimSnap = snap;
    }
  } else {
    const querySnap = await db()
      .collection("merchant_claims")
      .where("userId", "==", uid)
      .orderBy("updatedAt", "desc")
      .limit(1)
      .get();
    if (!querySnap.empty) {
      claimSnap = querySnap.docs[0];
    }
  }

  if (claimSnap == null || !claimSnap.exists) {
    return { claim: null };
  }

  const claimData = claimSnap.data() ?? {};
  const merchantId = normalizeRequiredString(claimData.merchantId, "merchantId");
  const merchantSnap = await db().collection("merchants").doc(merchantId).get();
  const merchantName = merchantSnap.exists
    ? resolveMerchantName(merchantSnap.data() ?? {})
    : null;

  const status = toClaimStatus(claimData.claimStatus);
  return {
    claim: {
      claimId: claimSnap.id,
      claimStatus: status,
      merchantId,
      merchantName,
      updatedAtMillis: readTimestampMillis(claimData.updatedAt),
      submittedAtMillis: readTimestampMillis(claimData.submittedAt),
      needsMoreInfo: status === "needs_more_info",
      conflictDetected: status === "conflict_detected",
      duplicateDetected: status === "duplicate_claim",
    },
  };
});

export const searchClaimableMerchants = onCall<
  SearchClaimableMerchantsRequest,
  Promise<SearchClaimableMerchantsResponse>
>({ enforceAppCheck: true }, async (request) => {
  assertAuthenticated(request.auth as CallableAuth);
  const zoneId = normalizeRequiredString(request.data.zoneId, "zoneId");
  const query = normalizeSearchQuery(request.data.query);
  const limit = normalizeSearchLimit(request.data.limit);

  // Scan acotado por zoneId + status + visibility para minimizar costo.
  const snapshot = await db()
    .collection("merchants")
    .where("zoneId", "==", zoneId)
    .where("status", "==", "active")
    .where("visibilityStatus", "in", ["visible", "review_pending"])
    .limit(80)
    .get();

  const merchants = snapshot.docs
    .map((doc) => {
      const data = doc.data();
      const name =
        typeof data.name === "string" && data.name.trim().length > 0
          ? data.name.trim()
          : "";
      const normalizedName = name
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase();
      const address =
        typeof data.address === "string" && data.address.trim().length > 0
          ? data.address.trim()
          : null;
      const normalizedAddress =
        address == null
          ? ""
          : address
              .normalize("NFD")
              .replace(/[\u0300-\u036f]/g, "")
              .toLowerCase();
      const categoryId =
        typeof data.categoryId === "string" ? data.categoryId.trim() : "";
      const ownershipStatus =
        typeof data.ownershipStatus === "string" ? data.ownershipStatus.trim() : "unclaimed";
      const ownerUserId =
        typeof data.ownerUserId === "string" ? data.ownerUserId.trim() : "";

      return {
        merchantId: doc.id,
        name,
        address,
        categoryId,
        zoneId,
        ownershipStatus,
        hasOwner: ownerUserId.length > 0,
        normalizedName,
        normalizedAddress,
      };
    })
    .filter((item) => item.name.length > 0)
    .filter((item) => {
      if (!query) return true;
      return (
        item.normalizedName.includes(query) ||
        item.normalizedAddress.includes(query) ||
        item.merchantId.toLowerCase().includes(query)
      );
    })
    .slice(0, limit)
    .map((item) => ({
      merchantId: item.merchantId,
      name: item.name,
      address: item.address,
      categoryId: item.categoryId,
      zoneId: item.zoneId,
      ownershipStatus: item.ownershipStatus,
      hasOwner: item.hasOwner,
    }));

  return {
    zoneId,
    query,
    merchants,
  };
});
