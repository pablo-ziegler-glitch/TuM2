import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { applyUserAccessClaims } from "../lib/accessClaims";

const db = () => getFirestore();

interface AssignOwnerRoleResponse {
  success: boolean;
  role: "owner";
  ownerPending: true;
}

const REQUEST_WINDOW_MS = 24 * 60 * 60 * 1000;
const MIN_REQUEST_INTERVAL_MS = 60 * 1000;
const MAX_REQUESTS_PER_WINDOW = 5;

/**
 * assignOwnerRole — B-02
 *
 * Callable HTTPS autenticado.
 * Eleva el rol de un usuario CUSTOMER a OWNER.
 *
 * Reglas:
 * - Solo usuarios con rol 'customer' pueden invocarla.
 * - Si el claim ya es 'owner', 'admin' o 'super_admin' → rechaza con código 'already-owner'.
 * - Actualiza el custom claim Y el campo role en Firestore users/{uid}.
 * - El caller debe forzar refresh del token post-llamada (getIdTokenResult(forceRefresh: true)).
 */
export const assignOwnerRole = onCall<void, Promise<AssignOwnerRoleResponse>>(
  { enforceAppCheck: true },
  async (request) => {
    // Guard: solo usuarios autenticados
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Se requiere autenticación.");
    }

    const uid = request.auth.uid;
    const adminAuth = getAuth();
    const signInProvider = String(
      (request.auth.token.firebase as { sign_in_provider?: string } | undefined)
        ?.sign_in_provider ?? ""
    ).trim();
    if (signInProvider === "anonymous") {
      throw new HttpsError(
        "permission-denied",
        "Sesión no elegible para solicitar rol owner."
      );
    }

    // Leer claims actuales del usuario
    const userRecord = await adminAuth.getUser(uid);
    const currentRole = userRecord.customClaims?.["role"] as string | undefined;
    if (!userRecord.emailVerified) {
      throw new HttpsError(
        "failed-precondition",
        "Necesitás verificar tu email antes de solicitar rol owner."
      );
    }

    // Rechazar si el rol ya es owner o superior
    if (
      currentRole === "owner" ||
      currentRole === "admin" ||
      currentRole === "super_admin"
    ) {
      throw new HttpsError(
        "already-exists",
        "already-owner"
      );
    }

    const userRef = db().doc(`users/${uid}`);
    const nowMs = Date.now();
    let nextAccessVersion = 1;
    await db().runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      const userData = (userSnap.data() ?? {}) as Record<string, unknown>;
      const firestoreRole = String(userData["role"] ?? "").trim().toLowerCase();
      if (firestoreRole !== "customer") {
        throw new HttpsError(
          "permission-denied",
          "Solo usuarios customer pueden solicitar rol owner."
        );
      }
      const security = (userData["security"] ?? {}) as Record<string, unknown>;
      const assignOwnerRoleState = (security["assignOwnerRole"] ?? {}) as Record<
        string,
        unknown
      >;
      const lastAttemptAtMs = Number(assignOwnerRoleState["lastAttemptAtMs"] ?? 0);
      const windowStartedAtMs = Number(assignOwnerRoleState["windowStartedAtMs"] ?? 0);
      const requestCount = Number(assignOwnerRoleState["requestCount"] ?? 0);
      const lastSuccessAtMs = Number(assignOwnerRoleState["lastSuccessAtMs"] ?? 0);

      if (
        Number.isFinite(lastAttemptAtMs) &&
        lastAttemptAtMs > 0 &&
        nowMs - lastAttemptAtMs < MIN_REQUEST_INTERVAL_MS
      ) {
        throw new HttpsError(
          "resource-exhausted",
          "Demasiadas solicitudes seguidas. Reintentá en unos minutos."
        );
      }

      const windowIsActive =
        Number.isFinite(windowStartedAtMs) &&
        windowStartedAtMs > 0 &&
        nowMs - windowStartedAtMs < REQUEST_WINDOW_MS;
      const currentCount = windowIsActive ? requestCount : 0;
      const nextCount = currentCount + 1;
      if (nextCount > MAX_REQUESTS_PER_WINDOW) {
        throw new HttpsError(
          "resource-exhausted",
          "Límite de solicitudes excedido. Reintentá mañana."
        );
      }

      if (
        Number.isFinite(lastSuccessAtMs) &&
        lastSuccessAtMs > 0 &&
        nowMs - lastSuccessAtMs < REQUEST_WINDOW_MS
      ) {
        throw new HttpsError(
          "already-exists",
          "Ya tenés una solicitud owner reciente en proceso."
        );
      }

      const currentAccessVersionRaw = userData["accessVersion"];
      const currentAccessVersion =
        typeof currentAccessVersionRaw === "number" &&
        Number.isFinite(currentAccessVersionRaw)
          ? Math.max(0, Math.trunc(currentAccessVersionRaw))
          : 0;
      nextAccessVersion = currentAccessVersion + 1;

      tx.set(
        userRef,
        {
          role: "owner",
          ownerPending: true,
          accessVersion: nextAccessVersion,
          updatedAt: FieldValue.serverTimestamp(),
          security: {
            assignOwnerRole: {
              lastAttemptAtMs: nowMs,
              windowStartedAtMs: windowIsActive ? windowStartedAtMs : nowMs,
              requestCount: nextCount,
              lastSuccessAtMs: nowMs,
            },
          },
        },
        { merge: true }
      );
    });

    await Promise.all([
      // Actualizar custom claims canónicas vía Admin SDK.
      applyUserAccessClaims({
        uid,
        role: "owner",
        ownerPending: true,
        accessVersion: nextAccessVersion,
        reason: "assign_owner_role_callable",
        actorType: "user",
        actorUid: uid,
      }),
    ]);

    console.log(
      `[assignOwnerRole] Usuario ${uid} elevado a rol 'owner' con owner_pending=true`
    );

    return { success: true, role: "owner", ownerPending: true };
  }
);
