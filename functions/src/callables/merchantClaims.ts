import { getAuth } from "firebase-admin/auth";
import { FieldPath, FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  SensitiveVault,
  buildSensitiveVault,
  revealSensitiveFields,
} from "../lib/claimSensitive";

const db = () => getFirestore();

type UserVisibleStatus =
  | "draft"
  | "submitted"
  | "under_review"
  | "needs_more_info"
  | "approved"
  | "rejected"
  | "duplicate_claim"
  | "conflict_detected";

type InternalWorkflowStatus =
  | "draft_editing"
  | "auto_validation_running"
  | "auto_validation_passed"
  | "auto_validation_blocked_conflict"
  | "auto_validation_blocked_duplicate"
  | "auto_validation_needs_more_info"
  | "manual_resolution_completed";

type ClaimStatus = UserVisibleStatus;
type DeclaredRole = "owner" | "co_owner" | "authorized_representative";
type EvidenceKind = "storefront_photo" | "ownership_document";
type SensitiveFieldKey = "phone" | "claimantDisplayName" | "claimantNote";

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

interface EvaluateMerchantClaimRequest {
  claimId?: unknown;
}

interface EvaluateMerchantClaimResponse {
  claimId: string;
  claimStatus: ClaimStatus;
  reasonCode: string | null;
  duplicateOfClaimId: string | null;
  updatedAtMillis: number | null;
}

interface ResolveMerchantClaimRequest {
  claimId?: unknown;
  userVisibleStatus?: unknown;
  reviewReasonCode?: unknown;
  reviewNotes?: unknown;
}

interface ResolveMerchantClaimResponse {
  claimId: string;
  claimStatus: ClaimStatus;
  reviewedAtMillis: number | null;
}

interface RevealSensitiveClaimDataRequest {
  claimId?: unknown;
  reasonCode?: unknown;
  fields?: unknown;
}

interface RevealSensitiveClaimDataResponse {
  claimId: string;
  expiresAtMillis: number;
  revealed: Partial<Record<SensitiveFieldKey, string>>;
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

interface ListMerchantClaimsForReviewRequest {
  zoneId?: unknown;
  statuses?: unknown;
  limit?: unknown;
  cursorCreatedAtMillis?: unknown;
  cursorClaimId?: unknown;
}

interface ReviewQueueItem {
  claimId: string;
  merchantId: string;
  userId: string;
  zoneId: string;
  categoryId: string | null;
  claimStatus: ClaimStatus;
  declaredRole: DeclaredRole;
  merchantName: string | null;
  submittedAtMillis: number | null;
  createdAtMillis: number | null;
  updatedAtMillis: number | null;
}

interface ListMerchantClaimsForReviewResponse {
  claims: ReviewQueueItem[];
  nextCursor: {
    createdAtMillis: number;
    claimId: string;
  } | null;
}

interface ListMyMerchantClaimsRequest {
  limit?: unknown;
  cursorUpdatedAtMillis?: unknown;
  cursorClaimId?: unknown;
}

interface MyClaimHistoryItem {
  claimId: string;
  merchantId: string;
  claimStatus: ClaimStatus;
  userVisibleStatus: ClaimStatus;
  zoneId: string | null;
  categoryId: string | null;
  merchantName: string | null;
  submittedAtMillis: number | null;
  createdAtMillis: number | null;
  updatedAtMillis: number | null;
}

interface ListMyMerchantClaimsResponse {
  claims: MyClaimHistoryItem[];
  nextCursor: {
    updatedAtMillis: number;
    claimId: string;
  } | null;
}

type CallableAuth = {
  uid: string;
  token: Record<string, unknown>;
};

const USER_VISIBLE_STATUSES: ReadonlySet<UserVisibleStatus> = new Set([
  "draft",
  "submitted",
  "under_review",
  "needs_more_info",
  "approved",
  "rejected",
  "duplicate_claim",
  "conflict_detected",
]);

const DRAFT_MUTABLE_STATUSES: ReadonlySet<UserVisibleStatus> = new Set([
  "draft",
  "needs_more_info",
]);

const ACTIVE_STATUSES: ReadonlyArray<UserVisibleStatus> = [
  "draft",
  "submitted",
  "under_review",
  "needs_more_info",
  "conflict_detected",
  "duplicate_claim",
];

const OWNER_PENDING_STATUSES: ReadonlySet<UserVisibleStatus> = new Set([
  "submitted",
  "under_review",
  "needs_more_info",
  "conflict_detected",
  "duplicate_claim",
]);

const CLOSED_NEGATIVE_STATUSES: ReadonlySet<UserVisibleStatus> = new Set([
  "rejected",
]);

const MAX_NOTE_LENGTH = 800;
const MAX_PHONE_LENGTH = 32;
const MAX_EVIDENCE_FILES = 6;
const MAX_EVIDENCE_FILE_BYTES = 8 * 1024 * 1024;
const STORAGE_PATH_PREFIX = "merchant-claims/";
const MAX_CLAIMABLE_SEARCH_LIMIT = 20;
const MAX_REVIEW_QUEUE_LIMIT = 50;
const MAX_MY_CLAIMS_LIMIT = 30;
const CLAIM_WORKFLOW_MANAGER = "callable_v2";
const DEFAULT_REVIEW_QUEUE_STATUSES: ReadonlyArray<UserVisibleStatus> = [
  "submitted",
  "under_review",
  "needs_more_info",
  "conflict_detected",
  "duplicate_claim",
];

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
  if (
    value === "owner" ||
    value === "co_owner" ||
    value === "authorized_representative"
  ) {
    return value;
  }
  throw new HttpsError("invalid-argument", "declaredRole inválido.");
}

