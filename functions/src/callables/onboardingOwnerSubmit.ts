import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import {
  OnboardingOwnerProgress,
  OnboardingStep3Data,
} from "../lib/types";

const db = () => getFirestore();

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
  { enforceAppCheck: false },
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

    // Validate categoryId exists in 'categories' collection
    const categorySnap = await db().doc(`categories/${step1.categoryId}`).get();
    if (!categorySnap.exists) {
      throw new HttpsError(
        "invalid-argument",
        `La categoría '${step1.categoryId}' no existe.`
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
    const step3 = progress.step3 as OnboardingStep3Data | null;
    const step3Skipped = progress.step3Skipped ?? false;

    await db().runTransaction(async (tx) => {
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
        name: step1.name.trim(),
        category: step1.categoryId,      // campo existente en MerchantDoc
        zone: step2.zoneId,              // campo existente en MerchantDoc
        zoneId: step2.zoneId,
        address: step2.address,
        lat: step2.lat,
        lng: step2.lng,
        geohash: step2.geohash ?? "",
        cityId: step2.cityId ?? "",
        provinceId: step2.provinceId ?? "",
        ownerUserId: uid,
        sourceType: "owner_created",
        visibilityStatus: "review_pending",
        status: "active",
        verificationStatus: "unverified",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Write schedules if step3 was completed (not skipped)
      if (!step3Skipped && step3 && Object.keys(step3).length > 0) {
        tx.set(schedulesRef, {
          merchantId: draftMerchantId,
          schedule: step3,
          timezone: "America/Argentina/Buenos_Aires",
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      // Mark progress as submitted
      tx.update(userRef, {
        "onboardingOwnerProgress.currentStep": "submitted",
        "onboardingOwnerProgress.updatedAt": FieldValue.serverTimestamp(),
      });
    });

    console.log(`[onboardingOwnerSubmit] Created merchant=${draftMerchantId} for uid=${uid}`);
    return { merchantId: draftMerchantId, status: "created" };
  }
);
