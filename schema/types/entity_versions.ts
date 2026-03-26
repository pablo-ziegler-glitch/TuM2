import type { Timestamp } from 'firebase/firestore';

/**
 * Entidades que se versionan obligatoriamente.
 * Criterio: toda entidad cuya modificación pueda afectar confianza pública,
 * moderación o auditoría de ownership.
 */
export type VersionedEntityType =
  | 'merchant'
  | 'merchant_claim'
  | 'pharmacy_duty'
  | 'catalog_item';

/**
 * Collection: entity_versions/{versionId}
 * Historial de versiones de entidades críticas.
 *
 * Política de snapshot:
 *   - snapshot parcial para cambios menores (ej: teléfono, horario)
 *   - snapshot completo en hitos críticos:
 *       * primera versión publicada
 *       * aprobación de ownership_claim
 *       * cambios de status o verificationStatus
 *       * resolución de dispute
 *
 * isFullSnapshot = true indica snapshot completo del documento en ese momento.
 * isFullSnapshot = false indica solo los campos modificados (diff parcial).
 *
 * versionNumber es secuencial por entityId, incrementado por Cloud Functions.
 */
export interface EntityVersionDocument {
  // Obligatorios
  id: string;
  entityType: VersionedEntityType;
  entityId: string;
  versionNumber: number;
  /** Snapshot parcial o completo del documento en este punto en el tiempo. */
  snapshot: Record<string, unknown>;
  createdByUserId: string;
  createdAt: Timestamp;

  // Opcionales
  changeSummary?: string | null;
  isFullSnapshot?: boolean;
}