function readDeclaredRole(value: unknown): DeclaredRole {
  if (
    value === "owner" ||
    value === "co_owner" ||
    value === "authorized_representative"
  ) {
    return value;
  }
  return "authorized_representative";
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
  const contentType = normalizeRequiredString(
    value,
    "evidence.contentType"
  ).toLowerCase();
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
    byId.set(id, {
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
    });
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

function normalizeReviewQueueLimit(value: unknown): number {
  if (value == null) return 20;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", "limit inválido.");
  }
  return Math.max(1, Math.min(MAX_REVIEW_QUEUE_LIMIT, Math.trunc(value)));
}

function normalizeMyClaimsLimit(value: unknown): number {
  if (value == null) return 12;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", "limit inválido.");
  }
  return Math.max(1, Math.min(MAX_MY_CLAIMS_LIMIT, Math.trunc(value)));
}

function normalizeCursorMillis(value: unknown, field: string): number | null {
  if (value == null) return null;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", `${field} inválido.`);
  }
  const truncated = Math.trunc(value);
  if (truncated <= 0) {
    throw new HttpsError("invalid-argument", `${field} inválido.`);
  }
  return truncated;
}

function normalizeCursorClaimId(value: unknown): string | null {
  if (value == null) return null;
  return normalizeClaimId(value);
}

function normalizeReviewQueueStatuses(value: unknown): UserVisibleStatus[] {
  if (value == null) return [...DEFAULT_REVIEW_QUEUE_STATUSES];
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "statuses debe ser un array.");
  }
  const allowed = new Set<UserVisibleStatus>(DEFAULT_REVIEW_QUEUE_STATUSES);
  const parsed = value
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim() as UserVisibleStatus)
    .filter((item): item is UserVisibleStatus => allowed.has(item));
  const unique = [...new Set(parsed)];
  if (unique.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "statuses debe incluir al menos un estado de revisión válido."
    );
  }
  if (unique.length > 10) {
    throw new HttpsError(
      "invalid-argument",
      "statuses excede el máximo permitido."
    );
  }
  return unique;
}

function toUserVisibleStatus(raw: unknown): UserVisibleStatus {
  if (typeof raw !== "string") return "draft";
  const normalized = raw.trim() as UserVisibleStatus;
  return USER_VISIBLE_STATUSES.has(normalized) ? normalized : "draft";
}

function parseRole(token: Record<string, unknown>): string {
  const role = token.role;
  return typeof role === "string" ? role.trim().toLowerCase() : "";
}

function assertAdmin(auth: CallableAuth): void {
  const role = parseRole(auth.token);
  if (role !== "admin" && role !== "super_admin") {
    throw new HttpsError(
      "permission-denied",
      "Solo administradores pueden ejecutar esta operación."
    );
  }
}

function normalizeResolveStatus(value: unknown): UserVisibleStatus {
  const normalized = normalizeRequiredString(value, "userVisibleStatus").toLowerCase();
  if (
    normalized === "approved" ||
    normalized === "rejected" ||
    normalized === "needs_more_info" ||
    normalized === "conflict_detected" ||
    normalized === "duplicate_claim"
  ) {
    return normalized;
  }
  throw new HttpsError(
    "invalid-argument",
    "userVisibleStatus inválido para resolución manual."
  );
}

function normalizeRevealFields(value: unknown): SensitiveFieldKey[] {
  const allowed = new Set<SensitiveFieldKey>([
    "phone",
    "claimantDisplayName",
    "claimantNote",
  ]);
  if (value == null) return ["phone", "claimantDisplayName", "claimantNote"];
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "fields debe ser un array.");
  }
  const parsed = value
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim())
    .filter((item): item is SensitiveFieldKey => allowed.has(item as SensitiveFieldKey));
  return parsed.length > 0 ? [...new Set(parsed)] : ["phone", "claimantDisplayName"];
}

function resolveMerchantName(data: Record<string, unknown>): string | null {
  const name = data.name;
  if (typeof name === "string" && name.trim().length > 0) {
    return name.trim();
  }
  return null;
}

