import type { Timestamp } from 'firebase/firestore';
import type { ExternalPlaceSource } from './external_places';

export type ImportBatchStatus =
  | 'running'
  | 'completed'
  | 'failed'
  | 'rolled_back'
  | 'hidden';

export type ImportVisibility = 'hidden' | 'visible';

/** Correspondencia entre una columna del CSV y un campo canónico de TuM2. */
export interface ImportFieldMapping {
  csvColumn: string;
  tum2Field: string;
  enabled: boolean;
}

/** Error de una fila específica durante la importación. */
export interface ImportRowError {
  row: number;
  name: string;
  reason: string;
}

/**
 * Collection: import_batches/{batchId}
 * Tracks a single execution of the external data import pipeline for a zone.
 * Admin-only.
 */
export interface ImportBatchDocument {
  // Required
  id: string;
  zoneId: string;
  source: ExternalPlaceSource;
  status: ImportBatchStatus;
  /** List of fields requested from the external API in this batch */
  requestedFields: string[];
  detectedCount: number;
  normalizedCount: number;
  linkedCount: number;
  discardedCount: number;
  /** Estimated API cost in USD for this batch */
  estimatedCost: number;
  startedAt: Timestamp;
  /** UID of the admin user who triggered the import */
  createdBy: string;

  // Optional
  finishedAt?: Timestamp | null;
  errorMessage?: string | null;

  // Campos extendidos para el portal web admin (TuM2-0077/0078)
  /** Número de batch para display (ej: #482). Autoincremental por zoneId. */
  batchNumber?: number;
  /** Tipo de dataset importado (ej: 'farmacias_repes', 'puntos_wifi'). */
  datasetType?: string;
  /** URL en Storage del archivo CSV/XLSX subido. */
  fileUrl?: string | null;
  /** Correspondencias CSV→TuM2 definidas en el paso de configuración. */
  fieldMappings?: ImportFieldMapping[];
  /** Si true, se omiten registros con nombre+teléfono duplicado. */
  deduplicationEnabled?: boolean;
  /** Visibilidad asignada a los registros importados. Default: 'hidden'. */
  visibilityAfterImport?: ImportVisibility;
  /** Errores por fila detectados durante la importación. */
  errors?: ImportRowError[];
  /** Cantidad de registros creados (alias explícito de linkedCount para UI). */
  createdCount?: number;
  /** Cantidad de registros duplicados omitidos. */
  duplicatedCount?: number;
  /** Cantidad de registros pendientes de revisión. */
  pendingReviewCount?: number;
}
