import type { Timestamp } from 'firebase/firestore';

export type ModerationEntityType =
  | 'contribution'
  | 'merchant_claim'
  | 'report'
  | 'merchant'
  | 'pharmacy_duty';

export type ModerationPriority = 'low' | 'normal' | 'high' | 'critical';
export type ModerationStatus = 'pending' | 'in_review' | 'resolved' | 'dismissed';

/**
 * Collection: moderation_queue/{itemId}
 * Cola explícita de moderación para el panel admin.
 *
 * Se crea automáticamente por Cloud Functions cuando:
 *   - llega una contribution que no califica para auto-publicación
 *   - se recibe un merchant_claim
 *   - se acumulan N reportes sobre un mismo target
 *   - se detecta conflicto entre contribuciones
 *
 * Prioridades sugeridas:
 *   critical → farmacia de turno conflictiva, claim con evidencia fuerte
 *   high     → >3 reportes en 24h, edit de campo sensible
 *   normal   → edit_suggestion estándar, claim sin evidencia
 *   low      → feedback, sugerencias menores
 */
export interface ModerationQueueDocument {
  // Obligatorios
  id: string;
  entityType: ModerationEntityType;
  entityId: string;
  priority: ModerationPriority;
  reason: string;
  status: ModerationStatus;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Opcionales
  assignedToUserId?: string | null;
  resolvedAt?: Timestamp | null;
  resolutionNotes?: string | null;
}
