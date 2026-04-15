import type { Timestamp } from 'firebase/firestore';

/**
 * Estados canónicos del ciclo de vida de un claim de titularidad.
 * Mantener sincronizado con callables/triggers y UX de CLAIM-07.
 */
export type MerchantClaimStatus =
  | 'draft'
  | 'submitted'
  | 'auto_validating'
  | 'under_review'
  | 'needs_more_info'
  | 'approved'
  | 'rejected'
  | 'duplicate_claim'
  | 'conflict_detected'
  | 'cancelled';

export type MerchantClaimDeclaredRole =
  | 'owner'
  | 'co_owner'
  | 'authorized_representative';

export type MerchantClaimEvidenceKind = 'storefront_photo' | 'ownership_document';

export interface MerchantClaimEvidenceFile {
  id: string;
  kind: MerchantClaimEvidenceKind;
  storagePath: string;
  contentType: string;
  sizeBytes: number;
  uploadedAt: Timestamp;
  /**
   * Nombre original del archivo. Es metadato de UX/admin, no se usa para auth.
   */
  originalFileName?: string | null;
 }

/**
 * Collection: merchant_claims/{claimId}
 * Solicitud de un usuario autenticado para reclamar titularidad de un comercio.
 * Se modela como workflow con validación automática + revisión manual posterior.
 */
export interface MerchantClaimDocument {
  // Obligatorios
  id: string;
  merchantId: string;
  userId: string;
  categoryId: string;
  zoneId: string;
  claimStatus: MerchantClaimStatus;
  authenticatedEmail: string;
  declaredRole: MerchantClaimDeclaredRole;
  hasAcceptedDataProcessingConsent: boolean;
  hasAcceptedLegitimacyDeclaration: boolean;
  storefrontPhotoUploaded: boolean;
  ownershipDocumentUploaded: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Opcionales
  submittedAt?: Timestamp | null;
  cancelledAt?: Timestamp | null;
  cancelledReason?: string | null;
  phone?: string | null;
  claimantDisplayName?: string | null;
  evidenceFiles?: MerchantClaimEvidenceFile[];
  claimantNote?: string | null;
  autoValidationVersion?: number | null;
  autoValidationResult?: 'pass' | 'needs_review' | 'blocked' | null;
  autoValidationReasonCode?: string | null;
  duplicateOfClaimId?: string | null;
  conflictType?: 'merchant_already_owned' | 'active_claim_exists' | 'suspicious_payload' | null;
  riskFlags?: string[];
  reviewedAt?: Timestamp | null;
  reviewedByUid?: string | null;
  reviewDecision?: MerchantClaimStatus | null;
  reviewNotes?: string | null;
  resolvedAt?: Timestamp | null;
  lastStatusAt?: Timestamp | null;
}
