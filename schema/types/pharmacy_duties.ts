import type { Timestamp } from 'firebase/firestore';
import type { ConfidenceLevel } from './merchant';

export type PharmacyDutyStatus = 'draft' | 'published' | 'cancelled';

export type PharmacyDutyVerificationStatus =
  | 'referential'
  | 'validated'
  | 'claimed';

export type PharmacyDutySourceType =
  | 'owner_created'
  | 'admin_created'
  | 'external_seed';

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
  zoneId: string;
  /** ISO date string: YYYY-MM-DD */
  date: string;
  startsAt: Timestamp;
  endsAt: Timestamp;
  status: PharmacyDutyStatus;
  sourceType: PharmacyDutySourceType;
  createdBy: string;
  updatedBy: string;
  verificationStatus?: PharmacyDutyVerificationStatus;
  /** Score de confianza 0–100. Escrito solo por Cloud Functions. */
  confidenceScore?: number;
  confidenceLevel?: ConfidenceLevel;
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
