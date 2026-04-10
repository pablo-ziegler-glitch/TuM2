import type { Timestamp } from 'firebase/firestore';

export type PharmacyDutyStatus =
  | 'draft'
  | 'published'
  | 'scheduled'
  | 'active'
  | 'incident_reported'
  | 'replacement_pending'
  | 'reassigned'
  | 'cancelled';

export type PharmacyDutyConfirmationStatus =
  | 'pending'
  | 'confirmed'
  | 'overdue'
  | 'incident_reported'
  | 'replaced';

export type PharmacyDutyVerificationStatus =
  | 'referential'
  | 'validated'
  | 'claimed';

export type PharmacyDutySourceType =
  | 'owner_created'
  | 'admin_created'
  | 'external_seed'
  | 'system_reassigned';

export type PharmacyDutyConfidenceLevel = 'high' | 'medium' | 'low';

export type PharmacyDutyPublicStatusLabel =
  | 'guardia_confirmada'
  | 'guardia_en_verificacion'
  | 'cambio_operativo_en_curso';

/**
 * Collection: pharmacy_duties/{dutyId}
 * Capa de turno/guardia de una farmacia para una fecha dada.
 * Un mismo merchant puede tener múltiples entries en fechas/zonas distintas.
 *
 * Dos capas de información:
 *   1. Comercio base (merchants/{merchantId})
 *   2. Esta capa de turno — enlazada por merchantId
 *
 * confidenceScore y confidenceLevel se recalculan por Cloud Functions
 * según evidencia, historial de reportes y validaciones recibidas.
 */
export interface PharmacyDutyDocument {
  // Obligatorios
  merchantId: string;
  originMerchantId?: string;
  zoneId: string;
  /** ISO date string: YYYY-MM-DD */
  date: string;
  startsAt: Timestamp | string;
  endsAt: Timestamp | string;
  status: PharmacyDutyStatus;
  confirmationStatus: PharmacyDutyConfirmationStatus;
  sourceType: PharmacyDutySourceType;
  verificationStatus: PharmacyDutyVerificationStatus;
  createdBy: string;
  updatedBy: string;
  confidenceLevel?: PharmacyDutyConfidenceLevel;
  publicStatusLabel?: PharmacyDutyPublicStatusLabel;
  incidentOpen?: boolean;
  incidentId?: string;
  replacementRoundOpen?: boolean;
  replacementMerchantId?: string;
  replacementAcceptedAt?: Timestamp;
  confirmedAt?: Timestamp;
  confirmedByUserId?: string;
  lastStatusChangedAt?: Timestamp;
  confirmationReminderLastSentAt?: Timestamp;
  confirmationReminderCount?: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Opcionales
  notes?: string | null;
  lastValidatedAt?: Timestamp | null;
  /** Cantidad de reportes "está cerrada" recibidos en este turno. */
  reportedClosedCount?: number;
  /** Cantidad de reportes de inconsistencia recibidos en este turno. */
  reportInconsistencyCount?: number;
  /** Si es true, se requiere evidencia adicional antes de publicar. */
  evidenceRequired?: boolean;
}
