import type { Timestamp } from 'firebase/firestore';
import type { MerchantVerificationStatus, MerchantVisibilityStatus } from './merchant';

export type MerchantBadge =
  | 'verified'
  | 'referential'
  | 'pending_validation'
  | 'claimed'
  | 'pharmacy_on_duty';

export interface OperationalSignalsSnapshot {
  temporaryClosed?: boolean;
  hasDelivery?: boolean;
  acceptsWhatsappOrders?: boolean;
  [key: string]: boolean | undefined;
}

/**
 * Collection: merchant_public/{merchantId}
 * Denormalized, read-optimized public view of a merchant.
 * Written exclusively by Cloud Functions — never by client code.
 *
 * sortBoost reference:
 *   verified: 100 | validated: 90 | claimed: 80 |
 *   referential: 70 | community_submitted: 40 | unverified: 20
 */
export interface MerchantPublicDocument {
  // Required
  merchantId: string;
  name: string;
  categoryId: string;
  zoneId: string;
  cityId: string;
  provinceId: string;
  address: string;
  lat: number;
  lng: number;
  verificationStatus: MerchantVerificationStatus;
  visibilityStatus: MerchantVisibilityStatus;
  badges: MerchantBadge[];
  /** null when schedule info is unavailable or unverified */
  isOpenNow: boolean | null;
  openStatusLabel: string;
  hasPharmacyDutyToday: boolean;
  searchKeywords: string[];
  /** Numeric boost for ordering in search results */
  sortBoost: number;
  lastDataRefreshAt: Timestamp;

  // Optional
  categoryLabel?: string;
  geohash?: string;
  distanceBucket?: string | null;
  todayScheduleLabel?: string | null;
  operationalSignals?: OperationalSignalsSnapshot;
  mapsUrl?: string | null;
  lastVerifiedAt?: Timestamp | null;
  /** 0–100 data confidence score */
  confidenceScore?: number;
}
