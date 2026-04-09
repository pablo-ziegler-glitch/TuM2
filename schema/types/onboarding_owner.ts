import type { Timestamp } from 'firebase/firestore';

/**
 * TuM2-0030-11 — Persistencia del progreso de onboarding OWNER
 *
 * Almacenado como campo embebido en users/{userId}.onboardingOwnerProgress
 * (no subcolección — el documento de usuario ya existe en ese punto del flujo).
 *
 * Ver docs/ONBOARDING-OWNER-FSM.md para la FSM completa y reglas de navegación.
 */

export type OnboardingOwnerStep =
  | 'step_1'
  | 'step_2'
  | 'step_3'
  | 'confirmation'
  | 'submitted'
  | 'completed'
  | 'abandoned';

export interface OnboardingStep1Data {
  /** Razón social (nombre legal). */
  razonSocial: string;
  /** Nombre de fantasía/comercial. Opcional. */
  nombreFantasia?: string;
  /** Compatibilidad hacia atrás con drafts viejos. */
  name?: string;
  categoryId: string;
}

export interface OnboardingStep2Data {
  address: string;
  lat: number;
  lng: number;
  geohash: string;
  zoneId: string;
  cityId: string;
  provinceId: string;
}

/**
 * Embebido en UserDocument como campo `onboardingOwnerProgress`.
 *
 * Reglas clave:
 * - `draftMerchantId`: generado en START, reutilizado en todos los reintentos.
 *   Garantiza idempotencia del SUBMIT.
 * - `step3Skipped: true` no bloquea avanzar a confirmation.
 *   Los horarios se completan después desde OWNER-07.
 * - El campo se limpia (o `currentStep` pasa a `completed`) cuando
 *   Cloud Function aprueba el comercio.
 */
export interface OnboardingOwnerProgress {
  currentStep: OnboardingOwnerStep;

  /** ULID generado al iniciar el flujo. Usado como ID del merchants/{id} draft. */
  draftMerchantId: string | null;

  step1: OnboardingStep1Data | null;
  step2: OnboardingStep2Data | null;

  /** true si el usuario eligió "Completar después" en el paso de horarios */
  step3Skipped: boolean;

  startedAt: Timestamp;
  updatedAt: Timestamp;
}
