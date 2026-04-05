import { auth } from "firebase-functions/v1";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const db = () => getFirestore();

/**
 * onUserCreate — B-01
 *
 * Trigger: Firebase Auth user().onCreate
 *
 * Al crear un nuevo usuario:
 * 1. Crea el documento users/{uid} con rol 'customer' y estructura base.
 * 2. Asigna el custom claim { role: 'customer' } via Admin SDK.
 *
 * El claim 'role' NUNCA debe ser escrito desde el cliente.
 * Las Firestore Rules deniegan explícitamente ese campo en escrituras de cliente.
 */
export const onUserCreate = auth.user().onCreate(async (user) => {
  const adminAuth = getAuth();

  // Detectar proveedor de autenticación (Google vs. magic link)
  const providerId = user.providerData[0]?.providerId ?? "";
  const provider = providerId === "google.com" ? "google" : "email_link";

  try {
    // Ejecutar ambas operaciones en paralelo para minimizar latencia
    await Promise.all([
      // 1. Crear documento del usuario en Firestore
      db()
        .doc(`users/${user.uid}`)
        .set({
          uid: user.uid,
          role: "customer",
          displayName: user.displayName ?? null,
          email: user.email ?? null,
          provider,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          deletedAt: null,
          onboardingOwnerProgress: {
            currentStep: "idle",
            draftMerchantId: null,
            updatedAt: FieldValue.serverTimestamp(),
          },
        }),

      // 2. Asignar custom claim rol=customer
      adminAuth.setCustomUserClaims(user.uid, { role: "customer" }),
    ]);

    console.log(
      `[onUserCreate] Usuario ${user.uid} creado con rol 'customer' (provider: ${provider})`
    );
  } catch (err) {
    console.error(`[onUserCreate] Error al procesar usuario ${user.uid}:`, err);
    throw err;
  }
});
