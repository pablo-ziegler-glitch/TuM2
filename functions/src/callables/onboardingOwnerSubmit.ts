import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import {
  OnboardingOwnerProgress,
  OnboardingStep3Data,
} from "../lib/types";
import { applyUserAccessClaims } from "../lib/accessClaims";

const db = () => getFirestore();

function canonicalCategoryId(raw: string): string {
  return raw.trim().toLowerCase();
}

const ALLOWED_CANONICAL_CATEGORY_IDS = new Set<string>([
  "farmacia",
  "kiosco",
  "almacen",
  "veterinaria",
  "comida_al_paso",
  "casa_de_comidas",
  "gomeria",
  "panaderia",
  "confiteria",
]);

interface OnboardingOwnerSubmitRequest {
  draftMerchantId: string;
}

interface OnboardingOwnerSubmitResponse {
  merchantId: string;
  status: "created" | "already_submitted";
}

/**
 * onboardingOwnerSubmit
 *
 * Callable HTTPS function. Atomically creates the merchant document from
 * the owner's onboarding draft, optionally writes schedules, and marks
 * the onboarding progress as submitted.
 *
 * Idempotent: calling it again on an already-submitted draft returns
 * { status: 'already_submitted' } without error.
 */
export const onboardingOwnerSubmit = onCall(
  { enforceAppCheck: true },
  async (request): Promise<OnboardingOwnerSubmitResponse> => {
    // ── Auth guard ──────────────────────────────────────────────────────────
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }
    const uid = request.auth.uid;

    // ── Role guard ──────────────────────────────────────────────────────────
    const userRef = db().doc(`users/${uid}`);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "Usuario no encontrado.");
    }
    const userData = userSnap.data()!;
    if (userData.role !== "owner") {
      throw new HttpsError(
        "permission-denied",
        "Solo usuarios con rol 'owner' pueden usar esta función."
      );
    }

    // ── Validate input ──────────────────────────────────────────────────────
    const { draftMerchantId } = request.data as OnboardingOwnerSubmitRequest;
    if (!draftMerchantId || typeof draftMerchantId !== "string") {
      throw new HttpsError("invalid-argument", "draftMerchantId es requerido.");
    }

    // ── Read onboarding progress ────────────────────────────────────────────
    const progress = userData.onboardingOwnerProgress as OnboardingOwnerProgress | undefined;
    if (!progress) {
      throw new HttpsError(
        "failed-precondition",
        "No se encontró progreso de onboarding para este usuario."
      );
    }

    // ── Idempotency: already submitted/completed ────────────────────────────
    if (
      progress.currentStep === "submitted" ||
      progress.currentStep === "completed"
    ) {
      const existingId = progress.draftMerchantId ?? draftMerchantId;
      console.log(`[onboardingOwnerSubmit] Already submitted for uid=${uid}, merchantId=${existingId}`);
      return { merchantId: existingId, status: "already_submitted" };
    }

    // ── Anti-replay: draftMerchantId must match ─────────────────────────────
    if (progress.draftMerchantId !== draftMerchantId) {
      throw new HttpsError(
        "invalid-argument",
        "draftMerchantId no coincide con el registrado en Firestore."
      );
    }

    // ── Validate step1 ──────────────────────────────────────────────────────
    const step1 = progress.step1;
    if (!step1?.name || !step1?.categoryId) {
      throw new HttpsError(
        "failed-precondition",
        "El paso 1 (nombre y categoría) no fue completado."
      );
    }
    if (step1.name.trim().length < 2 || step1.name.trim().length > 80) {
      throw new HttpsError(
        "invalid-argument",
        "El nombre debe tener entre 2 y 80 caracteres."
      );
    }

    const normalizedCategoryId = canonicalCategoryId(step1.categoryId);
    if (!ALLOWED_CANONICAL_CATEGORY_IDS.has(normalizedCategoryId)) {
      throw new HttpsError(
        "invalid-argument",
        `La categoría '${normalizedCategoryId}' no es canónica MVP.`
      );
    }

    // Validate categoryId exists in canonical categories collection.
    const canonicalCategorySnap = await db().doc(`categories/${normalizedCategoryId}`).get();
    if (!canonicalCategorySnap.exists) {
      throw new HttpsError(
        "invalid-argument",
        `La categoría '${normalizedCategoryId}' no existe.`
      );
    }

    // ── Validate step2 ──────────────────────────────────────────────────────
    const step2 = progress.step2;
    if (!step2?.address || step2.lat == null || step2.lng == null || !step2.zoneId) {
      throw new HttpsError(
        "failed-precondition",
        "El paso 2 (dirección y zona) no fue completado."
      );
    }

    // ── Atomic write (transaction) ──────────────────────────────────────────
    const merchantRef = db().doc(`merchants/${draftMerchantId}`);
    const schedulesRef = db().doc(`merchant_schedules/${draftMerchantId}`);

    await db().runTransaction(async (tx) => {
      // Re-read user inside transaction to avoid stale data
      const freshUserSnap = await tx.get(userRef);
      const freshProgress = freshUserSnap.data()?.onboardingOwnerProgress as OnboardingOwnerProgress | undefined;
      if (!freshProgress || freshProgress.draftMerchantId !== draftMerchantId) {
        throw new HttpsError(
          "aborted",
          "Los datos del onboarding cambiaron durante el envío. Intentá de nuevo."
        );
      }
      const freshStep1 = freshProgress.step1;
      const freshStep2 = freshProgress.step2;
      const freshStep3 = freshProgress.step3 as OnboardingStep3Data | null;
      const freshStep3Skipped = freshProgress.step3Skipped ?? false;

      // Check if merchant already exists (idempotency via Firestore)
      const existingMerchant = await tx.get(merchantRef);
      if (existingMerchant.exists) {
        // Merchant was already created — just update the user progress marker
        tx.update(userRef, {
          "onboardingOwnerProgress.currentStep": "submitted",
          "onboardingOwnerProgress.updatedAt": FieldValue.serverTimestamp(),
        });
        return;
      }

      // Write merchant document
      tx.set(merchantRef, {
        merchantId: draftMerchantId,
        name: freshStep1!.name.trim(),
        category: canonicalCategoryId(freshStep1!.categoryId),
        categoryId: canonicalCategoryId(freshStep1!.categoryId),
        zone: freshStep2!.zoneId,
        zoneId: freshStep2!.zoneId,
        address: freshStep2!.address,
        lat: freshStep2!.lat,
        lng: freshStep2!.lng,
        geohash: freshStep2!.geohash ?? "",
        cityId: freshStep2!.cityId ?? "",
        provinceId: freshStep2!.provinceId ?? "",
        ownerUserId: uid,
        sourceType: "owner_created",
        visibilityStatus: "review_pending",
        status: "active",
        verificationStatus: "unverified",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Write schedules if step3 was completed (not skipped)
      if (!freshStep3Skipped && freshStep3 && Object.keys(freshStep3).length > 0) {
        tx.set(schedulesRef, {
          merchantId: draftMerchantId,
          schedule: freshStep3,
          timezone: "America/Argentina/Buenos_Aires",
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      // Mark progress as submitted and set merchantId on user doc
      tx.update(userRef, {
        "onboardingOwnerProgress.currentStep": "submitted",
        "onboardingOwnerProgress.updatedAt": FieldValue.serverTimestamp(),
        "merchantId": draftMerchantId,
      });
    });

    // Claims canónicas de acceso OWNER (sin merchantId en JWT).
    await applyUserAccessClaims({
      uid,
      role: "owner",
      ownerPending: false,
      reason: "onboarding_owner_submit",
      actorType: "user",
      actorUid: uid,
    });

    console.log(`[onboardingOwnerSubmit] Created merchant=${draftMerchantId} for uid=${uid}`);
    return { merchantId: draftMerchantId, status: "created" };
  }
);
