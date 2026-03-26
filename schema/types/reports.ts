import type { Timestamp } from 'firebase/firestore';

export type ReportTargetType = 'merchant' | 'pharmacy_duty' | 'signal' | 'catalog_item';

export type ReportType =
  | 'incorrect_information'
  | 'wrong_schedule'
  | 'wrong_phone'
  | 'wrong_address'
  | 'closed_now'
  | 'closed_permanently'
  | 'not_on_duty'
  | 'wrong_duty'
  | 'duplicate'
  | 'abusive_content'
  | 'other';

export type ReportStatus = 'open' | 'reviewing' | 'resolved' | 'dismissed';

/**
 * Collection: reports/{reportId}
 * Reporte de un usuario indicando información incorrecta o abusiva.
 *
 * Se mantiene separado de contributions para distinguir acción correctiva
 * (contribution) de señal de problema (report).
 * Los reports alimentan el módulo de moderación y pueden decrementar
 * el confidenceScore del comercio afectado.
 */
export interface ReportDocument {
  // Obligatorios
  id: string;
  targetType: ReportTargetType;
  /** ID del documento reportado */
  targetId: string;
  reportType: ReportType;
  status: ReportStatus;
  /** UID del usuario que envió el reporte */
  createdBy: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Opcionales
  /** Código de razón más específico que reportType */
  reasonCode?: string | null;
  description?: string | null;
  evidenceImageUrl?: string | null;
  reviewedAt?: Timestamp | null;
  /** UID del admin que revisó el reporte */
  reviewedBy?: string | null;
  resolutionNotes?: string | null;
  resolvedAt?: Timestamp | null;
}
