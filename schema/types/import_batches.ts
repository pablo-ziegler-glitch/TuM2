import type { Timestamp } from 'firebase/firestore';
import type { ExternalPlaceSource } from './external_places';

export type ImportBatchStatus =
  | 'running'
  | 'completed'
  | 'failed'
  | 'rolled_back';

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
}
