import type { Timestamp } from 'firebase/firestore';

/**
 * Estados del ciclo de vida de un reclamo de ownership.
 * 'disputed' y 'cancelled' están preparados para V1, no implementados en MVP.
 */
export type MerchantClaimStatus =
  | 'pending'
  | 'approved'
  | 'rejected'
  | 'disputed'
  | 'cancelled';

export type ClaimEvidenceType =
  | 'social_profile'
  | 'photo_storefront'
  | 'phone_verification'
  | 'document'
  | 'other';

export interface ClaimEvidence {
  /** URL a foto del comercio (frente, cartel, etc.) */
  photoUrl?: string;
  /** Descripción del rol del reclamante */
  ownerDescription?: string;
  /** Teléfono provisto como prueba */
  verificationPhone?: string;
  [key: string]: string | undefined;
}

/**
 * Collection: merchant_claims/{claimId}
 * Solicitud de un usuario para reclamar la propiedad de un comercio.
 *
 * Solo el rol owner está activo en MVP.
 * Staff y disputas complejas quedan para V1.
 *
 * claimantUsername y claimantDisplayName se almacenan como snapshot
 * para mostrar en la ficha pública sin necesitar join al documento users.
 */
export interface MerchantClaimDocument {
  // Obligatorios
  id: string;
  merchantId: string;
  userId: string;
  status: MerchantClaimStatus;
  submittedAt: Timestamp;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Opcionales
  claimantUsername?: string | null;
  claimantDisplayName?: string | null;
  evidenceType?: ClaimEvidenceType | null;
  evidenceUrl?: string | null;
  evidence?: ClaimEvidence;
  notes?: string | null;
  reviewedAt?: Timestamp | null;
  /** UID del admin que revisó el reclamo */
  reviewedBy?: string | null;
  reviewDecision?: 'approved' | 'rejected' | null;
  reviewNotes?: string | null;
  resolvedAt?: Timestamp | null;
}