function evidenceSignature(value: unknown): string {
  if (!Array.isArray(value)) return "";
  const signatures = value
    .map((entry) => {
      if (!entry || typeof entry !== "object") return "";
      const file = entry as Record<string, unknown>;
      const id = typeof file.id === "string" ? file.id : "";
      const kind = typeof file.kind === "string" ? file.kind : "";
      const storagePath =
        typeof file.storagePath === "string" ? file.storagePath : "";
      const contentType =
        typeof file.contentType === "string" ? file.contentType : "";
      const sizeBytes =
        typeof file.sizeBytes === "number" ? Math.trunc(file.sizeBytes) : -1;
      return `${id}|${kind}|${storagePath}|${contentType}|${sizeBytes}`;
    })
    .filter((entry) => entry.length > 0)
    .sort();
  return signatures.join(";");
}

function hasDraftChanges(params: {
  existing: Record<string, unknown>;
  next: {
    declaredRole: DeclaredRole;
    hasAcceptedDataProcessingConsent: boolean;
    hasAcceptedLegitimacyDeclaration: boolean;
    storefrontPhotoUploaded: boolean;
    ownershipDocumentUploaded: boolean;
    evidenceFiles: ClaimEvidenceStored[];
    phoneMasked: string | null;
    claimantDisplayNameMasked: string | null;
    claimantNoteMasked: string | null;
  };
}): boolean {
  const existing = params.existing;
  if (existing.declaredRole !== params.next.declaredRole) return true;
  if (
    existing.hasAcceptedDataProcessingConsent !==
    params.next.hasAcceptedDataProcessingConsent
  ) {
    return true;
  }
  if (
    existing.hasAcceptedLegitimacyDeclaration !==
    params.next.hasAcceptedLegitimacyDeclaration
  ) {
    return true;
  }
  if (
    existing.storefrontPhotoUploaded !== params.next.storefrontPhotoUploaded ||
    existing.ownershipDocumentUploaded !== params.next.ownershipDocumentUploaded
  ) {
    return true;
  }
  if (evidenceSignature(existing.evidenceFiles) !== evidenceSignature(params.next.evidenceFiles)) {
    return true;
  }
  if (existing.phoneMasked !== params.next.phoneMasked) return true;
  if (
    existing.claimantDisplayNameMasked !== params.next.claimantDisplayNameMasked
  ) {
    return true;
  }
  if (existing.claimantNoteMasked !== params.next.claimantNoteMasked) {
    return true;
  }
  return false;
}

function hasSensitivePrivateChanges(
  currentVault: unknown,
  nextVault: SensitiveVault
): boolean {
  if (currentVault == null || typeof currentVault !== "object") {
    return true;
  }
  return JSON.stringify(currentVault) !== JSON.stringify(nextVault);
}

async function hasOtherPendingClaims(
  userId: string,
  excludeClaimId: string
): Promise<boolean> {
  const snap = await db()
    .collection("merchant_claims")
    .where("userId", "==", userId)
    .where("claimStatus", "in", [...OWNER_PENDING_STATUSES])
    .limit(5)
    .get();
  return snap.docs.some((doc) => doc.id !== excludeClaimId);
}

