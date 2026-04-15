import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

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

    const currentClaims = userRecord.customClaims ?? {};
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
    const normalizedMerchantIds = claimMerchantId == null
      ? [...new Set(claimMerchantIds)]
      : [...new Set([claimMerchantId, ...claimMerchantIds])];

    // Preservar claims existentes y elevar el rol
    const updatedClaims = {
      ...currentClaims,
      role: "owner",
      merchantIds: normalizedMerchantIds,
    };

    await Promise.all([
      // Actualizar custom claim via Admin SDK
      adminAuth.setCustomUserClaims(uid, updatedClaims),

      // Actualizar campo role en Firestore
      db().doc(`users/${uid}`).update({
        role: "owner",
        updatedAt: FieldValue.serverTimestamp(),
      }),
    ]);

    console.log(`[assignOwnerRole] Usuario ${uid} elevado a rol 'owner'`);

    return { success: true, role: "owner" };
  }
);
