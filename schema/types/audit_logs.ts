import type { Timestamp } from 'firebase/firestore';

export type AuditEntityType =
  | 'merchant'
  | 'merchant_claim'
  | 'pharmacy_duty'
  | 'contribution'
  | 'report'
  | 'user';

export type AuditAction =
  | 'create'
  | 'update'
  | 'delete'
  | 'archive'
  | 'restore'
  | 'approve'
  | 'reject'
  | 'publish'
  | 'unpublish';

export type AuditSource =
  | 'mobile_owner'
  | 'mobile_user'
  | 'web_admin'
  | 'cloud_function'
  | 'import_batch';

export interface AuditFieldChange {
  before: unknown;
  after: unknown;
}

/**
 * Collection: audit_logs/{logId}
 * Log de auditoría general. Top-level (no subcolecciones dispersas).
 * Solo accesible por admin y moderador.
 *
 * Se escribe exclusivamente desde Cloud Functions y backend admin.
 * Nunca desde clientes móviles o web pública.
 */
export interface AuditLogDocument {
  // Obligatorios
  id: string;
  entityType: AuditEntityType;
  entityId: string;
  action: AuditAction;
  performedByUserId: string;
  performedByRole: string;
  source: AuditSource;
  createdAt: Timestamp;

  // Opcionales
  changes?: Record<string, AuditFieldChange>;
  notes?: string | null;
}