async function syncOwnerPendingAccess(params: {
  userId: string;
  claimId: string;
  claimStatus: UserVisibleStatus;
  merchantId: string;
}): Promise<void> {
  const auth = getAuth();
  let currentClaims: Record<string, unknown> = {};
  let isOwner = false;

  try {
    const userRecord = await auth.getUser(params.userId);
    currentClaims = (userRecord.customClaims ?? {}) as Record<string, unknown>;
    isOwner = currentClaims["role"] === "owner";
  } catch (error) {
    console.warn(
      JSON.stringify({
        source: "merchant_claims",
        action: "owner_pending_get_user_failed",
        userId: params.userId,
        claimId: params.claimId,
        error: error instanceof Error ? error.message : String(error),
      })
    );
  }

  let ownerPending = OWNER_PENDING_STATUSES.has(params.claimStatus);
  if (!ownerPending && !isOwner && CLOSED_NEGATIVE_STATUSES.has(params.claimStatus)) {
    ownerPending = await hasOtherPendingClaims(params.userId, params.claimId);
  }

  const nextClaims: Record<string, unknown> = { ...currentClaims };
  nextClaims["owner_pending"] = ownerPending;

  if (params.claimStatus === "approved") {
    const claimMerchantId =
      typeof currentClaims["merchantId"] === "string" &&
      currentClaims["merchantId"].trim().length > 0
        ? currentClaims["merchantId"].trim()
        : null;
    const claimMerchantIds = Array.isArray(currentClaims["merchantIds"])
      ? currentClaims["merchantIds"]
          .filter((value): value is string => typeof value === "string")
          .map((value) => value.trim())
          .filter((value) => value.length > 0)
      : [];
    nextClaims["role"] = "owner";
    nextClaims["merchantId"] = claimMerchantId ?? params.merchantId;
    nextClaims["merchantIds"] = [...new Set([params.merchantId, ...claimMerchantIds])];
    nextClaims["onboardingComplete"] = true;
    nextClaims["owner_pending"] = false;
  } else if (!isOwner) {
    nextClaims["role"] = "customer";
    nextClaims["onboardingComplete"] = false;
  }

  if (JSON.stringify(currentClaims) !== JSON.stringify(nextClaims)) {
    try {
      await auth.setCustomUserClaims(params.userId, nextClaims);
    } catch (error) {
      console.warn(
        JSON.stringify({
          source: "merchant_claims",
          action: "owner_pending_set_claims_failed",
          userId: params.userId,
          claimId: params.claimId,
          error: error instanceof Error ? error.message : String(error),
        })
      );
    }
  }

  const userRef = db().doc(`users/${params.userId}`);
  const nextUserRole =
    params.claimStatus === "approved" ? "owner" : isOwner ? "owner" : "customer";
  const nextUserMerchantId =
    params.claimStatus === "approved" ? (nextClaims["merchantId"] as string) : null;
  const nextUserOwnerPending = nextClaims["owner_pending"] === true;
  const nextUserOnboarding = nextClaims["onboardingComplete"] === true;

  const userSnap = await userRef.get();
  const userData = userSnap.data() ?? {};
  const currentUserRole = typeof userData.role === "string" ? userData.role : null;
  const currentUserMerchantId =
    typeof userData.merchantId === "string" ? userData.merchantId : null;
  const currentUserOwnerPending = userData.ownerPending === true;
  const currentUserOnboarding = userData.onboardingComplete === true;

  const changed =
    currentUserRole !== nextUserRole ||
    currentUserMerchantId !== nextUserMerchantId ||
    currentUserOwnerPending !== nextUserOwnerPending ||
    currentUserOnboarding !== nextUserOnboarding;

  if (changed) {
    await userRef.set(
      {
        role: nextUserRole,
        merchantId: nextUserMerchantId,
        ownerPending: nextUserOwnerPending,
        onboardingComplete: nextUserOnboarding,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
}

async function evaluateClaimOutcome(params: {
  claimId: string;
  userId: string;
  merchantId: string;
  merchantOwnerUid: string;
  ownershipStatus: string;
  requiredEvidence: { storefront: boolean; ownershipDocument: boolean };
}): Promise<{
  userVisibleStatus: UserVisibleStatus;
  internalWorkflowStatus: InternalWorkflowStatus;
  reasonCode: string | null;
  conflictType: string | null;
  duplicateOfClaimId: string | null;
}> {
  if (!params.requiredEvidence.storefront || !params.requiredEvidence.ownershipDocument) {
    return {
      userVisibleStatus: "needs_more_info",
      internalWorkflowStatus: "auto_validation_needs_more_info",
      reasonCode: "missing_minimum_evidence",
      conflictType: null,
      duplicateOfClaimId: null,
    };
  }

  if (
    (params.merchantOwnerUid && params.merchantOwnerUid !== params.userId) ||
    params.ownershipStatus === "claimed"
  ) {
    return {
      userVisibleStatus: "conflict_detected",
      internalWorkflowStatus: "auto_validation_blocked_conflict",
      reasonCode: "merchant_already_owned",
      conflictType: "merchant_already_owned",
      duplicateOfClaimId: null,
    };
  }

  const duplicateSnap = await db()
    .collection("merchant_claims")
    .where("userId", "==", params.userId)
    .where("merchantId", "==", params.merchantId)
    .where("claimStatus", "in", ACTIVE_STATUSES)
    .limit(3)
    .get();
  const duplicate = duplicateSnap.docs.find((doc) => doc.id !== params.claimId);
  if (duplicate) {
    return {
      userVisibleStatus: "duplicate_claim",
      internalWorkflowStatus: "auto_validation_blocked_duplicate",
      reasonCode: "duplicate_claim",
      conflictType: null,
      duplicateOfClaimId: duplicate.id,
    };
  }

  return {
    userVisibleStatus: "under_review",
    internalWorkflowStatus: "auto_validation_passed",
    reasonCode: null,
    conflictType: null,
    duplicateOfClaimId: null,
  };
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
    request.data.claimId == null
      ? db().collection("merchant_claims").doc().id
      : normalizeClaimId(request.data.claimId);
  const evidenceFiles = normalizeEvidenceFiles(request.data.evidenceFiles, {
    uid,
    claimId,
  });
  const requiredEvidence = claimHasRequiredEvidence(evidenceFiles);
  const sensitive = buildSensitiveVault({
    userId: uid,
    merchantId,
    phone,
    claimantDisplayName,
    claimantNote,
  });

  const claimsCollection = db().collection("merchant_claims");
  const claimRef = claimsCollection.doc(claimId);
  const privateRef = db().collection("merchant_claim_private").doc(claimId);
  const existingClaimSnap = await claimRef.get();
  const existingPrivateSnap = await privateRef.get();
  let shouldUpsertPrivate = !existingPrivateSnap.exists;

  if (existingClaimSnap.exists) {
    const existingData = existingClaimSnap.data() ?? {};
    if (existingData.userId !== uid) {
      throw new HttpsError("permission-denied", "No podés modificar este claim.");
    }
    const currentStatus = toUserVisibleStatus(
      existingData.userVisibleStatus ?? existingData.claimStatus
    );
    if (!DRAFT_MUTABLE_STATUSES.has(currentStatus)) {
      throw new HttpsError(
        "failed-precondition",
        "Este claim ya no se puede editar desde el flujo de borrador."
      );
    }
    const changed = hasDraftChanges({
      existing: existingData as Record<string, unknown>,
      next: {
        declaredRole,
        hasAcceptedDataProcessingConsent,
        hasAcceptedLegitimacyDeclaration,
        storefrontPhotoUploaded: requiredEvidence.storefront,
        ownershipDocumentUploaded: requiredEvidence.ownershipDocument,
        evidenceFiles,
        phoneMasked: sensitive.masked.phoneMasked ?? null,
        claimantDisplayNameMasked: sensitive.masked.claimantDisplayNameMasked ?? null,
        claimantNoteMasked: sensitive.masked.claimantNoteMasked ?? null,
      },
    });
    const sensitiveChanged = hasSensitivePrivateChanges(
      existingPrivateSnap.data()?.sensitiveVault,
      sensitive.vault
    );
    shouldUpsertPrivate = sensitiveChanged || !existingPrivateSnap.exists;
    if (!changed && !sensitiveChanged) {
      return {
        claimId,
        claimStatus: toUserVisibleStatus(
          existingData.userVisibleStatus ?? existingData.claimStatus
        ),
        merchantId,
        updatedAtMillis: readTimestampMillis(existingData.updatedAt),
      };
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
      throw new HttpsError("already-exists", "Ya existe un claim activo para este comercio.", {
        code: "active_claim_exists",
        claimId: active.id,
        claimStatus: active.data().claimStatus ?? "draft",
      });
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
    userVisibleStatus: "draft",
    internalWorkflowStatus: "draft_editing",
    workflowManagedBy: CLAIM_WORKFLOW_MANAGER,
    authenticatedEmail: authEmail,
    declaredRole,
    phone: FieldValue.delete(),
    claimantDisplayName: FieldValue.delete(),
    claimantNote: FieldValue.delete(),
    sensitiveVault: FieldValue.delete(),
    fingerprintPrimary: FieldValue.delete(),
    ...sensitive.masked,
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
  if (shouldUpsertPrivate) {
    await privateRef.set(
      {
        claimId,
        userId: uid,
        merchantId,
        sensitiveVault: sensitive.vault,
        fingerprintPrimary: sensitive.vault.fingerprintPrimary ?? null,
        updatedAt: now,
        ...(existingPrivateSnap.exists ? {} : { createdAt: now }),
      },
      { merge: true }
    );
  }
  const saved = await claimRef.get();
  const savedData = saved.data() ?? {};
  return {
    claimId,
    claimStatus: toUserVisibleStatus(savedData.userVisibleStatus ?? savedData.claimStatus),
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

  const currentStatus = toUserVisibleStatus(
    claimData.userVisibleStatus ?? claimData.claimStatus
  );
  if (!(currentStatus === "draft" || currentStatus === "needs_more_info")) {
    throw new HttpsError(
      "failed-precondition",
      "El claim no está en estado editable para envío."
    );
  }

  const evidenceFilesRaw = Array.isArray(claimData.evidenceFiles)
    ? claimData.evidenceFiles
    : [];
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

  const decision = await evaluateClaimOutcome({
    claimId,
    userId: uid,
    merchantId,
    merchantOwnerUid,
    ownershipStatus,
    requiredEvidence,
  });

  const nextAction: SubmitMerchantClaimResponse["nextAction"] =
    decision.userVisibleStatus === "conflict_detected" ||
    decision.userVisibleStatus === "duplicate_claim"
      ? "resolve_conflict"
      : decision.userVisibleStatus === "needs_more_info"
      ? "provide_more_info"
      : "wait_review";

  const now = FieldValue.serverTimestamp();
  await claimRef.set(
    {
      authenticatedEmail: authEmail,
      claimStatus: decision.userVisibleStatus,
      userVisibleStatus: decision.userVisibleStatus,
      internalWorkflowStatus: decision.internalWorkflowStatus,
      workflowManagedBy: CLAIM_WORKFLOW_MANAGER,
      sensitiveVault: FieldValue.delete(),
      fingerprintPrimary: FieldValue.delete(),
      submittedAt: now,
      updatedAt: now,
      lastStatusAt: now,
      autoValidationVersion: 2,
      autoValidationResult:
        decision.userVisibleStatus === "under_review" ? "passed" : "blocked",
      autoValidationReasonCode: decision.reasonCode,
      conflictType: decision.conflictType,
      duplicateOfClaimId: decision.duplicateOfClaimId,
    },
    { merge: true }
  );

  await syncOwnerPendingAccess({
    userId: uid,
    claimId,
    claimStatus: decision.userVisibleStatus,
    merchantId,
  });

  const updated = (await claimRef.get()).data() ?? {};
  return {
    claimId,
    claimStatus: toUserVisibleStatus(updated.userVisibleStatus ?? updated.claimStatus),
    submittedAtMillis: readTimestampMillis(updated.submittedAt),
    nextAction,
  };
});

export const evaluateMerchantClaim = onCall<
  EvaluateMerchantClaimRequest,
  Promise<EvaluateMerchantClaimResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth as CallableAuth);
  assertAdmin(auth);

  const claimId = normalizeClaimId(request.data.claimId);
  const claimRef = db().collection("merchant_claims").doc(claimId);
  const claimSnap = await claimRef.get();
  if (!claimSnap.exists) {
    throw new HttpsError("not-found", "No encontramos el claim.");
  }
  const claimData = claimSnap.data() ?? {};
  const userId = normalizeRequiredString(claimData.userId, "claim.userId");
  const merchantId = normalizeRequiredString(claimData.merchantId, "claim.merchantId");
  const evidenceFiles = normalizeEvidenceFiles(claimData.evidenceFiles ?? [], {
    uid: userId,
    claimId,
  });
  const requiredEvidence = claimHasRequiredEvidence(evidenceFiles);

  const merchantSnap = await db().collection("merchants").doc(merchantId).get();
  if (!merchantSnap.exists) {
    throw new HttpsError("failed-precondition", "El comercio no está disponible.");
  }
  const merchantData = merchantSnap.data() ?? {};
  const merchantOwnerUid =
    typeof merchantData.ownerUserId === "string" ? merchantData.ownerUserId.trim() : "";
  const ownershipStatus =
    typeof merchantData.ownershipStatus === "string"
      ? merchantData.ownershipStatus.trim().toLowerCase()
      : "";

  const decision = await evaluateClaimOutcome({
    claimId,
    userId,
    merchantId,
    merchantOwnerUid,
    ownershipStatus,
    requiredEvidence,
  });

  const currentStatus = toUserVisibleStatus(
    claimData.userVisibleStatus ?? claimData.claimStatus
  );
  const currentInternal =
    typeof claimData.internalWorkflowStatus === "string"
      ? claimData.internalWorkflowStatus
      : null;
  if (
    currentStatus !== decision.userVisibleStatus ||
    currentInternal !== decision.internalWorkflowStatus
  ) {
    await claimRef.set(
      {
        claimStatus: decision.userVisibleStatus,
        userVisibleStatus: decision.userVisibleStatus,
        internalWorkflowStatus: decision.internalWorkflowStatus,
        workflowManagedBy: CLAIM_WORKFLOW_MANAGER,
        sensitiveVault: FieldValue.delete(),
        fingerprintPrimary: FieldValue.delete(),
        autoValidationVersion: 2,
        autoValidationResult:
          decision.userVisibleStatus === "under_review" ? "passed" : "blocked",
        autoValidationReasonCode: decision.reasonCode,
        conflictType: decision.conflictType,
        duplicateOfClaimId: decision.duplicateOfClaimId,
        updatedAt: FieldValue.serverTimestamp(),
        lastStatusAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  await syncOwnerPendingAccess({
    userId,
    claimId,
    claimStatus: decision.userVisibleStatus,
    merchantId,
  });

  const updated = (await claimRef.get()).data() ?? {};
  return {
    claimId,
    claimStatus: toUserVisibleStatus(updated.userVisibleStatus ?? updated.claimStatus),
    reasonCode: decision.reasonCode,
    duplicateOfClaimId: decision.duplicateOfClaimId,
    updatedAtMillis: readTimestampMillis(updated.updatedAt),
  };
});

export const resolveMerchantClaim = onCall<
  ResolveMerchantClaimRequest,
  Promise<ResolveMerchantClaimResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth as CallableAuth);
  assertAdmin(auth);
  const reviewerUid = auth.uid;

  const claimId = normalizeClaimId(request.data.claimId);
  const targetStatus = normalizeResolveStatus(request.data.userVisibleStatus);
  const reviewReasonCode = normalizeOptionalString(
    request.data.reviewReasonCode,
    "reviewReasonCode",
    120
  );
  const reviewNotes = normalizeOptionalString(
    request.data.reviewNotes,
    "reviewNotes",
    600
  );

  const claimRef = db().collection("merchant_claims").doc(claimId);
  const claimSnap = await claimRef.get();
  if (!claimSnap.exists) {
    throw new HttpsError("not-found", "No encontramos el claim.");
  }
  const claimData = claimSnap.data() ?? {};
  const userId = normalizeRequiredString(claimData.userId, "claim.userId");
  const merchantId = normalizeRequiredString(claimData.merchantId, "claim.merchantId");
  const currentStatus = toUserVisibleStatus(
    claimData.userVisibleStatus ?? claimData.claimStatus
  );

  if (currentStatus !== targetStatus) {
    await claimRef.set(
      {
        claimStatus: targetStatus,
        userVisibleStatus: targetStatus,
        internalWorkflowStatus: "manual_resolution_completed",
        workflowManagedBy: CLAIM_WORKFLOW_MANAGER,
        sensitiveVault: FieldValue.delete(),
        fingerprintPrimary: FieldValue.delete(),
        reviewReasonCode: reviewReasonCode ?? null,
        reviewNotes: reviewNotes ?? null,
        reviewedByUid: reviewerUid,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        lastStatusAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  } else if (reviewReasonCode != null || reviewNotes != null) {
    await claimRef.set(
      {
        reviewReasonCode: reviewReasonCode ?? null,
        reviewNotes: reviewNotes ?? null,
        reviewedByUid: reviewerUid,
        workflowManagedBy: CLAIM_WORKFLOW_MANAGER,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  if (targetStatus === "approved") {
    await db().doc(`merchants/${merchantId}`).set(
      {
        ownerUserId: userId,
        ownershipStatus: "claimed",
        verificationStatus: "claimed",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  await syncOwnerPendingAccess({
    userId,
    claimId,
    claimStatus: targetStatus,
    merchantId,
  });

  const updated = (await claimRef.get()).data() ?? {};
  return {
    claimId,
    claimStatus: toUserVisibleStatus(updated.userVisibleStatus ?? updated.claimStatus),
    reviewedAtMillis: readTimestampMillis(updated.reviewedAt),
  };
});

export const revealMerchantClaimSensitiveData = onCall<
  RevealSensitiveClaimDataRequest,
  Promise<RevealSensitiveClaimDataResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth as CallableAuth);
  assertAdmin(auth);

  const claimId = normalizeClaimId(request.data.claimId);
  const reasonCode = normalizeRequiredString(request.data.reasonCode, "reasonCode");
  const fields = normalizeRevealFields(request.data.fields);
  const claimSnap = await db().collection("merchant_claims").doc(claimId).get();
  if (!claimSnap.exists) {
    throw new HttpsError("not-found", "No encontramos el claim.");
  }
  const privateSnap = await db().collection("merchant_claim_private").doc(claimId).get();
  if (!privateSnap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "El claim no tiene datos sensibles disponibles para reveal."
    );
  }
  const privateData = privateSnap.data() ?? {};
  const vaultRaw = privateData.sensitiveVault;
  if (typeof vaultRaw !== "object" || vaultRaw == null) {
    throw new HttpsError(
      "failed-precondition",
      "El claim no tiene datos sensibles disponibles para reveal."
    );
  }

  const vault = vaultRaw as SensitiveVault;
  const revealed = revealSensitiveFields({
    vault,
    requestedFields: fields,
  });
  const expiresAtMillis = Date.now() + 5 * 60 * 1000;

  await db()
    .collection("merchant_claim_sensitive_reveals")
    .add({
      claimId,
      actorUid: auth.uid,
      reasonCode,
      revealedFields: Object.keys(revealed),
      keyVersion: vault.keyVersion ?? "unknown",
      expiresAtMillis,
      createdAt: FieldValue.serverTimestamp(),
    });

  return {
    claimId,
    expiresAtMillis,
    revealed,
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

  const status = toUserVisibleStatus(
    claimData.userVisibleStatus ?? claimData.claimStatus
  );
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

export const listMerchantClaimsForReview = onCall<
  ListMerchantClaimsForReviewRequest,
  Promise<ListMerchantClaimsForReviewResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth as CallableAuth);
  assertAdmin(auth);

  const zoneId = normalizeRequiredString(request.data.zoneId, "zoneId");
  const statuses = normalizeReviewQueueStatuses(request.data.statuses);
  const limit = normalizeReviewQueueLimit(request.data.limit);
  const cursorCreatedAtMillis = normalizeCursorMillis(
    request.data.cursorCreatedAtMillis,
    "cursorCreatedAtMillis"
  );
  const cursorClaimId = normalizeCursorClaimId(request.data.cursorClaimId);

  if ((cursorCreatedAtMillis == null) !== (cursorClaimId == null)) {
    throw new HttpsError(
      "invalid-argument",
      "cursorCreatedAtMillis y cursorClaimId deben enviarse juntos."
    );
  }

  let query = db()
    .collection("merchant_claims")
    .where("zoneId", "==", zoneId)
    .where("claimStatus", "in", statuses)
    .orderBy("createdAt", "desc")
    .orderBy(FieldPath.documentId(), "desc")
    .limit(limit);

  if (cursorCreatedAtMillis != null && cursorClaimId != null) {
    query = query.startAfter(
      Timestamp.fromMillis(cursorCreatedAtMillis),
      cursorClaimId
    );
  }

  const snapshot = await query.get();
  const claims = snapshot.docs.map((doc) => {
    const data = doc.data() ?? {};
    return {
      claimId: doc.id,
      merchantId: normalizeRequiredString(data.merchantId, "claim.merchantId"),
      userId: normalizeRequiredString(data.userId, "claim.userId"),
      zoneId: normalizeRequiredString(data.zoneId, "claim.zoneId"),
      categoryId: typeof data.categoryId === "string" ? data.categoryId : null,
      claimStatus: toUserVisibleStatus(data.userVisibleStatus ?? data.claimStatus),
      declaredRole: readDeclaredRole(data.declaredRole),
      merchantName:
        typeof data.merchantName === "string" && data.merchantName.trim().length > 0
          ? data.merchantName.trim()
          : null,
      submittedAtMillis: readTimestampMillis(data.submittedAt),
      createdAtMillis: readTimestampMillis(data.createdAt),
      updatedAtMillis: readTimestampMillis(data.updatedAt),
    } satisfies ReviewQueueItem;
  });

  const last = snapshot.docs[snapshot.docs.length - 1];
  const lastCreatedAtMillis = last ? readTimestampMillis(last.data()?.createdAt) : null;
  const nextCursor =
    claims.length === limit && last && lastCreatedAtMillis != null
      ? {
          createdAtMillis: lastCreatedAtMillis,
          claimId: last.id,
        }
      : null;

  return {
    claims,
    nextCursor,
  };
});

export const listMyMerchantClaims = onCall<
  ListMyMerchantClaimsRequest,
  Promise<ListMyMerchantClaimsResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth as CallableAuth);
  const uid = auth.uid;
  const limit = normalizeMyClaimsLimit(request.data.limit);
  const cursorUpdatedAtMillis = normalizeCursorMillis(
    request.data.cursorUpdatedAtMillis,
    "cursorUpdatedAtMillis"
  );
  const cursorClaimId = normalizeCursorClaimId(request.data.cursorClaimId);

  if ((cursorUpdatedAtMillis == null) !== (cursorClaimId == null)) {
    throw new HttpsError(
      "invalid-argument",
      "cursorUpdatedAtMillis y cursorClaimId deben enviarse juntos."
    );
  }

  let query = db()
    .collection("merchant_claims")
    .where("userId", "==", uid)
    .orderBy("updatedAt", "desc")
    .orderBy(FieldPath.documentId(), "desc")
    .limit(limit);

  if (cursorUpdatedAtMillis != null && cursorClaimId != null) {
    query = query.startAfter(
      Timestamp.fromMillis(cursorUpdatedAtMillis),
      cursorClaimId
    );
  }

  const snapshot = await query.get();
  const claims = snapshot.docs.map((doc) => {
    const data = doc.data() ?? {};
    const status = toUserVisibleStatus(data.userVisibleStatus ?? data.claimStatus);
    return {
      claimId: doc.id,
      merchantId: normalizeRequiredString(data.merchantId, "claim.merchantId"),
      claimStatus: status,
      userVisibleStatus: status,
      zoneId: typeof data.zoneId === "string" ? data.zoneId : null,
      categoryId: typeof data.categoryId === "string" ? data.categoryId : null,
      merchantName:
        typeof data.merchantName === "string" && data.merchantName.trim().length > 0
          ? data.merchantName.trim()
          : null,
      submittedAtMillis: readTimestampMillis(data.submittedAt),
      createdAtMillis: readTimestampMillis(data.createdAt),
      updatedAtMillis: readTimestampMillis(data.updatedAt),
    } satisfies MyClaimHistoryItem;
  });

  const last = snapshot.docs[snapshot.docs.length - 1];
  const lastUpdatedAtMillis = last ? readTimestampMillis(last.data()?.updatedAt) : null;
  const nextCursor =
    claims.length === limit && last && lastUpdatedAtMillis != null
      ? {
          updatedAtMillis: lastUpdatedAtMillis,
          claimId: last.id,
        }
      : null;

  return {
    claims,
    nextCursor,
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
        typeof data.ownershipStatus === "string"
          ? data.ownershipStatus.trim()
          : "unclaimed";
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
