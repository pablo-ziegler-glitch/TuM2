import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { applyUserAccessClaims } from "../lib/accessClaims";

const db = () => getFirestore();

interface AssignOwnerRoleResponse {
  success: boolean;
  role: "owner";
}

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

    // Leer claims actuales del usuario
    const userRecord = await adminAuth.getUser(uid);
    const currentRole = userRecord.customClaims?.["role"] as string | undefined;

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
    const userSnap = await userRef.get();
    const userData = (userSnap.data() ?? {}) as Record<string, unknown>;
    const currentAccessVersionRaw = userData["accessVersion"];
    const currentAccessVersion =
      typeof currentAccessVersionRaw === "number" && Number.isFinite(currentAccessVersionRaw)
        ? Math.max(0, Math.trunc(currentAccessVersionRaw))
        : 0;
    const nextAccessVersion = currentAccessVersion + 1;

    await Promise.all([
      // Actualizar custom claims canónicas vía Admin SDK.
      applyUserAccessClaims({
        uid,
        role: "owner",
        ownerPending: false,
        accessVersion: nextAccessVersion,
        reason: "assign_owner_role_callable",
        actorType: "user",
        actorUid: uid,
      }),

      // Actualizar campos de acceso en Firestore.
      userRef.set({
        role: "owner",
        ownerPending: false,
        accessVersion: nextAccessVersion,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true }),
    ]);

    console.log(`[assignOwnerRole] Usuario ${uid} elevado a rol 'owner'`);

    return { success: true, role: "owner" };
  }
);
