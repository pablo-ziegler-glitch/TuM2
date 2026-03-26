import type { Timestamp } from 'firebase/firestore';

export type ContributionTargetType = 'merchant' | 'pharmacy_duty' | 'signal';

/**
 * Tipo de contribución comunitaria.
 * Las de bajo riesgo pueden publicarse automáticamente (semi_auto).
 * Las de alto riesgo van siempre a revisión manual.
 *
 * Nunca auto-aplicable en MVP:
 *   - ownership, nombre, categoría principal
 *   - farmacia de turno sin soporte
 *   - cierre definitivo, datos sensibles conflictivos
 */
export type ContributionType =
  | 'new_merchant_suggestion'
  | 'edit_suggestion'
  | 'report_closed'
  | 'report_inconsistency'
  | 'signal_update'
  | 'pharmacy_turn_report';

export type ContributionStatus =
  | 'pending_review'
  | 'auto_applied'
  | 'approved'
  | 'rejected';

export type ContributionReviewMode = 'manual' | 'semi_auto' | 'auto';

/**
 * Collection: contributions/{contributionId}
 * Contribución de un usuario sobre un comercio, turno o señal.
 *
 * payload contiene los campos sugeridos como objeto libre.
 * confidenceImpact es el delta sobre confidenceScore del target
 * si la contribución es aprobada.
 */
export interface ContributionDocument {
  // Obligatorios
  id: string;
  targetType: ContributionTargetType;
  targetId: string;
  contributionType: ContributionType;
  status: ContributionStatus;
  submittedByUserId: string;
  submittedByUsername: string | null;
  submittedByDisplayName: string;
  /** Campos sugeridos: { phone: '+54911...', supportsOrders: true } */
  payload: Record<string, unknown>;
  autoPublishEligible: boolean;
  reviewMode: ContributionReviewMode;
  /** Delta sobre confidenceScore del target si se aprueba (positivo o negativo). */
  confidenceImpact: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Opcionales
  evidenceImageUrl?: string | null;
  evidenceText?: string | null;
  reviewedByUserId?: string | null;
  reviewDecision?: 'approved' | 'rejected' | null;
  reviewNotes?: string | null;
  resolvedAt?: Timestamp | null;
}
