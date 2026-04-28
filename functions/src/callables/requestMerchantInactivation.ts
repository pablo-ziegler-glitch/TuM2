import { HttpsError, onCall } from "firebase-functions/v2/https";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const db = () => getFirestore();

const REQUEST_WINDOW_MS = 24 * 60 * 60 * 1000;
const MIN_REQUEST_INTERVAL_MS = 2 * 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 5;
const ALLOWED_REASONS = new Set([
  "cierre_temporal",
  "cierre_definitivo",
  "mudanza",
  "otro",
]);

interface RequestMerchantInactivationPayload {
  merchantId?: unknown;
  reason?: unknown;
  details?: unknown;
}

interface RequestMerchantInactivationResponse {
  ok: true;
  merchantId: string;
  status: "inactive";
  visibilityStatus: "suppressed";
}

/**
 * requestMerchantInactivation
 *
 * Owner verificado solicita baja lógica de su comercio.
 * Nunca elimina físicamente merchants/{merchantId}.
 */
export const requestMerchantInactivation = onCall<
  RequestMerchantInactivationPayload,
  Promise<RequestMerchantInactivationResponse>
>({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Se requiere autenticación.");
  }

  const role = String(request.auth.token.role ?? "").trim().toLowerCase();
  const ownerPending =
    request.auth.token.owner_pending === true ||
    request.auth.token.owner_pending === "true";
  if (role !== "owner" || ownerPending) {
    throw new HttpsError(
      "permission-denied",
      "Solo owners verificados pueden solicitar inactivación."
    );
  }

  const merchantId = String(request.data?.merchantId ?? "").trim();
  if (!merchantId) {
    throw new HttpsError("invalid-argument", "merchantId es obligatorio.");
  }

  const reason = String(request.data?.reason ?? "")
    .trim()
    .toLowerCase();
  if (!ALLOWED_REASONS.has(reason)) {
    throw new HttpsError("invalid-argument", "reason inválido.");
  }

  const detailsRaw = request.data?.details;
  const details = typeof detailsRaw === "string" ? detailsRaw.trim() : "";
  if (details.length > 280) {
    throw new HttpsError(
      "invalid-argument",
      "details excede el máximo permitido."
    );
  }

  const nowMs = Date.now();
  const merchantRef = db().doc(`merchants/${merchantId}`);

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(merchantRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Comercio no encontrado.");
    }

    const data = snap.data() as Record<string, unknown>;
    const ownerUserId = String(data["ownerUserId"] ?? "").trim();
    if (!ownerUserId || ownerUserId !== request.auth?.uid) {
      throw new HttpsError(
        "permission-denied",
        "No tenés permisos sobre este comercio."
      );
    }

    const verificationStatus = String(data["verificationStatus"] ?? "")
      .trim()
      .toLowerCase();
    if (verificationStatus !== "verified") {
      throw new HttpsError(
        "failed-precondition",
        "Solo comercios verificados pueden solicitar inactivación."
      );
    }

    const security = (data["security"] ?? {}) as Record<string, unknown>;
    const requests = (security["inactivationRequests"] ?? {}) as Record<
      string,
      unknown
    >;
    const lastRequestAtMs = Number(requests["lastRequestAtMs"] ?? 0);
    const windowStartedAtMs = Number(requests["windowStartedAtMs"] ?? 0);
    const requestCount = Number(requests["requestCount"] ?? 0);
    const windowIsActive =
      Number.isFinite(windowStartedAtMs) &&
      windowStartedAtMs > 0 &&
      nowMs - windowStartedAtMs < REQUEST_WINDOW_MS;

    if (
      Number.isFinite(lastRequestAtMs) &&
      lastRequestAtMs > 0 &&
      nowMs - lastRequestAtMs < MIN_REQUEST_INTERVAL_MS
    ) {
      throw new HttpsError(
        "resource-exhausted",
        "Solicitud reciente detectada. Reintentá más tarde."
      );
    }

    const currentCount = windowIsActive ? requestCount : 0;
    const nextCount = currentCount + 1;
    if (nextCount > MAX_REQUESTS_PER_WINDOW) {
      throw new HttpsError(
        "resource-exhausted",
        "Límite de solicitudes excedido para este comercio."
      );
    }

    const status = String(data["status"] ?? "").trim().toLowerCase();
    const visibilityStatus = String(data["visibilityStatus"] ?? "")
      .trim()
      .toLowerCase();
    if (status === "inactive" && visibilityStatus === "suppressed") {
      throw new HttpsError(
        "already-exists",
        "El comercio ya se encuentra inactivo."
      );
    }

    tx.set(
      merchantRef,
      {
        status: "inactive",
        visibilityStatus: "suppressed",
        inactivationRequestedAt: FieldValue.serverTimestamp(),
        inactivationRequestedByUid: request.auth.uid,
        inactivationReason: reason,
        inactivationDetails: details || null,
        updatedAt: FieldValue.serverTimestamp(),
        security: {
          inactivationRequests: {
            lastRequestAtMs: nowMs,
            windowStartedAtMs: windowIsActive ? windowStartedAtMs : nowMs,
            requestCount: nextCount,
          },
        },
      },
      { merge: true }
    );
  });

  return {
    ok: true,
    merchantId,
    status: "inactive",
    visibilityStatus: "suppressed",
  };
});
