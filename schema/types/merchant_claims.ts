import type { Timestamp } from 'firebase/firestore';

/**
 * Estados canónicos del ciclo de vida de un claim de titularidad.
 * Mantener sincronizado con callables/triggers y UX de CLAIM-07.
 */
export type MerchantClaimStatus =
  | 'draft'
  | 'submitted'
  | 'under_review'
  | 'needs_more_info'
  | 'approved'
  | 'rejected'
  | 'duplicate_claim'
  | 'conflict_detected';

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
  /**
   * Estado técnico interno del workflow (backend).
   * Puede diferir del visible cuando se evita exponer estados técnicos.
   */
  internalWorkflowStatus?:
    | 'draft_editing'
    | 'auto_validation_running'
    | 'auto_validation_passed'
    | 'auto_validation_blocked_conflict'
    | 'auto_validation_blocked_duplicate'
    | 'auto_validation_needs_more_info'
    | 'manual_resolution_completed';
  /**
   * Estado visible para UX (CLAIM-07).
   */
  userVisibleStatus?: MerchantClaimStatus;
  workflowManagedBy?: string;
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
  // Campos legacy que se eliminan en escrituras nuevas (backend limpia texto plano)
  phone?: string | null; // legacy/backfill
  claimantDisplayName?: string | null; // legacy/backfill
  evidenceFiles?: MerchantClaimEvidenceFile[];
  claimantNote?: string | null; // legacy/backfill
  phoneMasked?: string | null;
  claimantDisplayNameMasked?: string | null;
  claimantNoteMasked?: string | null;
  autoValidationVersion?: number | null;
  autoValidationResult?: 'passed' | 'blocked' | null;
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

/**
 * Collection: merchant_claim_private/{claimId}
 * Vault privado de sensibles y fingerprints para dedupe/antifraude/revisión admin.
 * No exponer a cliente.
 */
export interface MerchantClaimPrivateDocument {
  claimId: string;
  userId: string;
  merchantId: string;
  sensitiveVault: {
    keyVersion: string;
    phoneCiphertext?: string | null;
    claimantDisplayNameCiphertext?: string | null;
    claimantNoteCiphertext?: string | null;
    phoneFingerprint?: string | null;
    claimantDisplayNameFingerprint?: string | null;
    claimantNoteFingerprint?: string | null;
    fingerprintPrimary?: string | null;
  };
  fingerprintPrimary?: string | null;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
}
