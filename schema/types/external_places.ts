import type { Timestamp } from 'firebase/firestore';

export type ExternalPlaceSource = 'google_places';

export type ExternalPlaceImportStatus =
  | 'detected'
  | 'normalized'
  | 'linked'
  | 'discarded'
  | 'review_pending';

/**
 * Collection: external_places/{externalPlaceDocId}
 * Raw records ingested from external sources (e.g. Google Places API).
 * Admin-only. Not exposed to public clients.
 *
 * Pipeline flow:
 *   detected → normalized → linked | discarded | review_pending
 */
export interface ExternalPlaceDocument {
  // Required
  id: string;
  source: ExternalPlaceSource;
  /** ID from the external provider (e.g. Google Place ID) */
  externalPlaceId: string;
  zoneId: string;
  displayName: string;
  normalizedName: string;
  formattedAddress: string;
  lat: number;
  lng: number;
  /** Primary category type from the external source */
  primaryType: string;
  /** Whether the source requires attribution in the UI */
  attributionRequired: boolean;
  fetchedAt: Timestamp;
  /** 0–100 confidence that this is a valid, active business */
  confidenceScore: number;
  importStatus: ExternalPlaceImportStatus;
  /** Reference to the import_batches/{batchId} this record belongs to */
  batchId: string;

  // Optional
  geohash?: string;
  businessStatus?: string;
  googleMapsUri?: string | null;
  /** SHA-256 hash of the raw API payload for deduplication */
  rawPayloadHash?: string | null;
  /** merchantId if this place has been linked to a merchant */
  linkedMerchantId?: string | null;
}
