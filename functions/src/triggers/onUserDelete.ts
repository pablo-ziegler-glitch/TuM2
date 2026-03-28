import { auth } from "firebase-functions/v1";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const db = () => getFirestore();

/**
 * onUserDelete — B-03
 *
 * Trigger: Firebase Auth user().onDelete
 *
 * Al eliminar un usuario de Firebase Auth:
 * 1. Marca users/{uid}.deletedAt con timestamp.
 * 2. Anonimiza: elimina email y displayName del documento Firestore.
 * 3. Si existe un draft de onboarding en curso, elimina merchant_drafts/{draftId}.
 *
 * No elimina el documento users/{uid} para conservar historial de actividad
 * (reportes, señales, etc.) con referencia al uid sin datos personales.
 */
export const onUserDelete = auth.user().onDelete(async (user) => {
  const userRef = db().doc(`users/${user.uid}`);

  let draftMerchantId: string | null = null;

  try {
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      // El documento puede no existir si onUserCreate falló
      console.warn(
        `[onUserDelete] No se encontró users/${user.uid}. Nada que anonimizar.`
      );
      return;
    }

    const data = userDoc.data() as Record<string, unknown>;
    const progress = data?.onboardingOwnerProgress as
      | Record<string, unknown>
      | undefined;
    draftMerchantId = (progress?.draftMerchantId as string | null) ?? null;
  } catch (err) {
    console.error(
      `[onUserDelete] Error al leer users/${user.uid}:`,
      err
    );
    // Continuar igualmente para intentar la anonimización
  }

  const ops: Promise<unknown>[] = [
    // Anonimizar: borrar datos personales, marcar como eliminado
    userRef.update({
      deletedAt: FieldValue.serverTimestamp(),
      email: null,
      displayName: null,
      updatedAt: FieldValue.serverTimestamp(),
    }),
  ];

  // Eliminar borrador de alta de comercio si existe
  if (draftMerchantId) {
    ops.push(
      db()
        .doc(`merchant_drafts/${draftMerchantId}`)
        .delete()
        .catch((err) => {
          // No bloquear el resto si el draft ya no existe
          console.warn(
            `[onUserDelete] merchant_drafts/${draftMerchantId} no se pudo eliminar:`,
            err
          );
        })
    );
  }

  await Promise.all(ops);

  console.log(`[onUserDelete] Usuario ${user.uid} anonimizado correctamente`);
});
